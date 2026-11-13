import 'dart:async';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:sakuramusic/audio/audio_player_service.dart';
import 'package:sakuramusic/audio/media_kit_audio_service.dart';
import 'package:sakuramusic/audio/playback_coordinator.dart';
import 'package:sakuramusic/data/db/app_database.dart';

/// Drives the real [MediaKitAudioPlayerService] against a fake media_kit
/// backend so the volume commands that would reach mpv can be inspected and
/// held open while an event is delivered.
void main() {
  group('MediaKitAudioPlayerService keeps the user volume target', () {
    late _Harness h;

    setUp(() {
      h = _Harness();
    });

    tearDown(() async {
      // Let an unawaited 120 ms envelope finish before the backend closes so a
      // late step cannot surface as an error during teardown.
      await Future<void>.delayed(const Duration(milliseconds: 250));
      await h.dispose();
    });

    test('(a) a late 0 report during next() cannot lower the target', () async {
      await h.service.setQueue(_queue());
      await h.service.setVolume(0.65);
      expect(h.service.currentSnapshot!.volume, 0.65);
      expect(h.fake.lastVolumeCommand, 65);

      await h.service.play();
      await _waitFor(
        () => h.fake.lastVolumeCommand == 65,
        description: 'the fade-in reaches 65',
      );
      await _waitFor(() => h.service.currentSnapshot!.playing);

      final marked = h.mark;
      final gate = Completer<void>();
      h.fake.switchGate = gate;
      final switching = h.service.next();
      await _waitFor(
        () => h.fake.events.contains('next'),
        description: 'next() is held on the gate',
      );
      expect(
        h.fake.lastVolumeCommand,
        0,
        reason: 'the switch fades out before moving the backend',
      );

      // A report emitted for the previous track arrives while the switch is held.
      h.fake.reportVolume(0);
      gate.complete();
      await switching;
      await _waitFor(
        () => h.fake.lastVolumeCommand == 65,
        description: 'the fade-in restores the target after the switch',
      );

      expect(h.service.currentSnapshot!.volume, 0.65);
      expect(h.volumesSince(marked), <double>{0.65});
      expect(h.fake.lastVolumeCommand, 65);
    });

    test('(b) play() starts silent and fades up to the target', () async {
      await h.service.setQueue(_queue());
      await h.service.setVolume(0.65);
      final marked = h.mark;
      h.fake.events.clear();

      await h.service.play();
      expect(h.fake.lastVolumeCommand, 0);
      expect(h.fake.events.indexOf('volume:0.00'), isNonNegative);
      expect(
        h.fake.events.indexOf('volume:0.00'),
        lessThan(h.fake.events.indexOf('play')),
        reason: 'the backend is lowered before playback starts',
      );

      await _waitFor(
        () => h.fake.lastVolumeCommand == 65,
        description: 'the fade-in reaches 65',
      );
      expect(h.service.currentSnapshot!.volume, 0.65);
      expect(h.volumesSince(marked), <double>{0.65});
    });

    test('(c) playAt() keeps the target through a queue selection', () async {
      await h.service.setQueue(_queue());
      await h.service.setVolume(0.65);
      await h.service.play();
      await _waitFor(() => h.fake.lastVolumeCommand == 65);

      await h.service.playAt(2);
      expect(
        h.fake.lastVolumeCommand,
        0,
        reason: 'the selected item starts from the faded-out volume',
      );
      await _waitFor(
        () => h.service.currentSnapshot!.currentIndex == 2,
        description: 'the selection reaches index 2',
      );
      await _waitFor(
        () => h.fake.lastVolumeCommand == 65,
        description: 'the fade-in reaches 65 after the selection',
      );
      expect(h.service.currentSnapshot!.volume, 0.65);
    });

    test(
      '(d) a manual change during the fade-in wins over late reports',
      () async {
        await h.service.setQueue(_queue());
        await h.service.setVolume(0.65);
        await h.service.play();
        await _waitFor(() => h.service.currentSnapshot!.playing);

        // Still inside the fade-in window: the user picks a new level.
        await h.service.setVolume(0.35);
        // Reports belonging to the superseded envelope arrive afterwards.
        h.fake.reportVolume(0.65);
        h.fake.reportVolume(0);
        await Future<void>.delayed(const Duration(milliseconds: 300));

        expect(h.service.currentSnapshot!.volume, 0.35);
        expect(h.fake.lastVolumeCommand, 35);
        expect(
          h.fake.volumeCommands.skipWhile((value) => value != 35),
          everyElement(35),
          reason: 'no superseded step may lower the output after the change',
        );
      },
    );

    test('(e) the 0 and 1 bounds cross the boundary as 0 and 100', () async {
      await h.service.setQueue(_queue());

      await h.service.setVolume(0);
      expect(h.fake.lastVolumeCommand, 0);
      expect(h.service.currentSnapshot!.volume, 0);

      await h.service.setVolume(1);
      expect(h.fake.lastVolumeCommand, 100);
      expect(h.service.currentSnapshot!.volume, 1);

      await expectLater(h.service.setVolume(-0.01), throwsArgumentError);
      await expectLater(h.service.setVolume(1.01), throwsArgumentError);
      expect(h.fake.lastVolumeCommand, 100);
      expect(h.service.currentSnapshot!.volume, 1);
    });

    test('a muted target stays muted across a track switch', () async {
      await h.service.setQueue(_queue());
      await h.service.setVolume(0);
      await h.service.play();
      await _waitFor(() => h.service.currentSnapshot!.playing);

      await h.service.next();
      await _waitFor(
        () => h.service.currentSnapshot!.currentIndex == 1,
        description: 'the switch moved to the next item',
      );
      await Future<void>.delayed(const Duration(milliseconds: 250));

      expect(h.service.currentSnapshot!.volume, 0);
      expect(h.fake.lastVolumeCommand, 0);
      expect(
        h.fake.volumeCommands.skipWhile((value) => value != 0),
        everyElement(0),
      );
    });

    test('(f) pause restores the target and play fades back to it', () async {
      await h.service.setQueue(_queue());
      await h.service.setVolume(0.65);
      final marked = h.mark;
      await h.service.play();
      await _waitFor(() => h.fake.lastVolumeCommand == 65);

      await h.service.pause();
      expect(h.service.currentSnapshot!.volume, 0.65);
      expect(
        h.fake.lastVolumeCommand,
        65,
        reason: 'a paused player is not left at the faded-out volume',
      );

      await h.service.play();
      await _waitFor(
        () => h.fake.events.where((event) => event == 'play').length == 2,
        description: 'the second play() reached the backend',
      );
      await _waitFor(() => h.fake.lastVolumeCommand == 65);
      expect(h.service.currentSnapshot!.volume, 0.65);
      expect(h.volumesSince(marked), <double>{0.65});
    });

    test(
      '(g) replacing and editing the queue keeps the target applied',
      () async {
        await h.service.setQueue(_queue());
        await h.service.setVolume(0.65);

        await h.service.setQueue(_queue(), startIndex: 1);
        expect(h.service.currentSnapshot!.volume, 0.65);
        expect(h.fake.lastVolumeCommand, 65);

        await h.service.insertNext(_item('inserted'));
        expect(h.service.currentSnapshot!.volume, 0.65);
        expect(h.fake.lastVolumeCommand, 65);

        await h.service.removeAt(0);
        expect(h.service.currentSnapshot!.volume, 0.65);
        expect(h.fake.lastVolumeCommand, 65);

        await h.service.moveItem(1, 0);
        expect(h.service.currentSnapshot!.volume, 0.65);
        expect(h.fake.lastVolumeCommand, 65);
        expect(
          h.fake.events.where((event) => event == 'open').length,
          greaterThanOrEqualTo(4),
          reason: 'every queue edit reopens the playlist',
        );
      },
    );

    test('a manual change during the fade-out is not overridden', () async {
      await h.service.setQueue(_queue());
      await h.service.setVolume(0.65);
      await h.service.play();
      await _waitFor(() => h.fake.lastVolumeCommand == 65);

      final gate = Completer<void>();
      h.fake.volumeGate = gate;
      final switching = h.service.next();
      await _waitFor(
        () => h.fake.volumeGate == null,
        description: 'the first fade-out step is held open',
      );

      // setVolume queues its write behind the held step, so it must not be
      // awaited before the gate opens.
      final change = h.service.setVolume(0.35);
      gate.complete();
      await change;
      await switching;
      await Future<void>.delayed(const Duration(milliseconds: 300));

      expect(h.service.currentSnapshot!.volume, 0.35);
      expect(h.fake.lastVolumeCommand, 35);
    });
  });

  group('PlaybackCoordinator volume persistence', () {
    test(
      '(h) saves the target and restores it through the real path',
      () async {
        final directory = await Directory.systemTemp.createTemp(
          'sakuramusic_volume_unit',
        );
        addTearDown(() async {
          if (directory.existsSync()) {
            await directory.delete(recursive: true);
          }
        });
        final files = <File>[
          for (final id in <String>['first', 'second'])
            await File('${directory.path}/$id.wav').create(),
        ];
        final queue = <PlayableItem>[
          for (final file in files)
            PlayableItem(
              id: file.uri.pathSegments.last,
              title: file.uri.pathSegments.last,
              streamUrl: file.uri.toString(),
              duration: const Duration(seconds: 3),
            ),
        ];

        final database = AppDatabase(NativeDatabase.memory());
        addTearDown(database.close);
        final serverId = await database.insertServer(
          ServersCompanion.insert(
            name: 'Offline volume test',
            baseUrl: 'https://offline.test',
            username: 'demo',
            password: '',
          ),
        );
        final server = (await database.getServer(serverId))!;

        final first = _Harness();
        await first.service.setQueue(queue);
        await first.service.setVolume(0.65);
        final coordinator = PlaybackCoordinator(
          service: first.service,
          database: database,
          server: server,
          readPassword: (_) => null,
          saveInterval: const Duration(milliseconds: 50),
        );
        // Let the (empty) restore pass finish before playback drives saves.
        await Future<void>.delayed(const Duration(milliseconds: 100));

        await first.service.play();
        await _waitFor(
          () => first.service.currentSnapshot!.playing,
          description: 'playback started',
        );

        await first.service.next();
        first.fake.reportVolume(0);
        await _waitFor(
          () => first.service.currentSnapshot!.currentIndex == 1,
          description: 'the switch moved to the second item',
        );
        await _waitFor(
          () => first.fake.lastVolumeCommand == 65,
          description: 'the fade-in restored the target after the switch',
        );
        final saved = await _waitForState(
          database,
          (state) => state.currentIndex == 1 && state.volume == 0.65,
          description:
              'the switched track was persisted with the target volume',
        );
        expect(saved.volume, 0.65);
        expect(first.service.currentSnapshot!.volume, 0.65);
        expect(first.fake.lastVolumeCommand, 65);

        await coordinator.dispose();
        await Future<void>.delayed(const Duration(milliseconds: 250));
        await first.dispose();

        // Rebuild the service and the coordinator: only the real restore path
        // (database -> setQueue/setVolume) can bring the volume back.
        final second = _Harness();
        final restored = PlaybackCoordinator(
          service: second.service,
          database: database,
          server: server,
          readPassword: (_) => null,
          saveInterval: const Duration(milliseconds: 50),
        );
        await _waitFor(
          () =>
              second.service.currentSnapshot?.volume == 0.65 &&
              second.fake.lastVolumeCommand == 65,
          timeout: const Duration(seconds: 10),
          description: 'the restore pass applied the saved volume',
        );
        expect(second.service.currentSnapshot!.volume, 0.65);
        expect(second.service.currentSnapshot!.currentIndex, 1);
        expect(second.fake.lastVolumeCommand, 65);

        await restored.dispose();
        await Future<void>.delayed(const Duration(milliseconds: 250));
        await second.dispose();
      },
    );
  });
}

/// One service instance wired to a controllable media_kit backend.
class _Harness {
  _Harness() {
    service = MediaKitAudioPlayerService(player: Player(platformPlayer: fake));
    _subscription = service.snapshot.listen(snapshots.add);
  }

  final _FakePlatformPlayer fake = _FakePlatformPlayer();
  late final MediaKitAudioPlayerService service;
  final List<PlayerSnapshot> snapshots = <PlayerSnapshot>[];
  late final StreamSubscription<PlayerSnapshot> _subscription;

  /// Snapshot index used to ignore the volumes published before a test acted.
  int get mark => snapshots.length;

  Set<double> volumesSince(int mark) =>
      snapshots.skip(mark).map((snapshot) => snapshot.volume).toSet();

  /// Every user-facing volume the snapshot stream published.
  Set<double> get observedVolumes =>
      snapshots.map((snapshot) => snapshot.volume).toSet();

  Future<void> dispose() async {
    await _subscription.cancel();
    await service.dispose();
  }
}

/// Minimal media_kit backend: records the volume commands the service issues,
/// can hold `open`/`next`/`setVolume` open, and can replay backend volume
/// reports for a previous track.
class _FakePlatformPlayer extends PlatformPlayer {
  _FakePlatformPlayer() : super(configuration: const PlayerConfiguration()) {
    completer.complete();
  }

  /// Values the service asked the backend to apply, in media_kit's 0-100 scale.
  final List<double> volumeCommands = <double>[];

  /// Ordered command log, used to assert the order of playback and volume work.
  final List<String> events = <String>[];

  /// mpv properties set by the service (`cache`, `af`); recorded so the fake
  /// behaves like a backend that accepts them.
  final Map<String, String> properties = <String, String>{};

  /// Holds the next [open] so a test can inspect the window before a queue
  /// becomes active.
  Completer<void>? openGate;

  /// Holds the next [next] so a test can deliver an event mid-switch.
  Completer<void>? switchGate;

  /// Holds the next volume write so a test can make an envelope step overlap a
  /// newer operation.
  Completer<void>? volumeGate;

  Playlist _playlist = const Playlist(<Media>[], index: 0);

  double? get lastVolumeCommand =>
      volumeCommands.isEmpty ? null : volumeCommands.last;

  /// Replays a volume report as the backend would after a track change.
  void reportVolume(double volume) => volumeController.add(volume);

  @override
  Future<void> open(Playable playable, {bool play = true}) async {
    events.add('open');
    final gate = openGate;
    openGate = null;
    if (gate != null) {
      await gate.future;
    }
    _playlist = switch (playable) {
      Playlist playlist => playlist,
      Media media => Playlist(<Media>[media], index: 0),
      _ => _playlist,
    };
    playlistController.add(_playlist);
    if (play) {
      await this.play();
    }
  }

  @override
  Future<void> stop() async {
    events.add('stop');
  }

  @override
  Future<void> play() async {
    events.add('play');
    playingController.add(true);
  }

  @override
  Future<void> pause() async {
    events.add('pause');
    playingController.add(false);
  }

  @override
  Future<void> next() async {
    events.add('next');
    final gate = switchGate;
    switchGate = null;
    if (gate != null) {
      await gate.future;
    }
    _jumpTo(_playlist.index + 1);
  }

  @override
  Future<void> previous() async {
    events.add('previous');
    final gate = switchGate;
    switchGate = null;
    if (gate != null) {
      await gate.future;
    }
    _jumpTo(_playlist.index - 1);
  }

  @override
  Future<void> jump(int index) async {
    events.add('jump:$index');
    _jumpTo(index);
  }

  @override
  Future<void> seek(Duration duration) async {
    events.add('seek');
    positionController.add(duration);
  }

  @override
  Future<void> setVolume(double volume) async {
    events.add('volume:${volume.toStringAsFixed(2)}');
    volumeCommands.add(volume);
    final gate = volumeGate;
    volumeGate = null;
    if (gate != null) {
      await gate.future;
    }
    // A real backend reports the value it applied; the service must ignore it
    // as a source of the user target.
    volumeController.add(volume);
  }

  @override
  Future<void> setRate(double rate) async {
    events.add('rate:${rate.toStringAsFixed(2)}');
    rateController.add(rate);
  }

  @override
  Future<void> setPlaylistMode(PlaylistMode playlistMode) async {
    events.add('playlistMode:${playlistMode.name}');
    playlistModeController.add(playlistMode);
  }

  @override
  Future<void> setShuffle(bool shuffle) async {
    events.add('shuffle:$shuffle');
    shuffleController.add(shuffle);
  }

  Future<void> setProperty(String property, String value) async {
    properties[property] = value;
  }

  void _jumpTo(int index) {
    if (_playlist.medias.isEmpty) {
      return;
    }
    final next = index.clamp(0, _playlist.medias.length - 1);
    _playlist = _playlist.copyWith(index: next);
    playlistController.add(_playlist);
  }
}

List<PlayableItem> _queue() => <PlayableItem>[
  _item('first'),
  _item('second'),
  _item('third'),
];

PlayableItem _item(String id) => PlayableItem(
  id: id,
  title: id,
  streamUrl: 'file:///tmp/sakuramusic_volume_test_$id.wav',
  duration: const Duration(seconds: 3),
);

Future<void> _waitFor(
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 5),
  String? description,
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      throw TimeoutException(
        'condition not met within ${timeout.inMilliseconds} ms'
        '${description == null ? '' : ': $description'}',
        timeout,
      );
    }
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}

Future<PlaybackState> _waitForState(
  AppDatabase database,
  bool Function(PlaybackState state) condition, {
  Duration timeout = const Duration(seconds: 5),
  String? description,
}) async {
  final deadline = DateTime.now().add(timeout);
  while (true) {
    final state = await database.getPlaybackState();
    if (state != null && condition(state)) {
      return state;
    }
    if (DateTime.now().isAfter(deadline)) {
      throw TimeoutException(
        'saved playback state not met within ${timeout.inMilliseconds} ms'
        '${description == null ? '' : ': $description'} '
        '(last saved: ${state?.volume}, index ${state?.currentIndex})',
        timeout,
      );
    }
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
}
