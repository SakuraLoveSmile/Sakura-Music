import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramusic/audio/audio_player_service.dart';
import 'package:sakuramusic/audio/equalizer_models.dart';
import 'package:sakuramusic/audio/sleep_timer_controller.dart';

class _FakeAudioPlayerService implements AudioPlayerService {
  final _controller = StreamController<PlayerSnapshot>.broadcast();
  final List<double> volumeCalls = <double>[];
  int pauseCalls = 0;
  PlayerSnapshot _current = const PlayerSnapshot(volume: 1.0);

  void emit(PlayerSnapshot snapshot) {
    _current = snapshot;
    _controller.add(snapshot);
  }

  @override
  PlayerSnapshot? get currentSnapshot => _current;

  @override
  Stream<PlayerSnapshot> get snapshot => _controller.stream;

  @override
  Future<void> setQueue(List<PlayableItem> items, {int startIndex = 0}) async {}

  @override
  Future<void> play() async {}

  @override
  Future<void> pause() async {
    pauseCalls++;
  }

  @override
  Future<void> next() async {}

  @override
  Future<void> previous() async {}

  @override
  Future<void> seek(Duration position) async {}

  @override
  Future<void> setLoopMode(AppLoopMode mode) async {}

  @override
  Future<void> setShuffle(bool enabled) async {}

  @override
  Future<void> playAt(int index) async {}

  @override
  Future<void> insertNext(PlayableItem item) async {}

  @override
  Future<void> removeAt(int index) async {}

  @override
  Future<void> moveItem(int from, int to) async {}

  @override
  Future<void> setVolume(double value) async {
    volumeCalls.add(value);
  }

  @override
  Future<void> setSpeed(double value) async {}

  @override
  Future<bool> setPreferredOutputDevice(int? deviceId) async => false;

  @override
  Future<void> setEqualizer(EqualizerSettings settings) async {}

  @override
  Future<void> dispose() async {}
}

SleepTimerController _controller(_FakeAudioPlayerService service) {
  final controller = SleepTimerController(
    service: service,
    fadeDuration: const Duration(milliseconds: 100),
  );
  addTearDown(controller.dispose);
  return controller;
}

void main() {
  test('cancel during countdown keeps the volume untouched', () async {
    final service = _FakeAudioPlayerService();
    final controller = _controller(service);

    controller.start(const Duration(hours: 1));
    expect(controller.isActive, isTrue);
    expect(controller.phase, SleepTimerPhase.countdown);

    controller.cancel();
    await Future<void>.delayed(const Duration(milliseconds: 30));

    expect(controller.isActive, isFalse);
    expect(controller.phase, SleepTimerPhase.inactive);
    expect(service.volumeCalls, isEmpty);
    expect(service.pauseCalls, 0);
  });

  test('replacing a timer invalidates the previous one', () async {
    final service = _FakeAudioPlayerService();
    final controller = _controller(service);

    // A timer about to fire, replaced before it can fade anything.
    controller.start(const Duration(milliseconds: 150));
    await Future<void>.delayed(const Duration(milliseconds: 60));
    controller.start(const Duration(hours: 1));

    await Future<void>.delayed(const Duration(milliseconds: 400));
    expect(service.volumeCalls, isEmpty);
    expect(service.pauseCalls, 0);
    expect(controller.phase, SleepTimerPhase.countdown);
    expect(
      controller.remaining,
      greaterThanOrEqualTo(const Duration(minutes: 59)),
    );

    // The replacement itself still fires when its time comes.
    controller.start(const Duration(milliseconds: 150));
    await Future<void>.delayed(const Duration(milliseconds: 500));
    expect(service.pauseCalls, 1);
    expect(controller.isActive, isFalse);
  });

  test('countdown fades the volume, pauses and restores it', () async {
    final service = _FakeAudioPlayerService();
    final controller = _controller(service);

    controller.start(const Duration(milliseconds: 150));
    await Future<void>.delayed(const Duration(milliseconds: 600));

    expect(service.pauseCalls, 1);
    expect(controller.isActive, isFalse);
    // Ten fade steps down from 1.0, then the restore back to the volume the
    // fade started from.
    expect(service.volumeCalls.length, 11);
    for (var step = 1; step <= 10; step++) {
      expect(service.volumeCalls[step - 1], closeTo(1.0 - step / 10, 0.001));
    }
    expect(service.volumeCalls.last, 1.0);
  });

  test('cancelling mid-fade stops the fade and restores the volume', () async {
    final service = _FakeAudioPlayerService();
    final controller = _controller(service);

    controller.start(const Duration(milliseconds: 150));
    // Let the countdown end and the fade begin, then cancel mid-fade.
    await Future<void>.delayed(const Duration(milliseconds: 200));
    expect(controller.phase, SleepTimerPhase.fading);

    controller.cancel();
    await Future<void>.delayed(const Duration(milliseconds: 300));

    expect(controller.isActive, isFalse);
    // The fade was interrupted: playback never paused.
    expect(service.pauseCalls, 0);
    // The last volume write restores the pre-fade level.
    expect(service.volumeCalls, isNotEmpty);
    expect(service.volumeCalls.last, 1.0);
  });

  test('endOfTrack pauses when the player reports a completed track', () async {
    final service = _FakeAudioPlayerService();
    final controller = _controller(service);

    controller.startEndOfTrack();
    expect(controller.isEndOfTrack, isTrue);

    // Ordinary snapshots do not stop the timer.
    service.emit(
      const PlayerSnapshot(
        status: PlayerStatus.ready,
        playing: true,
        currentItem: PlayableItem(
          id: 'song-1',
          title: 'Song',
          streamUrl: 'https://host/stream',
        ),
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(service.pauseCalls, 0);
    expect(controller.isEndOfTrack, isTrue);

    service.emit(
      const PlayerSnapshot(
        status: PlayerStatus.completed,
        currentItem: PlayableItem(
          id: 'song-1',
          title: 'Song',
          streamUrl: 'https://host/stream',
        ),
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(service.pauseCalls, 1);
    expect(controller.isActive, isFalse);
  });
}
