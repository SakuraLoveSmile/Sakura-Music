import 'dart:async';

import 'package:audio_service/audio_service.dart';

import 'audio_player_service.dart';
import 'equalizer_models.dart';
import 'just_audio_service.dart';
import 'playback_debug_log.dart';

class AudioServiceHandler extends BaseAudioHandler
    implements AudioPlayerService {
  AudioServiceHandler({
    JustAudioPlayerService? delegate,
    bool disableEqualizerPipeline = false,
  }) : _delegate = delegate ??
            JustAudioPlayerService(
              disableEqualizerPipeline: disableEqualizerPipeline,
            ) {
    _subscription = _delegate.snapshot.listen(_publishSnapshot);
  }

  final JustAudioPlayerService _delegate;
  late final StreamSubscription<PlayerSnapshot> _subscription;

  @override
  Stream<PlayerSnapshot> get snapshot => _delegate.snapshot;

  @override
  PlayerSnapshot? get currentSnapshot => _delegate.currentSnapshot;

  @override
  Future<void> setQueue(List<PlayableItem> items, {int startIndex = 0}) async {
    playbackDebugLog.add('AudioServiceHandler.setQueue');
    _stopped = false;
    queue.add(items.map(_mediaItemFor).toList(growable: false));
    await _delegate.setQueue(items, startIndex: startIndex);
  }

  @override
  Future<void> play() {
    playbackDebugLog.add('AudioServiceHandler.play');
    _stopped = false;
    return _delegate.play();
  }

  @override
  Future<void> pause() {
    playbackDebugLog.add('AudioServiceHandler.pause');
    return _delegate.pause();
  }

  @override
  Future<void> next() {
    playbackDebugLog.add('AudioServiceHandler.next');
    return _delegate.next();
  }

  @override
  Future<void> previous() {
    playbackDebugLog.add('AudioServiceHandler.previous');
    return _delegate.previous();
  }

  @override
  Future<void> skipToNext() {
    playbackDebugLog.add('AudioServiceHandler.skipToNext');
    return next();
  }

  @override
  Future<void> skipToPrevious() {
    playbackDebugLog.add('AudioServiceHandler.skipToPrevious');
    return previous();
  }

  @override
  Future<void> seek(Duration position) {
    playbackDebugLog.add('AudioServiceHandler.seek');
    return _delegate.seek(position);
  }

  @override
  Future<void> setLoopMode(AppLoopMode mode) {
    playbackDebugLog.add('AudioServiceHandler.setLoopMode');
    return _delegate.setLoopMode(mode);
  }

  @override
  Future<void> setShuffle(bool enabled) {
    playbackDebugLog.add('AudioServiceHandler.setShuffle');
    return _delegate.setShuffle(enabled);
  }

  @override
  Future<void> playAt(int index) {
    playbackDebugLog.add('AudioServiceHandler.playAt');
    return _delegate.playAt(index);
  }

  @override
  Future<void> stop() async {
    playbackDebugLog.add('AudioServiceHandler.stop');
    _stopped = true;
    await _delegate.pause();
    playbackState.add(
      playbackState.value.copyWith(
        processingState: AudioProcessingState.idle,
        playing: false,
      ),
    );
  }

  @override
  Future<void> insertNext(PlayableItem item) async {
    playbackDebugLog.add('AudioServiceHandler.insertNext');
    await _delegate.insertNext(item);
    _syncQueue(_lastQueue);
  }

  @override
  Future<void> removeAt(int index) async {
    playbackDebugLog.add('AudioServiceHandler.removeAt');
    await _delegate.removeAt(index);
    _syncQueue(_lastQueue);
  }

  @override
  Future<void> moveItem(int from, int to) async {
    playbackDebugLog.add('AudioServiceHandler.moveItem');
    await _delegate.moveItem(from, to);
    _syncQueue(_lastQueue);
  }

  @override
  Future<void> setVolume(double value) {
    playbackDebugLog.add('AudioServiceHandler.setVolume');
    return _delegate.setVolume(value);
  }

  @override
  Future<void> setSpeed(double speed) {
    playbackDebugLog.add('AudioServiceHandler.setSpeed');
    return _delegate.setSpeed(speed);
  }

  @override
  Future<void> setEqualizer(EqualizerSettings settings) {
    playbackDebugLog.add('AudioServiceHandler.setEqualizer');
    return _delegate.setEqualizer(settings);
  }

  List<PlayableItem> _lastQueue = const <PlayableItem>[];
  bool _stopped = false;

  void _publishSnapshot(PlayerSnapshot snapshot) {
    _lastQueue = snapshot.queue;
    _syncQueue(snapshot.queue);
    final item = snapshot.currentItem;
    if (item != null) {
      mediaItem.add(_mediaItemFor(item));
    }
    final controls = snapshot.playing
        ? const <MediaControl>[
            MediaControl.skipToPrevious,
            MediaControl.pause,
            MediaControl.skipToNext,
          ]
        : const <MediaControl>[
            MediaControl.skipToPrevious,
            MediaControl.play,
            MediaControl.skipToNext,
          ];
    playbackState.add(
      PlaybackState(
        controls: controls,
        systemActions: const <MediaAction>{MediaAction.seek},
        androidCompactActionIndices: const <int>[0, 1, 2],
        processingState: _stopped
            ? AudioProcessingState.idle
            : switch (snapshot.status) {
                PlayerStatus.idle => AudioProcessingState.idle,
                PlayerStatus.loading => AudioProcessingState.loading,
                PlayerStatus.buffering => AudioProcessingState.buffering,
                PlayerStatus.ready => AudioProcessingState.ready,
                PlayerStatus.completed => AudioProcessingState.completed,
                PlayerStatus.error => AudioProcessingState.error,
              },
        playing: _stopped ? false : snapshot.playing,
        updatePosition: snapshot.position,
        bufferedPosition: snapshot.position,
        queueIndex: snapshot.currentIndex,
      ),
    );
  }

  void _syncQueue(List<PlayableItem> items) {
    queue.add(items.map(_mediaItemFor).toList(growable: false));
  }

  MediaItem _mediaItemFor(PlayableItem item) {
    return MediaItem(
      id: item.id,
      title: item.title,
      artist: item.artist,
      album: item.album,
      duration: item.duration,
      artUri: item.artworkUrl == null ? null : Uri.tryParse(item.artworkUrl!),
    );
  }

  @override
  Future<void> dispose() async {
    await _subscription.cancel();
    await _delegate.dispose();
  }
}
