import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:subsonic_api/subsonic_api.dart';

import '../data/db/app_database.dart';
import '../data/server_repository.dart';
import 'audio_player_provider.dart';
import 'audio_player_service.dart';
import 'persisted_playable_item.dart';

/// Connects the platform player to durable playback state and local recent-play
/// history. It deliberately restores a paused queue only.
class PlaybackCoordinator {
  PlaybackCoordinator({
    required this.service,
    required this.database,
    required this.server,
  }) {
    _subscription = service.snapshot.listen(_onSnapshot);
    unawaited(_restore());
  }

  final AudioPlayerService service;
  final AppDatabase database;

  /// The server the queue belongs to. URLs and headers are regenerated from
  /// its metadata on restore; they are never persisted.
  final Server? server;

  late final StreamSubscription<PlayerSnapshot> _subscription;
  Timer? _saveTimer;
  PlayerSnapshot? _lastSnapshot;
  // Per-play recording guard: each distinct song play is recorded at most
  // once. The guard resets whenever the active song changes, so replaying a
  // song later (after the 5-minute DB de-duplication window) is allowed.
  bool _recordedActive = false;
  bool _restoring = true;
  bool _disposed = false;

  Future<void> _restore() async {
    try {
      final saved = await database.getPlaybackState();
      final activeServer = server;
      if (_disposed ||
          activeServer == null ||
          saved == null ||
          saved.serverId != activeServer.id) {
        return;
      }
      final decoded = jsonDecode(saved.queueJson);
      if (decoded is! List) {
        return;
      }
      final persisted = _decodePersistedQueue(decoded, activeServer);
      if (persisted.isEmpty) {
        return;
      }
      final subsonic = activeServer.type == 'webdav'
          ? null
          : SubsonicClient(
              baseUrl: activeServer.baseUrl,
              username: activeServer.username,
              password: activeServer.password,
            );
      final items = <PlayableItem>[];
      for (final entry in persisted) {
        final item = await _rebuildPlayableItem(entry, activeServer, subsonic);
        if (item != null) {
          items.add(item);
        }
      }
      if (items.isEmpty) {
        return;
      }
      final index = saved.currentIndex.clamp(0, items.length - 1);
      await service.setQueue(items, startIndex: index);
      await service.setLoopMode(_loopModeFromString(saved.loopMode));
      await service.setShuffle(saved.shuffle);
      await service.setVolume(saved.volume.clamp(0, 1));
      await service.setSpeed(saved.speed <= 0 ? 1 : saved.speed);
      await service.seek(
        Duration(milliseconds: saved.positionMs.clamp(0, 1 << 31)),
      );
    } catch (_) {
      // A stale queue or a malformed old record should never prevent startup.
    } finally {
      _restoring = false;
    }
  }

  /// Parses the persisted queue JSON, accepting both the sanitized
  /// [PersistedPlayableItem] format and the legacy raw-`PlayableItem` JSON.
  /// Legacy entries are converted on the fly (credentials dropped); the next
  /// save overwrites the old format.
  List<PersistedPlayableItem> _decodePersistedQueue(
    List<dynamic> decoded,
    Server activeServer,
  ) {
    final entries = <PersistedPlayableItem>[];
    for (final raw in decoded) {
      if (raw is! Map) {
        continue;
      }
      final json = raw.map((key, value) => MapEntry(key.toString(), value));
      try {
        if (PersistedPlayableItem.isLegacyJson(json)) {
          entries.add(
            PersistedPlayableItem.fromLegacyJson(
              json,
              sourceType: _classifyStreamUrl(
                json['streamUrl']?.toString() ?? '',
                activeServer,
              ),
            ),
          );
        } else {
          entries.add(PersistedPlayableItem.fromJson(json));
        }
      } catch (_) {
        // Skip one malformed entry and keep the rest of the queue.
      }
    }
    return entries
        .where((entry) => entry.id.isNotEmpty && entry.title.isNotEmpty)
        .toList(growable: false);
  }

  /// Rebuilds a playable item with a freshly signed stream URL. Returns null
  /// when the source cannot be rebuilt (e.g. internet radio, missing server)
  /// or the local file disappeared; such entries are dropped from the
  /// restored queue.
  Future<PlayableItem?> _rebuildPlayableItem(
    PersistedPlayableItem entry,
    Server activeServer,
    SubsonicClient? subsonic,
  ) async {
    String? streamUrl;
    Map<String, String>? headers;
    String? artworkUrl;
    String? artworkCacheKey;

    if (entry.artworkId != null && subsonic != null) {
      artworkUrl = subsonic.coverArtUrl(entry.artworkId!, size: 600);
      artworkCacheKey = 'cover_${entry.artworkId!}_600';
    }

    switch (entry.sourceType) {
      case 'local':
        final path = entry.localFilePath;
        if (path == null || path.isEmpty || !File(path).existsSync()) {
          return null;
        }
        streamUrl = Uri.file(path).toString();
      case 'webdav':
        streamUrl = Uri.parse(
          activeServer.baseUrl,
        ).resolve(entry.id).toString();
        final credentials = base64Encode(
          utf8.encode('${activeServer.username}:${activeServer.password}'),
        );
        headers = <String, String>{'Authorization': 'Basic $credentials'};
      case 'subsonic':
        streamUrl = subsonic?.streamUrl(entry.id);
      default:
        // Internet radio or an unknown source: no way to regenerate a URL.
        return null;
    }

    if (streamUrl == null || streamUrl.isEmpty) {
      return null;
    }
    return entry.toPlayable(
      streamUrl: streamUrl,
      headers: headers,
      artworkUrl: artworkUrl,
      artworkCacheKey: artworkCacheKey,
    );
  }

  /// Classifies a runtime stream URL for persistence. Only the shape of the
  /// URL is inspected; the URL itself is never stored.
  String _classifyStreamUrl(String streamUrl, Server activeServer) {
    if (streamUrl.startsWith('file:')) {
      return 'local';
    }
    if (activeServer.type == 'webdav') {
      return 'webdav';
    }
    if (streamUrl.contains('/rest/stream')) {
      return 'subsonic';
    }
    return 'external';
  }

  void _onSnapshot(PlayerSnapshot snapshot) {
    final previous = _lastSnapshot;
    _lastSnapshot = snapshot;
    if (_restoring || _disposed) {
      return;
    }

    _scheduleSave(snapshot);

    final item = snapshot.currentItem;
    final changed = previous != null && previous.currentItem?.id != item?.id;
    if (changed) {
      // The previously active song is ending. Record it once more if it was
      // skipped before the half-way point (guarded by its own recorded state).
      unawaited(_recordRecentPlayIfEligible(previous, force: true));
      // Starting a new song resets the per-play recording guard.
      _recordedActive = false;
    }
    if (snapshot.status == PlayerStatus.completed || _hasPassedHalf(snapshot)) {
      unawaited(_recordRecentPlayIfEligible(snapshot));
    }
  }

  bool _hasPassedHalf(PlayerSnapshot snapshot) {
    final duration = snapshot.duration ?? snapshot.currentItem?.duration;
    return duration != null &&
        duration > Duration.zero &&
        snapshot.position >= duration ~/ 2;
  }

  Future<void> _recordRecentPlayIfEligible(
    PlayerSnapshot snapshot, {
    bool force = false,
  }) async {
    final item = snapshot.currentItem;
    if (item == null ||
        item.id.isEmpty ||
        (!force && !_hasPassedHalf(snapshot))) {
      return;
    }
    if (_recordedActive) {
      return;
    }
    final activeServer = server;
    if (activeServer != null) {
      try {
        await database.recordRecentPlay(
          songId: item.id,
          serverId: activeServer.id,
          title: item.title,
          artist: item.artist,
          album: item.album,
          albumId: item.albumId,
          artistId: item.artistId,
        );
      } catch (_) {
        // History is best effort and must not interrupt playback.
      }
    }
    _recordedActive = true;
  }

  void _scheduleSave(PlayerSnapshot snapshot) {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(seconds: 2), () {
      unawaited(_save(snapshot));
    });
  }

  Future<void> _save(PlayerSnapshot snapshot) async {
    final activeServer = server;
    if (activeServer == null) {
      return;
    }
    try {
      final persisted = <Map<String, Object?>>[
        for (final item in snapshot.queue)
          PersistedPlayableItem.fromPlayable(
            item,
            sourceType: _classifyStreamUrl(item.streamUrl, activeServer),
          ).toJson(),
      ];
      await database.savePlaybackState(
        serverId: activeServer.id,
        queueJson: jsonEncode(persisted),
        currentIndex: snapshot.currentIndex ?? 0,
        positionMs: snapshot.position.inMilliseconds,
        loopMode: snapshot.loopMode.name,
        shuffle: snapshot.shuffle,
        volume: snapshot.volume,
        speed: snapshot.speed,
      );
    } catch (_) {
      // A locked or unavailable database must not affect audio playback.
    }
  }

  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;
    _saveTimer?.cancel();
    final snapshot = _lastSnapshot;
    if (snapshot != null) {
      await _save(snapshot);
    }
    await _subscription.cancel();
  }

  static AppLoopMode _loopModeFromString(String value) {
    return switch (value) {
      'all' => AppLoopMode.all,
      'one' => AppLoopMode.one,
      _ => AppLoopMode.off,
    };
  }
}

final playbackCoordinatorProvider = Provider<PlaybackCoordinator?>((ref) {
  final server = ref.watch(activeServerProvider);
  if (server == null) {
    return null;
  }
  final coordinator = PlaybackCoordinator(
    service: ref.watch(audioPlayerProvider),
    database: ref.watch(databaseProvider),
    server: server,
  );
  ref.onDispose(() {
    unawaited(coordinator.dispose());
  });
  return coordinator;
});
