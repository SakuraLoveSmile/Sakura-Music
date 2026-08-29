import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:sakuramusic/audio/audio_player_service.dart';
import 'package:sakuramusic/audio/equalizer_controller.dart';
import 'package:sakuramusic/audio/just_audio_service.dart';
import 'package:sakuramusic/audio/playback_debug_log.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // `setQueue` resolves a cache directory via path_provider, which has no
  // native implementation under `flutter test`. Stub the channel so the
  // equalizer retry path can be exercised without a platform plugin.
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (call) async {
          if (call.method == 'getTemporaryDirectory') {
            return Directory.systemTemp
                .createTempSync('sakuramusic_audio_cache_test')
                .path;
          }
          return null;
        },
      );

  const item = PlayableItem(
    id: 'song-1',
    title: 'Song',
    streamUrl: 'https://example.test/song.mp3',
  );
  const queue = <PlayableItem>[item];

  test('PlayableItem round-trips playback and cover metadata', () {
    const original = PlayableItem(
      id: 'song-42',
      title: 'Round Trip',
      artist: 'Artist',
      album: 'Album',
      albumId: 'album-7',
      artistId: 'artist-8',
      coverArtId: 'cover-9',
      artworkUrl: 'https://example.test/cover-9.jpg',
      artworkCacheKey: 'cover_cover-9_600',
      duration: Duration(milliseconds: 95000),
      streamUrl: 'https://example.test/song-42.mp3',
      headers: <String, String>{'X-Test': 'header'},
    );

    final restored = PlayableItem.fromJson(
      Map<String, dynamic>.from(original.toJson()),
    );

    expect(restored.id, original.id);
    expect(restored.title, original.title);
    expect(restored.artist, original.artist);
    expect(restored.album, original.album);
    expect(restored.albumId, original.albumId);
    expect(restored.artistId, original.artistId);
    expect(restored.coverArtId, original.coverArtId);
    expect(restored.artworkUrl, original.artworkUrl);
    expect(restored.artworkCacheKey, original.artworkCacheKey);
    expect(restored.duration, original.duration);
    expect(restored.streamUrl, original.streamUrl);
    expect(restored.headers, original.headers);

    expect(
      PlayableItem.fromJson(<String, dynamic>{
        'id': 'legacy-song',
        'title': 'Legacy',
        'streamUrl': 'https://example.test/legacy.mp3',
        'artworkId': 'legacy-cover',
      }).coverArtId,
      'legacy-cover',
    );
  });

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

  test('retries the equalizer after ready when setQueue timed out', () async {
    final fake = _FakeEqualizer(timeoutPattern: const <bool>[true, false]);
    final player = _RecordingAudioPlayer();
    final service = JustAudioPlayerService.withController(fake, player: player);
    addTearDown(service.dispose);

    // setQueue applies the equalizer, which times out because the native
    // effect is not ready yet; the retry marker must be armed.
    await service.setQueue(<PlayableItem>[item]);
    await Future<void>.delayed(const Duration(milliseconds: 350));
    expect(service.equalizerRetryPendingForTest, isTrue);
    expect(fake.parametersCalls, 1);

    // Once the player reaches ready, the pending retry fires exactly once.
    player.emitPlayerState(PlayerState(true, ProcessingState.ready));
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(fake.parametersCalls, 2);
    expect(service.equalizerRetryPendingForTest, isFalse);
    expect(
      playbackDebugLog.entries.any(
        (e) => e.message == 'setEqualizer: re-applied after ready',
      ),
      isTrue,
    );
  });

  test('setQueue resets the equalizer retry marker', () async {
    // First two equalizer calls time out (covering setQueue + the ready
    // retry), the third succeeds.
    final fake = _FakeEqualizer(
      timeoutPattern: const <bool>[true, true, false],
    );
    final player = _RecordingAudioPlayer();
    final service = JustAudioPlayerService.withController(fake, player: player);
    addTearDown(service.dispose);

    await service.setQueue(<PlayableItem>[item]);
    await Future<void>.delayed(const Duration(milliseconds: 350));
    player.emitPlayerState(PlayerState(true, ProcessingState.ready));
    // The retry re-arms the marker only after its own 250ms timeout elapses.
    await Future<void>.delayed(const Duration(milliseconds: 350));
    // A still-pending marker (re-armed by the failed retry).
    expect(service.equalizerRetryPendingForTest, isTrue);

    // A new queue must clear the marker; this time the call succeeds so the
    // marker stays cleared, proving setQueue reset the previous pending state.
    await service.setQueue(<PlayableItem>[item]);
    expect(service.equalizerRetryPendingForTest, isFalse);
    expect(fake.parametersCalls, 3);
  });

  test('setQueue passes custom headers to AudioSource', () async {
    final player = _RecordingAudioPlayer();
    final service = JustAudioPlayerService(player: player);
    addTearDown(service.dispose);

    const itemWithHeaders = PlayableItem(
      id: 'webdav-1',
      title: 'WebDAV Song',
      streamUrl: 'https://webdav.example.com/song.flac',
      headers: <String, String>{'Authorization': 'Basic dXNlcjpwYXNz'},
    );

    await service.setQueue(<PlayableItem>[itemWithHeaders]);

    expect(player.lastAudioSources, isNotNull);
    expect(player.lastAudioSources, hasLength(1));
    final source = player.lastAudioSources!.first as UriAudioSource;
    expect(source.headers, equals({'Authorization': 'Basic dXNlcjpwYXNz'}));
  });
}

class _RecordingAudioPlayer extends AudioPlayer {
  final events = <String>[];
  List<AudioSource>? lastAudioSources;

  final StreamController<PlayerState> _playerStateController =
      StreamController<PlayerState>.broadcast();
  PlayerState _injectedState = PlayerState(false, ProcessingState.idle);

  @override
  Stream<PlayerState> get playerStateStream => _playerStateController.stream;

  @override
  PlayerState get playerState => _injectedState;

  void emitPlayerState(PlayerState state) {
    _injectedState = state;
    _playerStateController.add(state);
  }

  @override
  Future<Duration?> setAudioSources(
    List<AudioSource> audioSources, {
    bool preload = true,
    int? initialIndex,
    Duration? initialPosition,
    ShuffleOrder? shuffleOrder,
  }) async {
    lastAudioSources = audioSources;
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

class _FakeEqualizer implements EqualizerController {
  _FakeEqualizer({this.timeoutPattern = const <bool>[true]});

  final List<bool> timeoutPattern;

  int parametersCalls = 0;
  int setEnabledCalls = 0;

  final EqualizerParameters _parameters = _FakeEqualizerParameters();

  @override
  Future<void> setEnabled(bool enabled) async => setEnabledCalls++;

  @override
  Future<EqualizerParameters> get parameters {
    parametersCalls++;
    final shouldTimeout = parametersCalls - 1 < timeoutPattern.length
        ? timeoutPattern[parametersCalls - 1]
        : false;
    if (shouldTimeout) {
      // Never completes within the 250ms timeout applied by the service.
      return Future<void>.delayed(
        const Duration(milliseconds: 400),
      ).then((_) => throw TimeoutException('fake timeout'));
    }
    return Future<EqualizerParameters>.value(_parameters);
  }
}

class _FakeEqualizerParameters implements EqualizerParameters {
  _FakeEqualizerParameters();

  @override
  final double minDecibels = -12;

  @override
  final double maxDecibels = 12;

  @override
  final List<EqualizerBand> bands = <EqualizerBand>[
    _FakeEqualizerBand(),
    _FakeEqualizerBand(),
    _FakeEqualizerBand(),
    _FakeEqualizerBand(),
    _FakeEqualizerBand(),
  ];
}

class _FakeEqualizerBand implements EqualizerBand {
  const _FakeEqualizerBand();

  @override
  Future<void> setGain(double gain) async {}
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
