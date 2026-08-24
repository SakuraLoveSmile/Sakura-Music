import 'dart:async';

import 'equalizer_models.dart';

enum PlayerStatus { idle, loading, buffering, ready, completed, error }

enum AppLoopMode { off, all, one }

class PlayableItem {
  const PlayableItem({
    required this.id,
    required this.title,
    required this.streamUrl,
    this.artist,
    this.album,
    this.artworkUrl,
    this.artworkCacheKey,
    this.duration,
  });

  final String id;
  final String title;
  final String streamUrl;
  final String? artist;
  final String? album;
  final String? artworkUrl;
  final String? artworkCacheKey;
  final Duration? duration;

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'title': title,
    'streamUrl': streamUrl,
    'artist': artist,
    'album': album,
    'artworkUrl': artworkUrl,
    'artworkCacheKey': artworkCacheKey,
    'durationMs': duration?.inMilliseconds,
  };

  factory PlayableItem.fromJson(Map<String, dynamic> json) {
    final durationMs = json['durationMs'];
    return PlayableItem(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      streamUrl: json['streamUrl']?.toString() ?? '',
      artist: json['artist']?.toString(),
      album: json['album']?.toString(),
      artworkUrl: json['artworkUrl']?.toString(),
      artworkCacheKey: json['artworkCacheKey']?.toString(),
      duration: durationMs is num
          ? Duration(milliseconds: durationMs.toInt())
          : null,
    );
  }
}

class PlayerSnapshot {
  const PlayerSnapshot({
    this.status = PlayerStatus.idle,
    this.playing = false,
    this.position = Duration.zero,
    this.duration,
    this.currentIndex,
    this.currentItem,
    this.error,
    this.queue = const <PlayableItem>[],
    this.loopMode = AppLoopMode.off,
    this.shuffle = false,
    this.volume = 1,
    this.speed = 1,
  });

  final PlayerStatus status;
  final bool playing;
  final Duration position;
  final Duration? duration;
  final int? currentIndex;
  final PlayableItem? currentItem;
  final Object? error;
  final List<PlayableItem> queue;
  final AppLoopMode loopMode;
  final bool shuffle;
  final double volume;
  final double speed;
}

/// Coalesces high-frequency position updates while keeping state changes
/// observable immediately. The snapshot stream is shared by UI and platform
/// integrations, so reducing duplicate snapshots here prevents every
/// subscriber from doing work on every native position callback.
class PlayerSnapshotEmitter {
  PlayerSnapshotEmitter(this._add);

  static const positionThrottle = Duration(milliseconds: 500);
  static const duplicatePositionWindow = Duration(milliseconds: 400);

  final void Function(PlayerSnapshot snapshot) _add;
  Timer? _positionTimer;
  PlayerSnapshot? _pendingPositionSnapshot;
  PlayerSnapshot? _lastSnapshot;
  bool _disposed = false;

  void emit(PlayerSnapshot snapshot, {bool positionChanged = false}) {
    if (_disposed) {
      return;
    }
    if (positionChanged) {
      _pendingPositionSnapshot = snapshot;
      if (_positionTimer != null) {
        return;
      }
      _positionTimer = Timer(positionThrottle, () {
        _positionTimer = null;
        final pending = _pendingPositionSnapshot;
        _pendingPositionSnapshot = null;
        if (pending != null) {
          _emitIfChanged(pending);
        }
      });
      return;
    }

    // State changes must not wait behind a pending position tick. The
    // immediate snapshot already contains the latest position.
    _positionTimer?.cancel();
    _positionTimer = null;
    _pendingPositionSnapshot = null;
    _emitIfChanged(snapshot);
  }

  void dispose() {
    _disposed = true;
    _positionTimer?.cancel();
    _positionTimer = null;
    _pendingPositionSnapshot = null;
  }

  void _emitIfChanged(PlayerSnapshot snapshot) {
    final previous = _lastSnapshot;
    if (previous != null && _isDuplicate(previous, snapshot)) {
      return;
    }
    _lastSnapshot = snapshot;
    _add(snapshot);
  }

  static bool _isDuplicate(PlayerSnapshot previous, PlayerSnapshot next) {
    if (previous.status != next.status ||
        previous.playing != next.playing ||
        previous.duration != next.duration ||
        previous.currentIndex != next.currentIndex ||
        !identical(previous.currentItem, next.currentItem) ||
        !identical(previous.queue, next.queue) ||
        previous.error != next.error ||
        previous.loopMode != next.loopMode ||
        previous.shuffle != next.shuffle ||
        previous.volume != next.volume ||
        previous.speed != next.speed) {
      return false;
    }
    final positionDelta =
        next.position.inMilliseconds - previous.position.inMilliseconds;
    return positionDelta.abs() < duplicatePositionWindow.inMilliseconds;
  }
}

abstract class AudioPlayerService {
  Stream<PlayerSnapshot> get snapshot;

  /// The latest state is used as the initial value when a new screen starts
  /// listening after playback has already begun.
  PlayerSnapshot? get currentSnapshot => null;

  Future<void> setQueue(List<PlayableItem> items, {int startIndex = 0});

  Future<void> play();

  Future<void> pause();

  Future<void> next();

  Future<void> previous();

  Future<void> seek(Duration position);

  Future<void> setLoopMode(AppLoopMode mode);

  Future<void> setShuffle(bool enabled);

  Future<void> playAt(int index);

  Future<void> insertNext(PlayableItem item);

  Future<void> removeAt(int index);

  Future<void> moveItem(int from, int to);

  Future<void> setVolume(double value);

  Future<void> setSpeed(double value);

  /// Routes playback to a specific output device, or restores the system
  /// default routing when [deviceId] is null. Returns whether the platform
  /// applied the request.
  Future<bool> setPreferredOutputDevice(int? deviceId);

  Future<void> setEqualizer(EqualizerSettings settings);

  Future<void> dispose();
}

void addSubscription(
  List<StreamSubscription<dynamic>> subscriptions,
  Stream<dynamic> stream,
  void Function(dynamic value) onData,
) {
  subscriptions.add(stream.listen(onData));
}

/// Applies a short volume envelope without blocking the playback engine.
/// Calling [cancel] invalidates an in-flight envelope, which prevents a stale
/// pause/next operation from restoring an old volume after the user changes
/// it manually.
class VolumeFader {
  int _generation = 0;

  void cancel() {
    _generation++;
  }

  Future<void> fade({
    required double from,
    required double to,
    required Future<void> Function(double value) apply,
    Duration duration = const Duration(milliseconds: 300),
  }) async {
    final generation = ++_generation;
    const steps = 15;
    final stepDuration = Duration(
      milliseconds: duration.inMilliseconds ~/ steps,
    );
    for (var step = 1; step <= steps; step++) {
      await Future<void>.delayed(stepDuration);
      if (generation != _generation) {
        return;
      }
      final value = from + (to - from) * (step / steps);
      await apply(value.clamp(0, 1).toDouble());
    }
  }
}
