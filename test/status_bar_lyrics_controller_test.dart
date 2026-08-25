import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramusic/audio/audio_player_provider.dart';
import 'package:sakuramusic/audio/audio_player_service.dart';
import 'package:sakuramusic/audio/equalizer_models.dart';
import 'package:sakuramusic/data/db/app_database.dart';
import 'package:sakuramusic/data/server_repository.dart';
import 'package:sakuramusic/features/player/lyrics/lyrics_parser.dart';
import 'package:sakuramusic/features/player/lyrics/lyrics_service.dart';
import 'package:sakuramusic/features/status_bar_lyrics/status_bar_lyrics_channel.dart';
import 'package:sakuramusic/features/status_bar_lyrics/status_bar_lyrics_controller.dart';

class _FakeStatusBarChannel implements StatusBarLyricsChannel {
  int registerCalls = 0;
  int destroyCalls = 0;
  int clearCalls = 0;
  final List<({
    String id,
    String name,
    String? artist,
    int durationMs,
    List<StatusBarLyricLine> lines,
  })> songs = <({
    String id,
    String name,
    String? artist,
    int durationMs,
    List<StatusBarLyricLine> lines,
  })>[];
  final List<int> positions = <int>[];
  final List<bool> states = <bool>[];

  @override
  Future<void> register() async {
    registerCalls++;
  }

  @override
  Future<void> destroy() async {
    destroyCalls++;
  }

  @override
  Future<void> clearSong() async {
    clearCalls++;
  }

  @override
  Future<void> setSong({
    required String id,
    required String name,
    required String? artist,
    required int durationMs,
    required List<StatusBarLyricLine> lines,
  }) async {
    songs.add((
      id: id,
      name: name,
      artist: artist,
      durationMs: durationMs,
      lines: lines,
    ));
  }

  @override
  Future<void> setPosition(int ms) async {
    positions.add(ms);
  }

  @override
  Future<void> setPlaybackState(bool playing) async {
    states.add(playing);
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

class _FakeLyricsService extends LyricsService {
  _FakeLyricsService(this._lines) : super(null);

  final List<ParsedLyricsLine>? _lines;

  @override
  Future<List<ParsedLyricsLine>?> load(LyricsQuery query) async => _lines;
}

ProviderContainer _container(
  _FakeStatusBarChannel channel,
  AppDatabase db,
  LyricsService? lyricsService,
) {
  return ProviderContainer(
    overrides: [
      statusBarLyricsChannelProvider.overrideWithValue(channel),
      audioPlayerProvider.overrideWithValue(_FakePlayerService()),
      lyricsServiceProvider.overrideWithValue(lyricsService),
      databaseProvider.overrideWithValue(db),
    ],
  );
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

const PlayerSnapshot _emptySnapshot = PlayerSnapshot(
  status: PlayerStatus.ready,
  playing: false,
  position: Duration.zero,
  currentItem: null,
);

void main() {
  test('pushes the whole song once on change and dedups position/state',
      () async {
    final channel = _FakeStatusBarChannel();
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final lyrics = <ParsedLyricsLine>[
      const ParsedLyricsLine(timeMs: 0, text: 'first'),
      const ParsedLyricsLine(timeMs: 10000, text: 'second'),
    ];
    final container = _container(channel, database, _FakeLyricsService(lyrics));
    addTearDown(container.dispose);

    final controller =
        container.read(statusBarLyricsControllerProvider.notifier);
    expect(container.read(statusBarLyricsControllerProvider), isFalse);

    // While disabled no snapshot may reach the channel.
    controller.handleSnapshot(_snapshot());
    expect(channel.songs, isEmpty);
    expect(channel.registerCalls, 0);

    await controller.setEnabled(true);
    expect(channel.registerCalls, 1);
    expect(container.read(statusBarLyricsControllerProvider), isTrue);

    // New song: placeholder (no lyrics) pushed, then lyrics load and the full
    // song is pushed once.
    controller.handleSnapshot(_snapshot(positionMs: 0, playing: true));
    await Future<void>.delayed(Duration.zero);
    expect(channel.songs, hasLength(2));
    expect(channel.songs.first.lines, isEmpty);
    final full = channel.songs.last;
    expect(full.id, 'song-1');
    expect(full.name, 'Test Song');
    expect(full.artist, 'Tester');
    expect(full.lines, hasLength(2));
    expect(full.lines.first.beginMs, 0);
    expect(full.lines.first.endMs, 10000);
    expect(full.lines.last.beginMs, 10000);
    // Last line end falls back to duration (0: item carries no duration).
    expect(full.lines.last.endMs, 0);
    expect(channel.states, <bool>[true]);
    expect(channel.positions, <int>[0]);

    // Unchanged state/position: nothing extra is pushed.
    controller.handleSnapshot(_snapshot(positionMs: 0, playing: true));
    expect(channel.songs, hasLength(2));
    expect(channel.states, <bool>[true]);
    expect(channel.positions, <int>[0]);

    // New position: only setPosition is pushed.
    controller.handleSnapshot(_snapshot(positionMs: 5000, playing: true));
    expect(channel.positions, <int>[0, 5000]);
    expect(channel.songs, hasLength(2));

    // Pause: only setPlaybackState is pushed.
    controller.handleSnapshot(_snapshot(positionMs: 5000, playing: false));
    expect(channel.states, <bool>[true, false]);

    // The enabled flag persists to settings.
    final settings = await database.getSettings();
    expect(settings?.statusBarLyricsEnabled, isTrue);
  });

  test('clears the song when the queue empties', () async {
    final channel = _FakeStatusBarChannel();
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final container = _container(channel, database, null);
    addTearDown(container.dispose);

    final controller =
        container.read(statusBarLyricsControllerProvider.notifier);
    await controller.setEnabled(true);
    controller.handleSnapshot(_snapshot(positionMs: 0, playing: true));
    await Future<void>.delayed(Duration.zero);
    expect(channel.songs, isNotEmpty);
    expect(channel.clearCalls, 0);

    controller.handleSnapshot(_emptySnapshot);
    expect(channel.clearCalls, 1);

    // A new song after clearing pushes again.
    controller.handleSnapshot(_snapshot(positionMs: 0, playing: true));
    await Future<void>.delayed(Duration.zero);
    expect(channel.clearCalls, 1);
    expect(channel.songs.length, greaterThan(1));
  });

  test('disabling destroys the provider and persists the switch', () async {
    final channel = _FakeStatusBarChannel();
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final container = _container(channel, database, null);
    addTearDown(container.dispose);

    final controller =
        container.read(statusBarLyricsControllerProvider.notifier);
    await controller.setEnabled(true);
    expect(channel.registerCalls, 1);

    await controller.setEnabled(false);
    expect(channel.destroyCalls, 1);
    expect(container.read(statusBarLyricsControllerProvider), isFalse);

    final settings = await database.getSettings();
    expect(settings?.statusBarLyricsEnabled, isFalse);
  });

  test('re-pushes the full song when lyrics arrive for the active song',
      () async {
    final channel = _FakeStatusBarChannel();
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final container = _container(channel, database, null);
    addTearDown(container.dispose);

    final controller =
        container.read(statusBarLyricsControllerProvider.notifier);
    await controller.setEnabled(true);

    // No lyrics service: placeholder pushed, no lines.
    controller.handleSnapshot(_snapshot(positionMs: 0, playing: true));
    await Future<void>.delayed(Duration.zero);
    expect(channel.songs, hasLength(1));
    expect(channel.songs.first.lines, isEmpty);

    // Lyrics arrive for the same song: the full song is re-pushed.
    controller.debugSetLyrics(
      'song-1',
      <ParsedLyricsLine>[const ParsedLyricsLine(timeMs: 5000, text: 'hello')],
    );
    expect(channel.songs, hasLength(2));
    expect(channel.songs.last.lines, hasLength(1));
    expect(channel.songs.last.lines.first.text, 'hello');
    expect(channel.songs.last.lines.first.beginMs, 5000);
  });
}
