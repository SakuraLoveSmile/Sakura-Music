import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramusic/audio/audio_player_service.dart';

void main() {
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
