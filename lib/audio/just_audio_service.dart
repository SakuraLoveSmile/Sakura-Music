// ignore_for_file: experimental_member_use

import 'dart:async';
import 'dart:io';

import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart';

import 'audio_cache_manager.dart';
import 'audio_player_service.dart';
import 'equalizer_models.dart';

class JustAudioPlayerService implements AudioPlayerService {
  JustAudioPlayerService({AudioPlayer? player})
    : this._withEqualizer(
        player,
        Platform.isAndroid ? AndroidEqualizer() : null,
      );

  JustAudioPlayerService._withEqualizer(AudioPlayer? player, this._equalizer)
    : _player =
          player ??
          AudioPlayer(
            audioPipeline: _equalizer == null
                ? null
                : AudioPipeline(
                    androidAudioEffects: <AndroidAudioEffect>[_equalizer],
                  ),
          ) {
    _snapshotEmitter = PlayerSnapshotEmitter(_snapshotController.add);
    addSubscription(_subscriptions, _player.playerStateStream, (_) => _emit());
    addSubscription(
      _subscriptions,
      _player.positionStream,
      (_) => _emit(positionChanged: true),
    );
    addSubscription(_subscriptions, _player.durationStream, (_) => _emit());
    addSubscription(_subscriptions, _player.currentIndexStream, (_) => _emit());
  }

  final AudioPlayer _player;
  final AndroidEqualizer? _equalizer;
  final StreamController<PlayerSnapshot> _snapshotController =
      StreamController<PlayerSnapshot>.broadcast();
  late final PlayerSnapshotEmitter _snapshotEmitter;
  PlayerSnapshot? _latestSnapshot;
  final List<StreamSubscription<dynamic>> _subscriptions =
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

  @override
  Future<void> setQueue(List<PlayableItem> items, {int startIndex = 0}) async {
    _queue = List<PlayableItem>.unmodifiable(items);
    if (_queue.isEmpty) {
      await _player.stop();
      _emit();
      return;
    }
    final index = startIndex.clamp(0, _queue.length - 1);
    final cacheDirectory = await AudioCacheManager.directory();
    unawaited(AudioCacheManager.trim(cacheDirectory).catchError((_) {}));
    final sources = _queue
        .map(
          (item) => LockCachingAudioSource(
            Uri.parse(item.streamUrl),
            cacheFile: AudioCacheManager.fileFor(
              cacheDirectory,
              item.streamUrl,
            ),
            tag: item,
          ),
        )
        .toList(growable: false);
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
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());
    if (await session.setActive(true)) {
      _volumeFader.cancel();
      await _applyVolume(0);
      await _player.play();
      unawaited(_fadeTo(_volume));
    }
  }

  @override
  Future<void> pause() async {
    if (_player.playerState.playing) {
      await _fadeTo(0);
    }
    await _player.pause();
    await _applyVolume(_volume);
  }

  @override
  Future<void> next() async {
    final wasPlaying = _player.playerState.playing;
    if (wasPlaying) {
      await _fadeTo(0);
    }
    await _player.seekToNext();
    if (wasPlaying) {
      unawaited(_fadeTo(_volume));
    }
  }

  @override
  Future<void> previous() async {
    final wasPlaying = _player.playerState.playing;
    if (wasPlaying) {
      await _fadeTo(0);
    }
    await _player.seekToPrevious();
    if (wasPlaying) {
      unawaited(_fadeTo(_volume));
    }
  }

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> setLoopMode(AppLoopMode mode) async {
    _loopMode = mode;
    await _player.setLoopMode(_toJustAudioLoopMode(mode));
    _emit();
  }

  @override
  Future<void> setShuffle(bool enabled) async {
    _shuffle = enabled;
    await _player.setShuffleModeEnabled(enabled);
    _emit();
  }

  @override
  Future<void> playAt(int index) async {
    _checkIndex(index);
    final wasPlaying = _player.playerState.playing;
    if (wasPlaying) {
      await _fadeTo(0);
    }
    await _player.seek(Duration.zero, index: index);
    if (wasPlaying) {
      await _player.play();
      unawaited(_fadeTo(_volume));
    }
  }

  @override
  Future<void> insertNext(PlayableItem item) async {
    final index = (_player.currentIndex ?? -1) + 1;
    final insertIndex = index.clamp(0, _queue.length);
    await _player.insertAudioSource(
      insertIndex,
      LockCachingAudioSource(Uri.parse(item.streamUrl), tag: item),
    );
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

  Future<void> _fadeTo(double target) async {
    await _volumeFader.fade(
      from: _appliedVolume,
      to: target,
      apply: _applyVolume,
      duration: const Duration(milliseconds: 120),
    );
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
    _equalizerSettings = settings;
    await _applyEqualizer();
  }

  Future<void> _applyEqualizer() async {
    final equalizer = _equalizer;
    if (equalizer == null) {
      return;
    }
    await equalizer.setEnabled(_equalizerSettings.enabled);
    try {
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
    } on TimeoutException {
      // The native effect becomes ready with the first audio source; setQueue
      // calls this method again after that activation.
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
    _snapshotEmitter.dispose();
    await _player.dispose();
    await _snapshotController.close();
  }
}
