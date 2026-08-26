// ignore_for_file: experimental_member_use

import 'dart:async';
import 'dart:io';

import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';

import 'audio_player_service.dart';
import 'equalizer_controller.dart';
import 'equalizer_models.dart';
import 'playback_debug_log.dart';

class JustAudioPlayerService implements AudioPlayerService {
  JustAudioPlayerService({
    AudioPlayer? player,
    bool disableEqualizerPipeline = true,
  }) : this._withEqualizer(
         player,
         (player == null && !disableEqualizerPipeline && Platform.isAndroid)
             ? AndroidEqualizer()
             : null,
       );

  JustAudioPlayerService._withEqualizer(
    AudioPlayer? player,
    AndroidEqualizer? realEqualizer,
  ) : _player =
          player ??
          AudioPlayer(
            audioPipeline: realEqualizer == null
                ? null
                : AudioPipeline(
                    androidAudioEffects: <AndroidAudioEffect>[realEqualizer],
                  ),
          ),
      _equalizer = realEqualizer == null
          ? null
          : AndroidEqualizerController(realEqualizer) {
    _init();
  }

  /// Test-only constructor that injects a [EqualizerController] (a fake in
  /// tests) so the equalizer retry path can be exercised without a native
  /// audio engine.
  @visibleForTesting
  JustAudioPlayerService.withController(
    EqualizerController? equalizer, {
    AudioPlayer? player,
  }) : _player = player ?? AudioPlayer(),
       _equalizer = equalizer {
    _init();
  }

  void _init() {
    _snapshotEmitter = PlayerSnapshotEmitter(_snapshotController.add);
    addSubscription(_subscriptions, _player.playerStateStream, (_) => _emit());
    addSubscription(
      _subscriptions,
      _player.positionStream,
      (_) => _emit(positionChanged: true),
    );
    addSubscription(_subscriptions, _player.durationStream, (_) => _emit());
    addSubscription(_subscriptions, _player.currentIndexStream, (_) => _emit());
    addSubscription(_subscriptions, _player.playerStateStream, _onPlayerState);
    unawaited(_initSessionLogging());
  }

  void _logPlayerState(dynamic state) {
    final playing = state.playing as bool? ?? false;
    final processing = state.processingState;
    playbackDebugLog.add(
      'playerState: processing=$processing playing=$playing',
    );
  }

  /// Logs player-state transitions and retries the equalizer once the player
  /// reaches `ready` if a previous [setQueue] attempt timed out.
  void _onPlayerState(dynamic state) {
    _logPlayerState(state);
    final processing = state.processingState;
    if (processing == ProcessingState.ready && _equalizerRetryPending) {
      unawaited(_retryEqualizerAfterReady());
    }
  }

  Future<void> _retryEqualizerAfterReady() async {
    if (!_equalizerRetryPending) {
      return;
    }
    // Consume the pending marker so a single ready transition triggers exactly
    // one retry; a failed retry re-arms the marker for the next transition.
    _equalizerRetryPending = false;
    final success = await _applyEqualizer();
    playbackDebugLog.add(
      success
          ? 'setEqualizer: re-applied after ready'
          : 'setEqualizer: still not ready after ready',
    );
  }

  Future<void> _initSessionLogging() async {
    try {
      final session = await AudioSession.instance;
      _sessionSubscriptions.add(
        session.interruptionEventStream.listen((event) {
          playbackDebugLog.add(
            'AudioSession interruption: begin=${event.begin} '
            'type=${event.type}',
          );
        }),
      );
      _sessionSubscriptions.add(
        session.becomingNoisyEventStream.listen((_) {
          playbackDebugLog.add('AudioSession becomingNoisy');
        }),
      );
    } catch (error, stackTrace) {
      playbackDebugLog.add('AudioSession logging init failed: $error');
      debugPrintStack(stackTrace: stackTrace, label: 'PlaybackDebug');
    }
  }

  final AudioPlayer _player;
  final EqualizerController? _equalizer;
  bool _equalizerRetryPending = false;

  @visibleForTesting
  bool get equalizerRetryPendingForTest => _equalizerRetryPending;

  final StreamController<PlayerSnapshot> _snapshotController =
      StreamController<PlayerSnapshot>.broadcast();
  late final PlayerSnapshotEmitter _snapshotEmitter;
  PlayerSnapshot? _latestSnapshot;
  final List<StreamSubscription<dynamic>> _subscriptions =
      <StreamSubscription<dynamic>>[];
  final List<StreamSubscription<dynamic>> _sessionSubscriptions =
      <StreamSubscription<dynamic>>[];
  List<PlayableItem> _queue = const <PlayableItem>[];
  AppLoopMode _loopMode = AppLoopMode.off;
  bool _shuffle = false;
  double _volume = 1;
  double _appliedVolume = 1;
  double _speed = 1;
  EqualizerSettings _equalizerSettings = const EqualizerSettings();
  final VolumeFader _volumeFader = VolumeFader();
  bool _disposed = false;

  @override
  Stream<PlayerSnapshot> get snapshot => _snapshotController.stream;

  @override
  PlayerSnapshot? get currentSnapshot => _latestSnapshot;

  @visibleForTesting
  void setQueueForTest(List<PlayableItem> items) {
    _queue = List<PlayableItem>.unmodifiable(items);
  }

  static AudioSource _createAudioSource(PlayableItem item) {
    final uri = Uri.parse(item.streamUrl);
    return AudioSource.uri(uri, headers: item.headers, tag: item);
  }

  @override
  Future<void> setQueue(List<PlayableItem> items, {int startIndex = 0}) async {
    playbackDebugLog.add(
      'setQueue: ${items.length} items startIndex=$startIndex',
    );
    _equalizerRetryPending = false;
    _queue = List<PlayableItem>.unmodifiable(items);
    if (_queue.isEmpty) {
      await _player.stop();
      _emit();
      return;
    }
    final index = startIndex.clamp(0, _queue.length - 1);
    final sources = _queue.map(_createAudioSource).toList(growable: false);
    await _player.setAudioSources(sources, initialIndex: index, preload: false);
    await _player.setLoopMode(_toJustAudioLoopMode(_loopMode));
    await _player.setShuffleModeEnabled(_shuffle);
    await _player.setVolume(_volume);
    _appliedVolume = _volume;
    await _player.setSpeed(_speed);
    await _applyEqualizer();
    _emit();
  }

  @override
  Future<void> play() async {
    playbackDebugLog.add('play');
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());
    final active = await session.setActive(true);
    // A failed audio-focus activation must not block playback: on some
    // devices setActive returns false even though audio is perfectly usable.
    // Previously this silently skipped playing; now we warn and continue.
    playbackDebugLog.add('AudioSession.setActive -> $active');
    _volumeFader.cancel();
    await _applyVolume(_volume);
    await _player.play();
    playbackDebugLog.add(
      'play: active volume=${_appliedVolume.toStringAsFixed(2)}',
    );
  }

  @override
  Future<void> pause() async {
    playbackDebugLog.add('pause');
    _volumeFader.cancel();
    await _player.pause();
  }

  @override
  Future<void> next() async {
    playbackDebugLog.add('next');
    _volumeFader.cancel();
    await _player.seekToNext();
  }

  @override
  Future<void> previous() async {
    playbackDebugLog.add('previous');
    _volumeFader.cancel();
    await _player.seekToPrevious();
  }

  @override
  Future<void> seek(Duration position) {
    playbackDebugLog.add('seek: ${position.inMilliseconds}ms');
    return _player.seek(position);
  }

  @override
  Future<void> setLoopMode(AppLoopMode mode) async {
    playbackDebugLog.add('setLoopMode: ${mode.name}');
    _loopMode = mode;
    await _player.setLoopMode(_toJustAudioLoopMode(mode));
    _emit();
  }

  @override
  Future<void> setShuffle(bool enabled) async {
    playbackDebugLog.add('setShuffle: $enabled');
    _shuffle = enabled;
    await _player.setShuffleModeEnabled(enabled);
    _emit();
  }

  @override
  Future<void> playAt(int index) async {
    playbackDebugLog.add('playAt: $index');
    _checkIndex(index);
    _volumeFader.cancel();
    await _player.seek(Duration.zero, index: index);
    await _applyVolume(_volume);
    await _player.play();
    playbackDebugLog.add(
      'playAt: active volume=${_appliedVolume.toStringAsFixed(2)}',
    );
  }

  @override
  Future<void> insertNext(PlayableItem item) async {
    final index = (_player.currentIndex ?? -1) + 1;
    final insertIndex = index.clamp(0, _queue.length);
    await _player.insertAudioSource(insertIndex, _createAudioSource(item));
    final updated = <PlayableItem>[..._queue]..insert(insertIndex, item);
    _queue = List<PlayableItem>.unmodifiable(updated);
    _emit();
  }

  @override
  Future<void> removeAt(int index) async {
    _checkIndex(index);
    await _player.removeAudioSourceAt(index);
    final updated = <PlayableItem>[..._queue]..removeAt(index);
    _queue = List<PlayableItem>.unmodifiable(updated);
    _emit();
  }

  @override
  Future<void> moveItem(int from, int to) async {
    _checkIndex(from);
    _checkIndex(to);
    if (from == to) {
      return;
    }
    await _player.moveAudioSource(from, to);
    final updated = <PlayableItem>[..._queue];
    final item = updated.removeAt(from);
    updated.insert(to, item);
    _queue = List<PlayableItem>.unmodifiable(updated);
    _emit();
  }

  @override
  Future<void> setVolume(double value) async {
    playbackDebugLog.add('setVolume: $value');
    _checkVolume(value);
    _volume = value;
    _volumeFader.cancel();
    await _player.setVolume(value);
    _appliedVolume = value;
    _emit();
  }

  Future<void> _applyVolume(double value) async {
    await _player.setVolume(value);
    _appliedVolume = value;
  }

  @override
  Future<bool> setPreferredOutputDevice(int? deviceId) async {
    playbackDebugLog.add('setPreferredDevice: deviceId=$deviceId');
    final applied = await _player.setPreferredDevice(deviceId);
    playbackDebugLog.add('setPreferredDevice: applied=$applied');
    return applied;
  }

  @override
  Future<void> setSpeed(double value) async {
    if (value <= 0) {
      throw ArgumentError.value(value, 'value', 'must be positive');
    }
    _speed = value;
    await _player.setSpeed(value);
    _emit();
  }

  @override
  Future<void> setEqualizer(EqualizerSettings settings) async {
    playbackDebugLog.add(
      'setEqualizer: enabled=${settings.enabled} '
      'gains=${settings.gains} preset=${settings.preset.name}',
    );
    _equalizerSettings = settings;
    await _applyEqualizer();
  }

  /// Applies the current [_equalizerSettings] to the native effect.
  ///
  /// The Android effect only reports its parameters once the first audio
  /// source has activated, so a call during [setQueue] can legitimately time
  /// out. When that happens (or a [PlatformException] is thrown) we return
  /// `false` and mark [_equalizerRetryPending]; the player-state subscription
  /// retries exactly once after the player reaches `ready`. Returns `true`
  /// when the settings were applied (or when there is no effect to apply).
  Future<bool> _applyEqualizer() async {
    final equalizer = _equalizer;
    if (equalizer == null) {
      playbackDebugLog.add('setEqualizer: no equalizer (pipeline disabled)');
      return true;
    }
    try {
      await equalizer.setEnabled(_equalizerSettings.enabled);
      final parameters = await equalizer.parameters.timeout(
        const Duration(milliseconds: 250),
      );
      for (
        var index = 0;
        index < parameters.bands.length &&
            index < _equalizerSettings.gains.length;
        index++
      ) {
        await parameters.bands[index].setGain(
          _equalizerSettings.gains[index]
              .clamp(parameters.minDecibels, parameters.maxDecibels)
              .toDouble(),
        );
      }
      playbackDebugLog.add(
        'setEqualizer: applied ${parameters.bands.length} bands',
      );
      return true;
    } on TimeoutException {
      // The native effect becomes ready with the first audio source; the
      // player-state subscription retries once the player reaches `ready`.
      playbackDebugLog.add('setEqualizer: parameters not ready (timeout)');
      _equalizerRetryPending = true;
      return false;
    } on PlatformException catch (error) {
      // Some Android audio effect implementations are not ready yet. A
      // missing equalizer must not prevent the queue from being loaded.
      playbackDebugLog.add('setEqualizer: PlatformException $error');
      _equalizerRetryPending = true;
      return false;
    }
  }

  void _emit({bool positionChanged = false}) {
    if (_disposed) {
      return;
    }
    final index = _player.currentIndex;
    final currentItem = index == null || index >= _queue.length
        ? null
        : _queue[index];
    final playerState = _player.playerState;
    final status = switch (playerState.processingState) {
      ProcessingState.idle => PlayerStatus.idle,
      ProcessingState.loading => PlayerStatus.loading,
      ProcessingState.buffering => PlayerStatus.buffering,
      ProcessingState.ready => PlayerStatus.ready,
      ProcessingState.completed => PlayerStatus.completed,
    };
    final snapshot = PlayerSnapshot(
      status: status,
      playing: playerState.playing,
      position: _player.position,
      duration: _player.duration ?? currentItem?.duration,
      currentIndex: index,
      currentItem: currentItem,
      queue: _queue,
      loopMode: _loopMode,
      shuffle: _shuffle,
      volume: _volume,
      speed: _speed,
    );
    _latestSnapshot = snapshot;
    _snapshotEmitter.emit(snapshot, positionChanged: positionChanged);
  }

  static LoopMode _toJustAudioLoopMode(AppLoopMode mode) {
    return switch (mode) {
      AppLoopMode.off => LoopMode.off,
      AppLoopMode.all => LoopMode.all,
      AppLoopMode.one => LoopMode.one,
    };
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

  @override
  Future<void> dispose() async {
    _disposed = true;
    _volumeFader.cancel();
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    for (final subscription in _sessionSubscriptions) {
      await subscription.cancel();
    }
    _snapshotEmitter.dispose();
    await _player.dispose();
    await _snapshotController.close();
  }
}
