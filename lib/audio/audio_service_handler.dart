import 'dart:async';

import 'package:audio_service/audio_service.dart';

import 'audio_player_service.dart';
import 'equalizer_models.dart';
import 'just_audio_service.dart';

class AudioServiceHandler extends BaseAudioHandler
    implements AudioPlayerService {
  AudioServiceHandler({JustAudioPlayerService? delegate})
    : _delegate = delegate ?? JustAudioPlayerService() {
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
    queue.add(items.map(_mediaItemFor).toList(growable: false));
    await _delegate.setQueue(items, startIndex: startIndex);
  }

  @override
  Future<void> play() => _delegate.play();

  @override
  Future<void> pause() => _delegate.pause();

  @override
  Future<void> next() => _delegate.next();

  @override
  Future<void> previous() => _delegate.previous();

  @override
  Future<void> skipToNext() => next();

  @override
  Future<void> skipToPrevious() => previous();

  @override
  Future<void> seek(Duration position) => _delegate.seek(position);

  @override
  Future<void> setLoopMode(AppLoopMode mode) => _delegate.setLoopMode(mode);

  @override
  Future<void> setShuffle(bool enabled) => _delegate.setShuffle(enabled);

  @override
  Future<void> playAt(int index) => _delegate.playAt(index);

  @override
  Future<void> insertNext(PlayableItem item) async {
    await _delegate.insertNext(item);
    _syncQueue(_lastQueue);
  }

  @override
  Future<void> removeAt(int index) async {
    await _delegate.removeAt(index);
    _syncQueue(_lastQueue);
  }

  @override
  Future<void> moveItem(int from, int to) async {
    await _delegate.moveItem(from, to);
    _syncQueue(_lastQueue);
  }

  @override
  Future<void> setVolume(double value) => _delegate.setVolume(value);

  @override
  Future<void> setSpeed(double speed) => _delegate.setSpeed(speed);

  @override
  Future<void> setEqualizer(EqualizerSettings settings) =>
      _delegate.setEqualizer(settings);

  List<PlayableItem> _lastQueue = const <PlayableItem>[];

  void _publishSnapshot(PlayerSnapshot snapshot) {
    _lastQueue = snapshot.queue;
    _syncQueue(snapshot.queue);
    final item = snapshot.currentItem;
    if (item != null) {
      mediaItem.add(_mediaItemFor(item));
    }
    playbackState.add(
      PlaybackState(
        controls: const <MediaControl>[
          MediaControl.skipToPrevious,
          MediaControl.play,
          MediaControl.pause,
          MediaControl.skipToNext,
        ],
        systemActions: const <MediaAction>{MediaAction.seek},
        androidCompactActionIndices: const <int>[0, 1, 3],
        processingState: switch (snapshot.status) {
          PlayerStatus.idle => AudioProcessingState.idle,
          PlayerStatus.loading => AudioProcessingState.loading,
          PlayerStatus.buffering => AudioProcessingState.buffering,
          PlayerStatus.ready => AudioProcessingState.ready,
          PlayerStatus.completed => AudioProcessingState.completed,
          PlayerStatus.error => AudioProcessingState.error,
        },
        playing: snapshot.playing,
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
