import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../audio/audio_player_provider.dart';
import '../../audio/audio_player_service.dart';
import '../../data/settings_repository.dart';
import '../player/lyrics/lyrics_parser.dart';
import '../player/lyrics/lyrics_service.dart';
import 'status_bar_lyrics_channel.dart';

/// Keeps the Lyricon status-bar lyrics in sync with playback.
///
/// Unlike the floating overlay, Lyricon expects the whole song (title, artist,
/// duration and timed lines) to be pushed once when the song changes; after
/// that only position and play-state are streamed. The snapshot stream is
/// already throttled to ~500ms by [PlayerSnapshotEmitter], which matches
/// Lyricon's default position-read interval, so high-frequency position
/// updates stay off the platform channel.
class StatusBarLyricsController extends Notifier<bool> {
  StatusBarLyricsChannel get _channel => ref.read(statusBarLyricsChannelProvider);

  StreamSubscription<PlayerSnapshot>? _snapshotSub;
  String? _songId;
  PlayableItem? _currentItem;
  bool? _lastPlaying;
  int _lastPositionMs = -1;

  @override
  bool build() {
    ref.onDispose(_stopListening);
    if (Platform.isAndroid) {
      unawaited(_restoreAfterStartup());
    }
    return false;
  }

  /// Toggles status-bar lyrics. No special permission is needed; the Lyricon
  /// provider degrades silently on devices without LSPosed/Lyricon installed.
  Future<void> setEnabled(bool value, {bool persist = true}) async {
    if (state == value) {
      return;
    }
    final previous = state;
    state = value;
    try {
      if (value) {
        await _channel.register();
        _startListening();
      } else {
        _stopListening();
        await _channel.destroy();
      }
    } catch (_) {
      // A dead provider must not leave a stale switch state behind.
      state = previous;
      _stopListening();
      return;
    }
    if (persist) {
      await _persist(value);
    }
  }

  /// Feeds one player snapshot into the sync logic. Exposed for tests; in the
  /// app it is driven by the snapshot stream subscription.
  @visibleForTesting
  void handleSnapshot(PlayerSnapshot snapshot) {
    if (!state) {
      return;
    }
    final item = snapshot.currentItem;
    if (item == null || item.id.isEmpty) {
      if (_songId != null) {
        _songId = null;
        _currentItem = null;
        _lastPlaying = null;
        _lastPositionMs = -1;
        _pushClear();
      }
      return;
    }

    if (item.id != _songId) {
      _songId = item.id;
      _currentItem = item;
      _lastPlaying = null;
      _lastPositionMs = -1;
      // Push a placeholder song (no lyrics yet) so the title/artist show
      // immediately; the loaded lyrics replace it once available.
      _pushSong(item, null);
      unawaited(_loadLyrics(item));
    }

    // Sync play state, deduplicated so unchanged snapshots stay off the channel.
    if (snapshot.playing != _lastPlaying) {
      _lastPlaying = snapshot.playing;
      _channel
          .setPlaybackState(snapshot.playing)
          .catchError((Object _) {});
    }

    // Sync position, deduplicated the same way.
    final positionMs = snapshot.position.inMilliseconds;
    if (positionMs != _lastPositionMs) {
      _lastPositionMs = positionMs;
      _channel.setPosition(positionMs).catchError((Object _) {});
    }
  }

  /// Injects loaded lyrics for [songId]; exposed for tests. Passing null keeps
  /// the song-info placeholder in place.
  @visibleForTesting
  void debugSetLyrics(String songId, List<ParsedLyricsLine>? lines) {
    if (_songId != songId) {
      return;
    }
    if (_currentItem != null) {
      _pushSong(_currentItem!, lines);
    }
  }

  void _pushSong(PlayableItem item, List<ParsedLyricsLine>? lines) {
    final durationMs = item.duration?.inMilliseconds ?? 0;
    final lyricLines = <StatusBarLyricLine>[];
    if (lines != null) {
      for (var i = 0; i < lines.length; i++) {
        final beginMs = lines[i].timeMs;
        final endMs =
            (i + 1 < lines.length) ? lines[i + 1].timeMs : durationMs;
        lyricLines.add(
          StatusBarLyricLine(
            beginMs: beginMs,
            endMs: endMs,
            text: lines[i].text,
          ),
        );
      }
    }
    _channel
        .setSong(
          id: item.id,
          name: item.title,
          artist: item.artist,
          durationMs: durationMs,
          lines: lyricLines,
        )
        .catchError((Object _) {});
  }

  void _pushClear() {
    _channel.clearSong().catchError((Object _) {});
  }

  Future<void> _loadLyrics(PlayableItem item) async {
    final service = ref.read(lyricsServiceProvider);
    if (service == null) {
      return;
    }
    try {
      final lines = await service.load(
        LyricsQuery(id: item.id, artist: item.artist, title: item.title),
      );
      if (_songId != item.id) {
        return;
      }
      // Re-push the song with its now-loaded lyrics.
      _pushSong(item, lines);
    } catch (_) {
      // No lyrics or a fetch failure leaves the song-info placeholder in place.
    }
  }

  void _startListening() {
    _stopListening();
    final service = ref.read(audioPlayerProvider);
    _snapshotSub = service.snapshot.listen(handleSnapshot);
    final current = service.currentSnapshot;
    if (current != null) {
      handleSnapshot(current);
    }
  }

  void _stopListening() {
    _snapshotSub?.cancel();
    _snapshotSub = null;
  }

  Future<void> _persist(bool value) async {
    try {
      await ref
          .read(settingsRepositoryProvider)
          .updateStatusBarLyrics(enabled: value);
    } catch (_) {
      // Persistence failures must not undo the visible switch state.
    }
  }

  Future<void> _restoreAfterStartup() async {
    try {
      final row = await ref.read(settingsRepositoryProvider).read();
      if (!(row?.statusBarLyricsEnabled ?? false) || state) {
        return;
      }
      await setEnabled(true, persist: false);
    } catch (_) {
      // Restoring on startup is best effort.
    }
  }
}

final statusBarLyricsControllerProvider =
    NotifierProvider<StatusBarLyricsController, bool>(
      StatusBarLyricsController.new,
    );
