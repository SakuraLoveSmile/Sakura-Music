import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/db/app_database.dart';
import '../data/server_repository.dart';
import 'audio_player_provider.dart';
import 'audio_player_service.dart';

/// Connects the platform player to durable playback state and local recent-play
/// history. It deliberately restores a paused queue only.
class PlaybackCoordinator {
  PlaybackCoordinator({
    required this.service,
    required this.database,
    required this.serverId,
  }) {
    _subscription = service.snapshot.listen(_onSnapshot);
    unawaited(_restore());
  }

  final AudioPlayerService service;
  final AppDatabase database;
  final int? serverId;

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
      if (_disposed || saved == null || saved.serverId != serverId) {
        return;
      }
      final decoded = jsonDecode(saved.queueJson);
      if (decoded is! List) {
        return;
      }
      final items = decoded
          .whereType<Map>()
          .map(
            (item) => PlayableItem.fromJson(
              item.map((key, value) => MapEntry(key.toString(), value)),
            ),
          )
          .where((item) => item.id.isNotEmpty && item.streamUrl.isNotEmpty)
          .toList(growable: false);
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
    if (serverId != null) {
      try {
        await database.recordRecentPlay(
          songId: item.id,
          serverId: serverId!,
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
    try {
      await database.savePlaybackState(
        serverId: serverId,
        queueJson: jsonEncode(
          snapshot.queue.map((item) => item.toJson()).toList(growable: false),
        ),
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
    serverId: server.id,
  );
  ref.onDispose(() {
    unawaited(coordinator.dispose());
  });
  return coordinator;
});
