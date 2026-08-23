import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:sakuramusic/audio/audio_player_service.dart';
import 'package:sakuramusic/audio/just_audio_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const item = PlayableItem(
    id: 'song-1',
    title: 'Song',
    streamUrl: 'https://example.test/song.mp3',
  );
  const queue = <PlayableItem>[item];

  PlayerSnapshot snapshot({
    Duration position = Duration.zero,
    bool playing = false,
  }) {
    return const PlayerSnapshot(
      status: PlayerStatus.ready,
      currentIndex: 0,
      currentItem: item,
      queue: queue,
    ).copyWithForTest(position: position, playing: playing);
  }

  test(
    'throttles position updates and keeps the latest pending snapshot',
    () async {
      final emitted = <PlayerSnapshot>[];
      final emitter = PlayerSnapshotEmitter(emitted.add);
      addTearDown(emitter.dispose);

      emitter.emit(snapshot());
      emitter.emit(
        snapshot(position: const Duration(milliseconds: 100)),
        positionChanged: true,
      );
      await Future<void>.delayed(const Duration(milliseconds: 100));
      emitter.emit(
        snapshot(position: const Duration(milliseconds: 700)),
        positionChanged: true,
      );

      expect(emitted, hasLength(1));
      await Future<void>.delayed(const Duration(milliseconds: 450));
      expect(emitted, hasLength(2));
      expect(emitted.last.position, const Duration(milliseconds: 700));
    },
  );

  test(
    'emits state changes immediately and cancels a pending position tick',
    () async {
      final emitted = <PlayerSnapshot>[];
      final emitter = PlayerSnapshotEmitter(emitted.add);
      addTearDown(emitter.dispose);

      emitter.emit(snapshot());
      emitter.emit(
        snapshot(position: const Duration(milliseconds: 100)),
        positionChanged: true,
      );
      emitter.emit(
        snapshot(position: const Duration(milliseconds: 100), playing: true),
      );

      expect(emitted, hasLength(2));
      expect(emitted.last.playing, isTrue);
      await Future<void>.delayed(const Duration(milliseconds: 550));
      expect(emitted, hasLength(2));
    },
  );

  test('playAt starts the selected item when the player is paused', () async {
    final player = _RecordingAudioPlayer();
    final service = JustAudioPlayerService(player: player);
    addTearDown(service.dispose);

    service.setQueueForTest(<PlayableItem>[
      item,
      const PlayableItem(
        id: 'song-2',
        title: 'Second song',
        streamUrl: 'https://example.test/song-2.mp3',
      ),
    ]);
    player.events.clear();

    // setQueue leaves the native player paused. Selecting another queue item
    // must still issue a play command.
    await service.playAt(1);

    expect(player.events, contains('seek:1'));
    expect(player.events, contains('play'));
    expect(
      player.events.indexOf('seek:1'),
      lessThan(player.events.indexOf('play')),
    );
  });
}

class _RecordingAudioPlayer extends AudioPlayer {
  final events = <String>[];

  @override
  Future<Duration?> setAudioSources(
    List<AudioSource> audioSources, {
    bool preload = true,
    int? initialIndex,
    Duration? initialPosition,
    ShuffleOrder? shuffleOrder,
  }) async {
    return null;
  }

  @override
  Future<void> setLoopMode(LoopMode mode) async {}

  @override
  Future<void> setShuffleModeEnabled(bool enabled) async {}

  @override
  Future<void> setVolume(double volume) async {
    events.add('volume:${volume.toStringAsFixed(2)}');
  }

  @override
  Future<void> setSpeed(double speed) async {}

  @override
  Future<void> seek(Duration? position, {int? index}) async {
    events.add('seek:$index');
  }

  @override
  Future<void> play() async {
    events.add('play');
  }
}

extension on PlayerSnapshot {
  PlayerSnapshot copyWithForTest({Duration? position, bool? playing}) {
    return PlayerSnapshot(
      status: status,
      playing: playing ?? this.playing,
      position: position ?? this.position,
      duration: duration,
      currentIndex: currentIndex,
      currentItem: currentItem,
      error: error,
      queue: queue,
      loopMode: loopMode,
      shuffle: shuffle,
      volume: volume,
      speed: speed,
    );
  }
}
