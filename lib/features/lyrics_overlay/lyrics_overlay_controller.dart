import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../audio/audio_player_provider.dart';
import '../../audio/audio_player_service.dart';
import '../../data/settings_repository.dart';
import '../player/lyrics/lyrics_parser.dart';
import '../player/lyrics/lyrics_service.dart';
import 'lyrics_overlay_channel.dart';

/// Keeps the Android floating-lyrics window in sync with playback.
///
/// The switch state lives here and persists to the settings table. Lyrics are
/// pushed to native only when the active line index or the playing flag
/// changes, so high-frequency position updates stay off the platform channel.
class LyricsOverlayController extends Notifier<bool> {
  LyricsOverlayChannel get _channel => ref.read(lyricsOverlayChannelProvider);

  StreamSubscription<PlayerSnapshot>? _snapshotSub;
  String? _songId;
  List<ParsedLyricsLine>? _lines;
  String _fallbackText = '';
  int _lastIndex = -2;
  bool? _lastPlaying;

  @override
  bool build() {
    ref.onDispose(_stopListening);
    _channel.setOverlayClosedHandler(_onOverlayClosed);
    if (Platform.isAndroid) {
      unawaited(_restoreAfterStartup());
    }
    return false;
  }

  /// Toggles the overlay. Permission checks happen at the call site (settings
  /// screen) so the user can be prompted properly.
  Future<void> setEnabled(bool value, {bool persist = true}) async {
    if (state == value) {
      return;
    }
    final previous = state;
    state = value;
    try {
      if (value) {
        await _channel.show();
        _startListening();
      } else {
        _stopListening();
        await _channel.hide();
      }
    } catch (_) {
      // A dead or denied overlay must not leave a stale switch state behind.
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
        _lines = null;
        _lastIndex = -2;
        _fallbackText = '';
        _lastPlaying = null;
        _pushToChannel('', '', snapshot.playing);
      }
      return;
    }
    if (item.id != _songId) {
      _songId = item.id;
      _lines = null;
      _lastIndex = -2;
      _lastPlaying = null;
      _fallbackText = (item.artist == null || item.artist!.isEmpty)
          ? '♪ ${item.title}'
          : '♪ ${item.title} - ${item.artist}';
      unawaited(_loadLyrics(item));
    }

    final index = _activeIndex(_lines, snapshot.position.inMilliseconds);
    if (index == _lastIndex && snapshot.playing == _lastPlaying) {
      return;
    }
    _lastIndex = index;
    _lastPlaying = snapshot.playing;
    final lines = _lines;
    final currentText = index >= 0 ? lines![index].text : _fallbackText;
    final nextText = (lines != null && index + 1 < lines.length)
        ? lines[index + 1].text
        : '';
    _pushToChannel(currentText, nextText, snapshot.playing);
  }

  /// Injects loaded lyrics for [songId]; exposed for tests. Passing null
  /// keeps the song-info fallback text.
  @visibleForTesting
  void debugSetLyrics(String songId, List<ParsedLyricsLine>? lines) {
    _songId = songId;
    _lines = lines;
    _lastIndex = -2;
  }

  void _pushToChannel(String current, String next, bool isPlaying) {
    _channel
        .updateLyrics(current: current, next: next, isPlaying: isPlaying)
        .catchError((Object _) {});
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
      _lines = lines;
      _lastIndex = -2;
      final snapshot = ref.read(audioPlayerProvider).currentSnapshot;
      if (snapshot != null) {
        handleSnapshot(snapshot);
      }
    } catch (_) {
      // No lyrics or a fetch failure leaves the song-info fallback in place.
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

  void _onOverlayClosed() {
    state = false;
    _stopListening();
    unawaited(_persist(false));
  }

  Future<void> _persist(bool value) async {
    try {
      await ref
          .read(settingsRepositoryProvider)
          .updateLyricsOverlay(enabled: value);
    } catch (_) {
      // Persistence failures must not undo the visible overlay state.
    }
  }

  Future<void> _restoreAfterStartup() async {
    try {
      final row = await ref.read(settingsRepositoryProvider).read();
      if (!(row?.lyricsOverlayEnabled ?? false) || state) {
        return;
      }
      if (!await _channel.checkPermission()) {
        return;
      }
      await setEnabled(true, persist: false);
    } catch (_) {
      // Restoring the overlay on startup is best effort.
    }
  }

  /// Same binary search as the in-app lyrics view: the last line whose
  /// timestamp is not after the playback position.
  static int _activeIndex(List<ParsedLyricsLine>? lines, int positionMs) {
    if (lines == null || lines.isEmpty) {
      return -1;
    }
    var active = -1;
    var low = 0;
    var high = lines.length - 1;
    while (low <= high) {
      final middle = low + ((high - low) >> 1);
      if (lines[middle].timeMs <= positionMs) {
        active = middle;
        low = middle + 1;
      } else {
        high = middle - 1;
      }
    }
    return active;
  }
}

final lyricsOverlayControllerProvider =
    NotifierProvider<LyricsOverlayController, bool>(
      LyricsOverlayController.new,
    );
