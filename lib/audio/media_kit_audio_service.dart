import 'dart:async';

import 'package:media_kit/media_kit.dart';

import 'audio_player_service.dart';
import 'equalizer_models.dart';
import 'playback_debug_log.dart';
import 'smtc_windows_integration.dart';

class MediaKitAudioPlayerService implements AudioPlayerService {
  MediaKitAudioPlayerService({Player? player})
    : _player =
          player ??
          Player(
            configuration: const PlayerConfiguration(
              bufferSize: 32 * 1024 * 1024,
            ),
          ) {
    _mpvCacheReady = _applyMpvCache();
    _snapshotEmitter = PlayerSnapshotEmitter(_snapshotController.add);
    _smtcIntegration = SmtcWindowsIntegration(service: this);
    addSubscription(_subscriptions, _player.stream.playing, (value) {
      _playing = value as bool;
      _emit();
    });
    addSubscription(_subscriptions, _player.stream.buffering, (value) {
      _buffering = value as bool;
      _emit();
    });
    addSubscription(_subscriptions, _player.stream.position, (value) {
      _position = value as Duration;
      _emit(positionChanged: true);
    });
    addSubscription(_subscriptions, _player.stream.duration, (value) {
      _duration = value as Duration;
      _emit();
    });
    addSubscription(_subscriptions, _player.stream.playlist, (value) {
      _index = (value as Playlist).index;
      _emit();
    });
    addSubscription(_subscriptions, _player.stream.volume, (value) {
      if (_ignoreVolumeStream) {
        return;
      }
      _volume = (value as double) / 100;
      _appliedVolume = _volume;
      _emit();
    });
    addSubscription(_subscriptions, _player.stream.rate, (value) {
      _speed = value as double;
      _emit();
    });
    addSubscription(_subscriptions, _player.stream.playlistMode, (value) {
      _loopMode = _fromMediaKitPlaylistMode(value as PlaylistMode);
      _emit();
    });
    addSubscription(_subscriptions, _player.stream.shuffle, (value) {
      _shuffle = value as bool;
      _emit();
    });
    addSubscription(_subscriptions, _player.stream.completed, (value) {
      _completed = value as bool;
      _emit();
    });
    addSubscription(_subscriptions, _player.stream.error, (value) {
      _error = value;
      _emit();
    });
  }

  final Player _player;
  late final Future<void> _mpvCacheReady;
  late final SmtcWindowsIntegration _smtcIntegration;
  final StreamController<PlayerSnapshot> _snapshotController =
      StreamController<PlayerSnapshot>.broadcast();
  late final PlayerSnapshotEmitter _snapshotEmitter;
  PlayerSnapshot? _latestSnapshot;
  final List<StreamSubscription<dynamic>> _subscriptions =
      <StreamSubscription<dynamic>>[];
  List<PlayableItem> _queue = const <PlayableItem>[];
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  int _index = 0;
  bool _playing = false;
  bool _buffering = false;
  bool _completed = false;
  AppLoopMode _loopMode = AppLoopMode.off;
  bool _shuffle = false;
  double _volume = 1;
  double _appliedVolume = 1;
  double _speed = 1;
  final VolumeFader _volumeFader = VolumeFader();
  int _fadeGeneration = 0;
  bool _ignoreVolumeStream = false;
  Object? _error;
  EqualizerSettings _equalizerSettings = const EqualizerSettings();
  bool _disposed = false;

  @override
  Stream<PlayerSnapshot> get snapshot => _snapshotController.stream;

  @override
  PlayerSnapshot? get currentSnapshot => _latestSnapshot;

  @override
  Future<void> setQueue(List<PlayableItem> items, {int startIndex = 0}) async {
    _queue = List<PlayableItem>.unmodifiable(items);
    _index = _queue.isEmpty ? 0 : startIndex.clamp(0, _queue.length - 1);
    _completed = false;
    _error = null;
    if (_queue.isEmpty) {
      await _player.stop();
      _emit();
      return;
    }
    await _mpvCacheReady;
    await _player.open(
      Playlist(
        _queue.map((item) => Media(item.streamUrl)).toList(growable: false),
        index: _index,
      ),
      play: false,
    );
    await Future.wait<void>(<Future<void>>[
      _player.setPlaylistMode(_toMediaKitPlaylistMode(_loopMode)),
      _player.setShuffle(_shuffle),
      _player.setVolume(_volume * 100),
      _player.setRate(_speed),
      _applyEqualizer(),
    ]);
    _appliedVolume = _volume;
    _emit();
  }

  @override
  Future<void> play() async {
    _completed = false;
    _fadeGeneration++;
    _volumeFader.cancel();
    await _applyVolume(0, suppressStream: true);
    await _player.play();
    unawaited(_fadeTo(_volume));
  }

  @override
  Future<void> pause() async {
    if (_playing) {
      await _fadeTo(0);
    }
    await _player.pause();
    await _applyVolume(_volume);
  }

  @override
  Future<void> next() async {
    final wasPlaying = _playing;
    if (wasPlaying) {
      await _fadeTo(0);
    }
    _completed = false;
    await _player.next();
    if (wasPlaying) {
      unawaited(_fadeTo(_volume));
    }
  }

  @override
  Future<void> previous() async {
    final wasPlaying = _playing;
    if (wasPlaying) {
      await _fadeTo(0);
    }
    _completed = false;
    await _player.previous();
    if (wasPlaying) {
      unawaited(_fadeTo(_volume));
    }
  }

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> setLoopMode(AppLoopMode mode) async {
    _loopMode = mode;
    await _player.setPlaylistMode(_toMediaKitPlaylistMode(mode));
    _emit();
  }

  @override
  Future<void> setShuffle(bool enabled) async {
    _shuffle = enabled;
    await _player.setShuffle(enabled);
    _emit();
  }

  @override
  Future<void> playAt(int index) async {
    _checkIndex(index);
    await _fadeTo(0);
    await _player.jump(index);
    await _player.play();
    unawaited(_fadeTo(_volume));
  }

  @override
  Future<void> insertNext(PlayableItem item) async {
    if (_queue.isEmpty) {
      await setQueue(<PlayableItem>[item]);
      return;
    }
    final insertIndex = ((_index + 1).clamp(0, _queue.length));
    final updated = <PlayableItem>[..._queue]..insert(insertIndex, item);
    await _reopenQueue(updated, currentItemId: _queue[_index].id);
  }

  @override
  Future<void> removeAt(int index) async {
    _checkIndex(index);
    final currentId = _queue[_index].id;
    final updated = <PlayableItem>[..._queue]..removeAt(index);
    if (updated.isEmpty) {
      _queue = const <PlayableItem>[];
      await _player.stop();
      _emit();
      return;
    }
    await _reopenQueue(
      updated,
      currentItemId: index == _index ? null : currentId,
    );
  }

  @override
  Future<void> moveItem(int from, int to) async {
    _checkIndex(from);
    _checkIndex(to);
    if (from == to) {
      return;
    }
    final currentId = _queue[_index].id;
    final updated = <PlayableItem>[..._queue];
    final item = updated.removeAt(from);
    updated.insert(to, item);
    await _reopenQueue(updated, currentItemId: currentId);
  }

  @override
  Future<void> setVolume(double value) async {
    _checkVolume(value);
    _volume = value;
    _fadeGeneration++;
    _ignoreVolumeStream = false;
    _volumeFader.cancel();
    await _player.setVolume(value * 100);
    _appliedVolume = value;
    _emit();
  }

  Future<void> _applyVolume(double value, {bool suppressStream = false}) async {
    final wasIgnoring = _ignoreVolumeStream;
    if (suppressStream) {
      _ignoreVolumeStream = true;
    }
    try {
      await _player.setVolume(value * 100);
      _appliedVolume = value;
    } finally {
      if (suppressStream) {
        _ignoreVolumeStream = wasIgnoring;
      }
    }
  }

  Future<void> _fadeTo(double target) async {
    final generation = ++_fadeGeneration;
    _ignoreVolumeStream = true;
    try {
      await _volumeFader.fade(
        from: _appliedVolume,
        to: target,
        apply: _applyVolume,
        duration: const Duration(milliseconds: 120),
      );
    } finally {
      if (generation == _fadeGeneration) {
        _ignoreVolumeStream = false;
      }
    }
  }

  @override
  Future<void> setSpeed(double value) async {
    if (value <= 0) {
      throw ArgumentError.value(value, 'value', 'must be positive');
    }
    _speed = value;
    await _player.setRate(value);
    _emit();
  }

  @override
  Future<bool> setPreferredOutputDevice(int? deviceId) async {
    playbackDebugLog.add(
      'setPreferredDevice: deviceId=$deviceId -> not supported by '
      'media_kit pipeline',
    );
    return false;
  }

  @override
  Future<void> setEqualizer(EqualizerSettings settings) async {
    _equalizerSettings = settings;
    await _applyEqualizer();
  }

  Future<void> _applyEqualizer() async {
    final settings = _equalizerSettings;
    final filter = settings.enabled
        ? List<String>.generate(
            equalizerFrequencies.length,
            (index) =>
                'equalizer=f=${equalizerFrequencies[index]}:g=${settings.gains[index].toStringAsFixed(2)}',
          ).join(',')
        : '';
    try {
      await (_player.platform as dynamic).setProperty('af', filter);
    } catch (_) {
      // The filter is unavailable on a non-native/test backend.
    }
  }

  Future<void> _applyMpvCache() async {
    try {
      await Future.wait<void>(<Future<void>>[
        (_player.platform as dynamic).setProperty('cache', 'yes'),
        (_player.platform as dynamic).setProperty('cache-secs', '60'),
      ]);
    } catch (_) {
      // Cache properties are unavailable on a non-native/test backend.
    }
  }

  void _emit({bool positionChanged = false}) {
    if (_disposed) {
      return;
    }
    final item = _index >= 0 && _index < _queue.length ? _queue[_index] : null;
    final status = _error != null
        ? PlayerStatus.error
        : _completed
        ? PlayerStatus.completed
        : _buffering
        ? PlayerStatus.buffering
        : item == null
        ? PlayerStatus.idle
        : PlayerStatus.ready;
    final snapshot = PlayerSnapshot(
      status: status,
      playing: _playing,
      position: _position,
      duration: _duration == Duration.zero ? item?.duration : _duration,
      currentIndex: item == null ? null : _index,
      currentItem: item,
      error: _error,
      queue: _queue,
      loopMode: _loopMode,
      shuffle: _shuffle,
      volume: _volume,
      speed: _speed,
    );
    _latestSnapshot = snapshot;
    _snapshotEmitter.emit(snapshot, positionChanged: positionChanged);
  }

  /// media_kit currently has no in-place playlist edit API in this wrapper,
  /// so queue edits reopen the playlist. If profiling still shows this path
  /// as perceptible, debounce and apply several edits as one reopen.
  Future<void> _reopenQueue(
    List<PlayableItem> items, {
    required String? currentItemId,
  }) async {
    final wasPlaying = _playing;
    final position = _position;
    _queue = List<PlayableItem>.unmodifiable(items);
    final restoredIndex = currentItemId == null
        ? _index.clamp(0, _queue.length - 1)
        : _queue.indexWhere((item) => item.id == currentItemId);
    _index = restoredIndex < 0 ? 0 : restoredIndex;
    await _mpvCacheReady;
    await _player.open(
      Playlist(
        _queue.map((item) => Media(item.streamUrl)).toList(growable: false),
        index: _index,
      ),
      play: wasPlaying,
    );
    await Future.wait<void>(<Future<void>>[
      _player.setPlaylistMode(_toMediaKitPlaylistMode(_loopMode)),
      _player.setShuffle(_shuffle),
      _player.setVolume(_volume * 100),
      _player.setRate(_speed),
      _applyEqualizer(),
    ]);
    _appliedVolume = _volume;
    if (position > Duration.zero) {
      await _player.seek(position);
    }
    _emit();
  }

  void _checkIndex(int index) {
    if (index < 0 || index >= _queue.length) {
      throw RangeError.index(index, _queue, 'index');
    }
  }

  void _checkVolume(double value) {
    if (value < 0 || value > 1) {
      throw ArgumentError.value(value, 'value', 'must be between 0 and 1');
    }
  }

  static PlaylistMode _toMediaKitPlaylistMode(AppLoopMode mode) {
    return switch (mode) {
      AppLoopMode.off => PlaylistMode.none,
      AppLoopMode.all => PlaylistMode.loop,
      AppLoopMode.one => PlaylistMode.single,
    };
  }

  static AppLoopMode _fromMediaKitPlaylistMode(PlaylistMode mode) {
    return switch (mode) {
      PlaylistMode.none => AppLoopMode.off,
      PlaylistMode.loop => AppLoopMode.all,
      PlaylistMode.single => AppLoopMode.one,
    };
  }

  @override
  Future<void> dispose() async {
    _disposed = true;
    _volumeFader.cancel();
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    _snapshotEmitter.dispose();
    await _player.dispose();
    await _smtcIntegration.dispose();
    await _snapshotController.close();
  }
}
