import 'dart:async';
import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramusic/audio/audio_player_provider.dart';
import 'package:sakuramusic/audio/audio_player_service.dart';
import 'package:sakuramusic/audio/equalizer_models.dart';
import 'package:sakuramusic/core/providers.dart';
import 'package:sakuramusic/data/db/app_database.dart';
import 'package:sakuramusic/data/server_repository.dart';
import 'package:sakuramusic/features/home/home_screen.dart';
import 'package:sakuramusic/l10n/app_localizations.dart';
import 'package:subsonic_api/subsonic_api.dart';

/// UI-wiring coverage for the home daily-recommendation card's round button.
///
/// The button must refresh the card with a fresh batch through
/// `DailyRecommendSongsNotifier.shuffle()` and must never start playback or
/// disturb the queue / current track / playback state; the card body keeps its
/// "tap to play" behavior and queues whatever batch the card currently shows.
///
/// shuffle()'s own cache/HTTP semantics are covered by
/// daily_recommend_shuffle_test.dart. Most tests here drive a fake notifier so
/// the widget tree stays deterministic; the last one wires the REAL notifier to
/// an isolated data source to prove production refresh logic and the UI meet.
void main() {
  for (final key in <LogicalKeyboardKey>[
    LogicalKeyboardKey.space,
    LogicalKeyboardKey.enter,
  ]) {
    testWidgets(
      'keyboard ${key.keyLabel} refreshes through the real notifier',
      (tester) async {
        final client = _StubSubsonicClient();
        final harness = await _pumpHome(
          tester,
          client: client,
          useRealNotifier: true,
        );
        final icon = find.descendant(
          of: _shuffleButton(),
          matching: find.byIcon(Icons.refresh_rounded),
        );
        Focus.of(tester.element(icon)).requestFocus();
        await tester.pump();

        await tester.sendKeyEvent(key);
        await tester.pumpAndSettle();

        expect(client.randomSongsCalls, <int>[20]);
        expect(find.text('Real Song One'), findsOneWidget);
        expect(harness.player.playbackCommands, isEmpty);
      },
    );
  }

  for (final failure in <bool>[false, true]) {
    testWidgets(
      '${failure ? 'failed' : 'empty'} real response preserves the card and player',
      (tester) async {
        final client = _StubSubsonicClient(
          response: const <Song>[],
          shouldThrow: failure,
        );
        final harness = await _pumpHome(
          tester,
          client: client,
          useRealNotifier: true,
        );

        await tester.tap(_shuffleButton());
        await tester.pumpAndSettle();

        expect(client.randomSongsCalls, <int>[20]);
        expect(find.text('Old Song One'), findsOneWidget);
        expect(harness.player.playbackCommands, isEmpty);
      },
    );
  }

  testWidgets(
    'the round button shuffles a fresh batch without starting playback',
    (tester) async {
      final harness = await _pumpHome(tester);

      expect(find.text('Old Song One'), findsOneWidget);
      expect(find.text('New Song One'), findsNothing);

      final button = _shuffleButton();
      expect(button, findsOneWidget, reason: 'the card renders one button');
      await tester.tap(button);
      await tester.pumpAndSettle();

      expect(harness.dailyNotifier.shuffleCalls, 1);
      expect(find.text('New Song One'), findsOneWidget);
      expect(find.text('Old Song One'), findsNothing);
      // Shuffling only refreshes the card: no queue is built, nothing plays,
      // and no playback command of any kind is issued.
      expect(harness.player.setQueueCalls, isEmpty);
      expect(harness.player.playCalls, 0);
      expect(harness.player.playbackCommands, isEmpty);
    },
  );

  testWidgets('the button is independently keyboard/semantics activatable', (
    tester,
  ) async {
    final harness = await _pumpHome(tester);

    // The card's button carries its own tooltip — a semantics entry separate
    // from the card body — so assistive tech and long-press users get a
    // labelled refresh affordance rather than only the play action.
    final button = _shuffleButton();
    expect(button, findsOneWidget);
    final tooltip = tester.widget<Tooltip>(
      find.descendant(of: button, matching: find.byType(Tooltip)),
    );
    expect(tooltip.message, isNotEmpty);

    // Keyboard/assistive activation: the button wraps its own Focus and maps
    // the activation intents, so dispatching the same intent a hardware Enter
    // key or an accessibility tap sends must refresh the batch — and must
    // never start playback. (Invoking it on the card BODY plays instead,
    // which is what makes this an independent activation entry point.)
    final inkWell = find.descendant(of: button, matching: find.byType(InkWell));
    expect(inkWell, findsOneWidget);
    final buttonFocus = find
        .descendant(of: inkWell, matching: find.byType(Focus))
        .first;
    final focus = tester.widget<Focus>(buttonFocus);
    expect(
      focus.canRequestFocus,
      isTrue,
      reason: 'the button must be reachable by keyboard focus',
    );
    Actions.invoke(tester.element(buttonFocus), const ActivateIntent());
    await tester.pumpAndSettle();
    expect(harness.dailyNotifier.shuffleCalls, 1);
    expect(find.text('New Song One'), findsOneWidget);
    expect(harness.player.playbackCommands, isEmpty);
    expect(harness.player.setQueueCalls, isEmpty);
  });

  testWidgets('the card body plays the batch currently shown', (tester) async {
    final harness = await _pumpHome(tester);

    await tester.tap(find.text('Old Song One'));
    await tester.pumpAndSettle();
    expect(harness.player.setQueueCalls, hasLength(1));
    expect(harness.player.setQueueCalls.single.startIndex, 0);
    expect(
      harness.player.setQueueCalls.single.items.map((item) => item.title),
      <String>['Old Song One', 'Old Song Two'],
    );
    expect(harness.player.playCalls, 1);

    // A shuffle in between changes what the next body tap plays and still
    // does not start playback by itself.
    await tester.tap(_shuffleButton());
    await tester.pumpAndSettle();
    expect(harness.player.setQueueCalls, hasLength(1));
    expect(harness.player.playCalls, 1);

    await tester.tap(find.text('New Song One'));
    await tester.pumpAndSettle();
    expect(harness.player.setQueueCalls, hasLength(2));
    expect(
      harness.player.setQueueCalls.last.items.map((item) => item.title),
      <String>['New Song One', 'New Song Two'],
    );
    expect(harness.player.playCalls, 2);
  });

  testWidgets(
    'a refresh with a paused snapshot leaves queue, track and state untouched',
    (tester) async {
      final harness = await _pumpHome(tester);

      // The player already holds a queue and is PAUSED on a specific track.
      const current = PlayableItem(
        id: 'old-1',
        title: 'Old Song One',
        streamUrl: 'http://127.0.0.1:4533/rest/stream?id=old-1',
      );
      harness.player.emit(
        const PlayerSnapshot(
          status: PlayerStatus.ready,
          playing: false,
          position: Duration(seconds: 12),
          currentIndex: 0,
          currentItem: current,
          queue: <PlayableItem>[current],
        ),
      );
      await tester.pumpAndSettle();

      final queueBefore = harness.player.currentSnapshot!.queue;
      final itemBefore = harness.player.currentSnapshot!.currentItem;
      final playingBefore = harness.player.currentSnapshot!.playing;

      await tester.tap(_shuffleButton());
      await tester.pumpAndSettle();

      // The card did change...
      expect(find.text('New Song One'), findsOneWidget);
      // ...while playback was left completely alone: no command was issued and
      // the snapshot still describes the same paused track and queue.
      expect(harness.player.playbackCommands, isEmpty);
      expect(harness.player.pauseCalls, 0);
      expect(harness.player.seekCalls, isEmpty);
      expect(harness.player.shuffleModeCalls, isEmpty);
      expect(harness.player.loopModeCalls, isEmpty);
      final after = harness.player.currentSnapshot!;
      expect(after.queue, queueBefore);
      expect(after.currentItem?.id, itemBefore?.id);
      expect(after.currentItem?.title, 'Old Song One');
      expect(after.playing, playingBefore);
      expect(after.playing, isFalse);
      expect(after.position, const Duration(seconds: 12));
    },
  );

  testWidgets(
    'a refresh with a playing snapshot keeps playing the same track',
    (tester) async {
      final harness = await _pumpHome(tester);

      const current = PlayableItem(
        id: 'old-1',
        title: 'Old Song One',
        streamUrl: 'http://127.0.0.1:4533/rest/stream?id=old-1',
      );
      harness.player.emit(
        const PlayerSnapshot(
          status: PlayerStatus.ready,
          playing: true,
          position: Duration(seconds: 20),
          currentIndex: 0,
          currentItem: current,
          queue: <PlayableItem>[current],
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(_shuffleButton());
      await tester.pumpAndSettle();

      expect(find.text('New Song One'), findsOneWidget);
      expect(harness.player.playbackCommands, isEmpty);
      final after = harness.player.currentSnapshot!;
      expect(after.currentItem?.title, 'Old Song One');
      expect(after.playing, isTrue);
      expect(after.position, const Duration(seconds: 20));
      expect(after.queue.map((item) => item.title), <String>['Old Song One']);
    },
  );

  testWidgets(
    'the real notifier drives the button end to end without playing',
    (tester) async {
      // No fake notifier here: the production provider runs its real
      // build/shuffle/cache/rotation logic against a stub client and an
      // in-memory database, so this proves the UI wiring and the production
      // refresh path work together. The client is stubbed (rather than using
      // real sockets) because a widget test's fake-async clock cannot drive
      // real network IO.
      final client = _StubSubsonicClient();
      final harness = await _pumpHome(
        tester,
        client: client,
        useRealNotifier: true,
      );

      // Today's cache was seeded by the harness, so the card already shows the
      // old batch without asking the server.
      expect(find.text('Old Song One'), findsOneWidget);
      expect(client.randomSongsCalls, isEmpty);

      // The real shuffle, triggered through the button, bypasses that cache.
      await tester.tap(_shuffleButton());
      await tester.pumpAndSettle();

      expect(client.randomSongsCalls, hasLength(1));
      expect(client.randomSongsCalls.single, 20);
      expect(find.text('Real Song One'), findsOneWidget);
      expect(find.text('Old Song One'), findsNothing);
      // A refresh in no way touches playback.
      expect(harness.player.setQueueCalls, isEmpty);
      expect(harness.player.playbackCommands, isEmpty);
      expect(harness.player.playCalls, 0);

      // The body tap then plays exactly the batch the card shows.
      await tester.tap(find.text('Real Song One'));
      await tester.pumpAndSettle();
      expect(harness.player.setQueueCalls, hasLength(1));
      expect(harness.player.setQueueCalls.single.startIndex, 0);
      expect(
        harness.player.setQueueCalls.single.items.map((item) => item.title),
        <String>['Real Song One', 'Real Song Two'],
      );
      expect(harness.player.playCalls, 1);
    },
  );
}

String _todayKey() {
  final now = DateTime.now();
  return '${now.year}-${now.month.toString().padLeft(2, '0')}-'
      '${now.day.toString().padLeft(2, '0')}';
}

/// The card's round shuffle button.
///
/// Located by its stable [Key] so it can never be confused with the separate
/// 19px `Colors.white60` refresh button in the "random songs" section header
/// further down the page (both use `Icons.refresh_rounded`).
Finder _shuffleButton() {
  return find.byKey(const Key('daily-recommend-shuffle-button'));
}

class _Harness {
  _Harness(this.player, this.dailyNotifier);

  final _RecordingPlayerService player;
  final _FakeDailyNotifier dailyNotifier;
}

Future<_Harness> _pumpHome(
  WidgetTester tester, {
  String baseUrl = 'http://127.0.0.1:4533',
  bool useRealNotifier = false,
  SubsonicClient? client,
}) async {
  final database = AppDatabase(NativeDatabase.memory());
  addTearDown(database.close);
  final player = _RecordingPlayerService();
  addTearDown(player.dispose);
  final dailyNotifier = _FakeDailyNotifier();

  final server = Server(
    id: 1,
    name: 'Navidrome',
    baseUrl: baseUrl,
    username: 'listener',
    password: '',
    createdAt: DateTime(2024),
  );

  if (useRealNotifier) {
    // Seed today's cache so the card renders immediately from cache; the real
    // notifier then bypasses it when the button is tapped.
    await database.upsertDailyRecommend(
      server.id,
      _todayKey(),
      jsonEncode(<Map<String, dynamic>>[
        const Song(
          id: 'old-1',
          title: 'Old Song One',
          artist: 'Artist',
          album: 'Album',
        ).toJson(),
        const Song(
          id: 'old-2',
          title: 'Old Song Two',
          artist: 'Artist',
          album: 'Album',
        ).toJson(),
      ]),
    );
  }

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(database),
        serversProvider.overrideWithValue(AsyncValue.data(<Server>[server])),
        activeServerProvider.overrideWithValue(server),
        activeSubsonicClientProvider.overrideWithValue(
          client ??
              SubsonicClient(
                baseUrl: baseUrl,
                username: 'listener',
                password: 'password',
              ),
        ),
        audioPlayerProvider.overrideWithValue(player),
        // With the real notifier the provider is left untouched so the
        // production build/shuffle path runs against the injected client.
        if (!useRealNotifier)
          dailyRecommendSongsProvider.overrideWith(() => dailyNotifier),
        starredProvider.overrideWith(() => _EmptyStarredNotifier()),
        // A live drift stream would schedule its own teardown timer when the
        // widget tree is disposed, tripping the pending-timer invariant.
        recentPlaysProvider.overrideWithValue(AsyncValue.data(<RecentPlay>[])),
        randomSongsProvider.overrideWith((ref) async => const <Song>[]),
        newestAlbumsProvider.overrideWith((ref) async => const <Album>[]),
        playlistsProvider.overrideWith((ref) async => const <Playlist>[]),
        libraryStatsProvider.overrideWith((ref) async => const LibraryStats()),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('zh'),
        home: const Scaffold(body: HomeScreen()),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return _Harness(player, dailyNotifier);
}

/// Serves a fixed batch, then swaps to [newBatch] on [shuffle] — the real
/// notifier's cache/HTTP work is covered by daily_recommend_shuffle_test.dart.
class _FakeDailyNotifier extends DailyRecommendSongsNotifier {
  static const _oldBatch = <Song>[
    Song(id: 'old-1', title: 'Old Song One', artist: 'Artist', album: 'Album'),
    Song(id: 'old-2', title: 'Old Song Two', artist: 'Artist', album: 'Album'),
  ];
  static const _newBatch = <Song>[
    Song(id: 'new-1', title: 'New Song One', artist: 'Artist', album: 'Album'),
    Song(id: 'new-2', title: 'New Song Two', artist: 'Artist', album: 'Album'),
  ];

  int shuffleCalls = 0;

  @override
  Future<List<Song>> build() async => _oldBatch;

  @override
  Future<void> shuffle() async {
    shuffleCalls++;
    state = const AsyncData<List<Song>>(_newBatch);
  }
}

class _EmptyStarredNotifier extends StarredNotifier {
  @override
  Future<Starred2> build() async {
    return const Starred2();
  }
}

/// Records every playback command instead of touching a real audio engine.
///
/// Nothing is a silent no-op: a failure to record would hide a side effect the
/// shuffle button must never have, so each command is captured (and the ones
/// that are meaningful for this card are asserted on as empty).
class _RecordingPlayerService implements AudioPlayerService {
  final _controller = StreamController<PlayerSnapshot>.broadcast();

  final List<({List<PlayableItem> items, int startIndex})> setQueueCalls =
      <({List<PlayableItem> items, int startIndex})>[];
  final List<String> playbackCommands = <String>[];
  int playCalls = 0;
  int pauseCalls = 0;
  final List<Duration> seekCalls = <Duration>[];
  final List<bool> shuffleModeCalls = <bool>[];
  final List<AppLoopMode> loopModeCalls = <AppLoopMode>[];
  final List<int> playAtCalls = <int>[];
  int nextCalls = 0;
  int previousCalls = 0;
  final List<PlayableItem> insertNextCalls = <PlayableItem>[];
  final List<int> removeAtCalls = <int>[];
  final List<({int from, int to})> moveItemCalls = <({int from, int to})>[];
  final List<double> volumeCalls = <double>[];
  final List<double> speedCalls = <double>[];

  PlayerSnapshot _last = const PlayerSnapshot();

  /// Publishes a snapshot as the real service would.
  void emit(PlayerSnapshot snapshot) {
    _last = snapshot;
    _controller.add(snapshot);
  }

  @override
  Stream<PlayerSnapshot> get snapshot => _controller.stream;

  @override
  PlayerSnapshot? get currentSnapshot => _last;

  @override
  Future<void> setQueue(List<PlayableItem> items, {int startIndex = 0}) async {
    setQueueCalls.add((items: items, startIndex: startIndex));
    playbackCommands.add('setQueue');
  }

  @override
  Future<void> play() async {
    playCalls++;
    playbackCommands.add('play');
  }

  @override
  Future<void> pause() async {
    pauseCalls++;
    playbackCommands.add('pause');
  }

  @override
  Future<void> next() async {
    nextCalls++;
    playbackCommands.add('next');
  }

  @override
  Future<void> previous() async {
    previousCalls++;
    playbackCommands.add('previous');
  }

  @override
  Future<void> seek(Duration position) async {
    seekCalls.add(position);
    playbackCommands.add('seek');
  }

  @override
  Future<void> setLoopMode(AppLoopMode mode) async {
    loopModeCalls.add(mode);
    playbackCommands.add('setLoopMode');
  }

  @override
  Future<void> setShuffle(bool enabled) async {
    shuffleModeCalls.add(enabled);
    playbackCommands.add('setShuffle');
  }

  @override
  Future<void> playAt(int index) async {
    playAtCalls.add(index);
    playbackCommands.add('playAt');
  }

  @override
  Future<void> insertNext(PlayableItem item) async {
    insertNextCalls.add(item);
    playbackCommands.add('insertNext');
  }

  @override
  Future<void> removeAt(int index) async {
    removeAtCalls.add(index);
    playbackCommands.add('removeAt');
  }

  @override
  Future<void> moveItem(int from, int to) async {
    moveItemCalls.add((from: from, to: to));
    playbackCommands.add('moveItem');
  }

  @override
  Future<void> setVolume(double value) async {
    volumeCalls.add(value);
    playbackCommands.add('setVolume');
  }

  @override
  Future<void> setSpeed(double value) async {
    speedCalls.add(value);
    playbackCommands.add('setSpeed');
  }

  @override
  Future<bool> setPreferredOutputDevice(int? deviceId) async => false;

  @override
  Future<void> setEqualizer(EqualizerSettings settings) async {}

  @override
  Future<void> dispose() async {
    await _controller.close();
  }
}

/// A Subsonic client whose only interesting endpoint is the random batch.
///
/// It keeps the real notifier's logic under test without real sockets, which a
/// widget test's fake-async clock cannot drive. Every call is recorded so the
/// test can assert the refresh really bypassed the cache and asked for 20.
class _StubSubsonicClient extends SubsonicClient {
  _StubSubsonicClient({this.response = batch, this.shouldThrow = false})
    : super(
        baseUrl: 'http://127.0.0.1:4533',
        username: 'listener',
        password: 'password',
      );

  static const batch = <Song>[
    Song(
      id: 'real-1',
      title: 'Real Song One',
      artist: 'Artist',
      album: 'Album',
    ),
    Song(
      id: 'real-2',
      title: 'Real Song Two',
      artist: 'Artist',
      album: 'Album',
    ),
  ];

  final List<Song> response;
  final bool shouldThrow;

  final List<int> randomSongsCalls = <int>[];

  @override
  Future<List<Song>> getRandomSongs({int size = 10}) async {
    randomSongsCalls.add(size);
    if (shouldThrow) {
      throw StateError('Isolated shuffle failure');
    }
    return response;
  }
}
