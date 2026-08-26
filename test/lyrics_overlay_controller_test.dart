import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramusic/audio/audio_player_provider.dart';
import 'package:sakuramusic/audio/audio_player_service.dart';
import 'package:sakuramusic/audio/equalizer_models.dart';
import 'package:sakuramusic/data/db/app_database.dart';
import 'package:sakuramusic/data/server_repository.dart';
import 'package:sakuramusic/features/lyrics_overlay/lyrics_overlay_channel.dart';
import 'package:sakuramusic/features/lyrics_overlay/lyrics_overlay_controller.dart';
import 'package:sakuramusic/features/player/lyrics/lyrics_parser.dart';
import 'package:sakuramusic/features/player/lyrics/lyrics_service.dart';

class _FakeOverlayChannel implements LyricsOverlayChannel {
  final List<({String current, String next, bool isPlaying})> calls =
      <({String current, String next, bool isPlaying})>[];
  int showCalls = 0;
  int hideCalls = 0;
  void Function()? closedHandler;

  @override
  Future<bool> checkPermission() async => true;

  @override
  Future<void> requestPermission() async {}

  @override
  Future<void> show() async {
    showCalls++;
  }

  @override
  Future<void> hide() async {
    hideCalls++;
  }

  @override
  Future<void> updateLyrics({
    required String current,
    required String next,
    required bool isPlaying,
  }) async {
    calls.add((current: current, next: next, isPlaying: isPlaying));
  }

  @override
  void setOverlayClosedHandler(void Function() handler) {
    closedHandler = handler;
  }
}

class _FakePlayerService implements AudioPlayerService {
  @override
  Stream<PlayerSnapshot> get snapshot => const Stream<PlayerSnapshot>.empty();

  @override
  PlayerSnapshot? get currentSnapshot => null;

  @override
  Future<void> setQueue(List<PlayableItem> items, {int startIndex = 0}) async {}

  @override
  Future<void> play() async {}

  @override
  Future<void> pause() async {}

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
  Future<void> setVolume(double value) async {}

  @override
  Future<void> setSpeed(double value) async {}

  @override
  Future<bool> setPreferredOutputDevice(int? deviceId) async => false;

  @override
  Future<void> setEqualizer(EqualizerSettings settings) async {}

  @override
  Future<void> dispose() async {}
}

PlayerSnapshot _snapshot({int positionMs = 0, bool playing = false}) {
  return PlayerSnapshot(
    status: PlayerStatus.ready,
    playing: playing,
    position: Duration(milliseconds: positionMs),
    currentItem: const PlayableItem(
      id: 'song-1',
      title: 'Test Song',
      artist: 'Tester',
      streamUrl: 'https://example.com/stream',
    ),
  );
}

ProviderContainer _container(_FakeOverlayChannel channel, AppDatabase db) {
  return ProviderContainer(
    overrides: [
      lyricsOverlayChannelProvider.overrideWithValue(channel),
      audioPlayerProvider.overrideWithValue(_FakePlayerService()),
      lyricsServiceProvider.overrideWithValue(null),
      databaseProvider.overrideWithValue(db),
    ],
  );
}

void main() {
  test('pushes only when the active line or play state changes', () async {
    final channel = _FakeOverlayChannel();
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final container = _container(channel, database);
    addTearDown(container.dispose);

    final controller = container.read(lyricsOverlayControllerProvider.notifier);
    expect(container.read(lyricsOverlayControllerProvider), isFalse);

    // While disabled no snapshot may reach the channel.
    controller.handleSnapshot(_snapshot());
    expect(channel.calls, isEmpty);

    await controller.setEnabled(true);
    expect(channel.showCalls, 1);
    expect(container.read(lyricsOverlayControllerProvider), isTrue);

    final lines = <ParsedLyricsLine>[
      const ParsedLyricsLine(timeMs: 0, text: 'first'),
      const ParsedLyricsLine(timeMs: 10000, text: 'second'),
      const ParsedLyricsLine(timeMs: 20000, text: 'third'),
    ];
    controller.debugSetLyrics('song-1', lines);

    controller.handleSnapshot(_snapshot(positionMs: 0, playing: true));
    expect(channel.calls, hasLength(1));
    expect(channel.calls.last.current, 'first');
    expect(channel.calls.last.next, 'second');
    expect(channel.calls.last.isPlaying, isTrue);

    // Same line and same play state: throttled away.
    controller.handleSnapshot(_snapshot(positionMs: 5000, playing: true));
    expect(channel.calls, hasLength(1));

    // Crossing into the next line pushes.
    controller.handleSnapshot(_snapshot(positionMs: 12000, playing: true));
    expect(channel.calls, hasLength(2));
    expect(channel.calls.last.current, 'second');
    expect(channel.calls.last.next, 'third');

    // A pause flips the play state and pushes the same line again.
    controller.handleSnapshot(_snapshot(positionMs: 12500, playing: false));
    expect(channel.calls, hasLength(3));
    expect(channel.calls.last.current, 'second');
    expect(channel.calls.last.isPlaying, isFalse);

    // The enabled flag persists.
    final settings = await database.getSettings();
    expect(settings?.lyricsOverlayEnabled, isTrue);
  });

  test('falls back to the song title before the first lyric line', () async {
    final channel = _FakeOverlayChannel();
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final container = _container(channel, database);
    addTearDown(container.dispose);

    final controller = container.read(lyricsOverlayControllerProvider.notifier);
    await controller.setEnabled(true);

    // No lyrics loaded yet: the fallback text is the song info.
    controller.handleSnapshot(_snapshot(positionMs: 0, playing: true));
    expect(channel.calls, hasLength(1));
    expect(channel.calls.last.current, '♪ Test Song - Tester');

    // Lyrics arrive for the same song and the current line takes over.
    controller.debugSetLyrics('song-1', <ParsedLyricsLine>[
      const ParsedLyricsLine(timeMs: 5000, text: 'hello'),
    ]);
    controller.handleSnapshot(_snapshot(positionMs: 10000, playing: true));
    expect(channel.calls, hasLength(2));
    expect(channel.calls.last.current, 'hello');
    expect(channel.calls.last.next, isEmpty);
  });

  test('overlay-closed event turns the switch off and persists', () async {
    final channel = _FakeOverlayChannel();
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final container = _container(channel, database);
    addTearDown(container.dispose);

    final controller = container.read(lyricsOverlayControllerProvider.notifier);
    await controller.setEnabled(true);
    expect(container.read(lyricsOverlayControllerProvider), isTrue);

    channel.closedHandler!();
    await Future<void>.delayed(Duration.zero);
    expect(container.read(lyricsOverlayControllerProvider), isFalse);

    final settings = await database.getSettings();
    expect(settings?.lyricsOverlayEnabled, isFalse);
  });
}
