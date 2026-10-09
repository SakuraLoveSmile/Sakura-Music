import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramusic/audio/audio_player_provider.dart';
import 'package:sakuramusic/audio/audio_player_service.dart';
import 'package:sakuramusic/core/providers.dart';
import 'package:sakuramusic/data/db/app_database.dart';
import 'package:sakuramusic/data/server_repository.dart';
import 'package:sakuramusic/features/home/home_screen.dart';
import 'package:sakuramusic/l10n/app_localizations.dart';
import 'package:subsonic_api/subsonic_api.dart';

class _TestAudioPlayerService extends Fake implements AudioPlayerService {
  final _controller = StreamController<PlayerSnapshot>.broadcast();
  PlayerSnapshot _snapshot = const PlayerSnapshot();

  @override
  Stream<PlayerSnapshot> get snapshot => _controller.stream;

  @override
  PlayerSnapshot? get currentSnapshot => _snapshot;

  void emit(PlayerSnapshot state) {
    _snapshot = state;
    _controller.add(state);
  }

  int playCount = 0;
  int pauseCount = 0;
  int nextCount = 0;
  int prevCount = 0;
  Duration? lastSeek;
  final List<({List<PlayableItem> items, int startIndex})> setQueueCalls = [];

  @override
  Future<void> setQueue(List<PlayableItem> items, {int startIndex = 0}) async {
    setQueueCalls.add((items: items, startIndex: startIndex));
  }

  @override
  Future<void> play() async {
    playCount++;
  }

  @override
  Future<void> pause() async {
    pauseCount++;
  }

  @override
  Future<void> next() async {
    nextCount++;
  }

  @override
  Future<void> previous() async {
    prevCount++;
  }

  @override
  Future<void> seek(Duration position) async {
    lastSeek = position;
  }

  @override
  Future<void> dispose() async {
    await _controller.close();
  }
}

class _TestSubsonicClient extends Fake implements SubsonicClient {
  _TestSubsonicClient({
    required this.batches,
    this.shouldThrowOnShuffle = false,
  });

  final List<List<Song>> batches;
  final bool shouldThrowOnShuffle;
  int batchIndex = 0;
  int getRandomSongsCalls = 0;

  @override
  Future<List<Song>> getRandomSongs({
    int? size,
    String? genre,
    String? fromYear,
    String? toYear,
    String? musicFolderId,
  }) async {
    getRandomSongsCalls++;
    if (getRandomSongsCalls > 1 && shouldThrowOnShuffle) {
      throw Exception('Shuffle network error');
    }
    if (batchIndex < batches.length) {
      final batch = batches[batchIndex];
      batchIndex++;
      return batch;
    }
    return batches.isNotEmpty ? batches.last : const <Song>[];
  }

  @override
  Future<List<Album>> getAlbumList({
    String type = 'recent',
    int? size,
    int? offset,
    int? fromYear,
    int? toYear,
    String? genre,
    String? musicFolderId,
  }) async => const <Album>[];

  @override
  Future<List<Playlist>> getPlaylists() async => const <Playlist>[];

  @override
  Future<Starred2> getStarred2() async => const Starred2();

  @override
  String streamUrl(
    String id, {
    int? maxBitRate,
    String? format,
    int? timeOffset,
    bool? estimateContentLength,
  }) {
    return 'https://stream.example.com/$id.mp3';
  }

  @override
  String coverArtUrl(String id, {int? size}) {
    return 'https://art.example.com/$id';
  }
}

Widget _buildTestApp({
  required _TestAudioPlayerService playerService,
  required _TestSubsonicClient client,
  required AppDatabase database,
  required Server server,
}) {
  return ProviderScope(
    overrides: [
      audioPlayerProvider.overrideWithValue(playerService),
      databaseProvider.overrideWithValue(database),
      activeServerProvider.overrideWith((ref) => server),
      activeSubsonicClientProvider.overrideWith((ref) => client),
      serversProvider.overrideWith((ref) => Stream.value([server])),
      starredIdsProvider.overrideWith(
        (ref) => (songs: <String>{}, albums: <String>{}, artists: <String>{}),
      ),
      recentPlaysProvider.overrideWith(
        (ref) => Stream.value(const <RecentPlay>[]),
      ),
      randomSongsProvider.overrideWith((ref) async => const <Song>[]),
      newestAlbumsProvider.overrideWith((ref) async => const <Album>[]),
      playlistsProvider.overrideWith((ref) async => const <Playlist>[]),
      libraryStatsProvider.overrideWith(
        (ref) async =>
            const LibraryStats(songCount: 0, albumCount: 0, artistCount: 0),
      ),
    ],
    child: const MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: Locale('zh'),
      home: HomeScreen(),
    ),
  );
}

void main() {
  late AppDatabase database;
  late Server server;
  late _TestAudioPlayerService playerService;

  setUp(() async {
    DailyRecommendCacheCoordinator.reset();
    database = AppDatabase(NativeDatabase.memory());
    final serverId = await database.insertServer(
      ServersCompanion.insert(
        name: 'Home Test Server',
        baseUrl: 'https://hometest.example.com',
        username: 'user',
        password: 'pwd',
      ),
    );
    server = (await database.getServer(serverId))!;
    playerService = _TestAudioPlayerService();
  });

  tearDown(() async {
    DailyRecommendCacheCoordinator.reset(database);
    DailyRecommendCacheCoordinator.reset();
    await playerService.dispose();
    await database.close();
  });

  final batch1 = <Song>[
    const Song(
      id: 'song-1',
      title: 'Batch 1 First Song',
      artist: 'Artist 1',
      album: 'Album 1',
    ),
    const Song(
      id: 'song-2',
      title: 'Batch 1 Second Song',
      artist: 'Artist 1',
      album: 'Album 1',
    ),
  ];

  final batch2 = <Song>[
    const Song(
      id: 'song-3',
      title: 'Batch 2 First Song',
      artist: 'Artist 2',
      album: 'Album 2',
    ),
    const Song(
      id: 'song-4',
      title: 'Batch 2 Second Song',
      artist: 'Artist 2',
      album: 'Album 2',
    ),
  ];

  testWidgets(
    'right circular shuffle button has key, refresh icon and tooltip',
    (tester) async {
      final client = _TestSubsonicClient(batches: [batch1, batch2]);

      await tester.pumpWidget(
        _buildTestApp(
          playerService: playerService,
          client: client,
          database: database,
          server: server,
        ),
      );
      await tester.pumpAndSettle();

      final shuffleButtonFinder = find.byKey(
        const Key('daily-recommend-shuffle-button'),
      );
      expect(shuffleButtonFinder, findsOneWidget);

      final iconFinder = find.descendant(
        of: shuffleButtonFinder,
        matching: find.byIcon(Icons.refresh_rounded),
      );
      expect(iconFinder, findsOneWidget);

      final tooltipFinder = find.ancestor(
        of: shuffleButtonFinder,
        matching: find.byType(Tooltip),
      );
      expect(tooltipFinder, findsOneWidget);
      final tooltip = tester.widget<Tooltip>(tooltipFinder.first);
      expect(tooltip.message, '换一批');
    },
  );

  testWidgets(
    'clicking right button in IDLE state refreshes card songs without touching player',
    (tester) async {
      playerService.emit(
        const PlayerSnapshot(
          status: PlayerStatus.idle,
          playing: false,
          currentItem: null,
          queue: <PlayableItem>[],
        ),
      );

      final client = _TestSubsonicClient(batches: [batch1, batch2]);

      await tester.pumpWidget(
        _buildTestApp(
          playerService: playerService,
          client: client,
          database: database,
          server: server,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Batch 1 First Song'), findsOneWidget);

      final shuffleButtonFinder = find.byKey(
        const Key('daily-recommend-shuffle-button'),
      );
      await tester.tap(shuffleButtonFinder);
      await tester.pumpAndSettle();

      expect(find.text('Batch 2 First Song'), findsOneWidget);

      expect(playerService.playCount, 0);
      expect(playerService.pauseCount, 0);
      expect(playerService.nextCount, 0);
      expect(playerService.prevCount, 0);
      expect(playerService.setQueueCalls, isEmpty);
      expect(playerService.lastSeek, isNull);
      expect(playerService.currentSnapshot?.status, PlayerStatus.idle);
      expect(playerService.currentSnapshot?.playing, isFalse);
    },
  );

  testWidgets(
    'clicking right button in PAUSED state refreshes card songs without touching player',
    (tester) async {
      const existingTrack = PlayableItem(
        id: 'playing-1',
        title: 'Already Queued Song',
        streamUrl: 'https://example.com/stream.mp3',
      );
      playerService.emit(
        const PlayerSnapshot(
          status: PlayerStatus.ready,
          playing: false,
          currentItem: existingTrack,
          queue: <PlayableItem>[existingTrack],
          position: Duration(seconds: 42),
        ),
      );

      final client = _TestSubsonicClient(batches: [batch1, batch2]);

      await tester.pumpWidget(
        _buildTestApp(
          playerService: playerService,
          client: client,
          database: database,
          server: server,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Batch 1 First Song'), findsOneWidget);

      await tester.tap(find.byKey(const Key('daily-recommend-shuffle-button')));
      await tester.pumpAndSettle();

      expect(find.text('Batch 2 First Song'), findsOneWidget);

      expect(playerService.playCount, 0);
      expect(playerService.pauseCount, 0);
      expect(playerService.nextCount, 0);
      expect(playerService.prevCount, 0);
      expect(playerService.setQueueCalls, isEmpty);
      expect(playerService.lastSeek, isNull);
      expect(playerService.currentSnapshot?.currentItem?.id, 'playing-1');
      expect(
        playerService.currentSnapshot?.position,
        const Duration(seconds: 42),
      );
      expect(playerService.currentSnapshot?.playing, isFalse);
    },
  );

  testWidgets(
    'clicking right button in PLAYING state refreshes card songs without touching player',
    (tester) async {
      const existingTrack = PlayableItem(
        id: 'playing-live',
        title: 'Currently Playing Song',
        streamUrl: 'https://example.com/stream.mp3',
      );
      playerService.emit(
        const PlayerSnapshot(
          status: PlayerStatus.ready,
          playing: true,
          currentItem: existingTrack,
          queue: <PlayableItem>[existingTrack],
          position: Duration(seconds: 120),
        ),
      );

      final client = _TestSubsonicClient(batches: [batch1, batch2]);

      await tester.pumpWidget(
        _buildTestApp(
          playerService: playerService,
          client: client,
          database: database,
          server: server,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Batch 1 First Song'), findsOneWidget);

      await tester.tap(find.byKey(const Key('daily-recommend-shuffle-button')));
      await tester.pumpAndSettle();

      expect(find.text('Batch 2 First Song'), findsOneWidget);

      expect(playerService.playCount, 0);
      expect(playerService.pauseCount, 0);
      expect(playerService.nextCount, 0);
      expect(playerService.prevCount, 0);
      expect(playerService.setQueueCalls, isEmpty);
      expect(playerService.lastSeek, isNull);
      expect(playerService.currentSnapshot?.currentItem?.id, 'playing-live');
      expect(
        playerService.currentSnapshot?.position,
        const Duration(seconds: 120),
      );
      expect(playerService.currentSnapshot?.playing, isTrue);
    },
  );

  testWidgets(
    'tapping card body triggers full playback of current batch with featured song first',
    (tester) async {
      final client = _TestSubsonicClient(batches: [batch1, batch2]);

      await tester.pumpWidget(
        _buildTestApp(
          playerService: playerService,
          client: client,
          database: database,
          server: server,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Batch 1 First Song'));
      await tester.pumpAndSettle();

      expect(playerService.setQueueCalls, hasLength(1));
      final call = playerService.setQueueCalls.first;
      expect(call.startIndex, 0);
      expect(call.items, hasLength(2));
      expect(call.items.first.id, 'song-1');
      expect(call.items.first.title, 'Batch 1 First Song');
      expect(call.items[1].id, 'song-2');
      expect(playerService.playCount, 1);
    },
  );

  testWidgets(
    'tapping card body after shuffle plays the newly displayed batch',
    (tester) async {
      final client = _TestSubsonicClient(batches: [batch1, batch2]);

      await tester.pumpWidget(
        _buildTestApp(
          playerService: playerService,
          client: client,
          database: database,
          server: server,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('daily-recommend-shuffle-button')));
      await tester.pumpAndSettle();
      expect(find.text('Batch 2 First Song'), findsOneWidget);

      await tester.tap(find.text('Batch 2 First Song'));
      await tester.pumpAndSettle();

      expect(playerService.setQueueCalls, hasLength(1));
      final call = playerService.setQueueCalls.first;
      expect(call.startIndex, 0);
      expect(call.items, hasLength(2));
      expect(call.items.first.id, 'song-3');
      expect(call.items.first.title, 'Batch 2 First Song');
      expect(call.items[1].id, 'song-4');
      expect(playerService.playCount, 1);
    },
  );

  testWidgets(
    'pure keyboard Space activation on shuffle button triggers shuffle without player commands',
    (tester) async {
      final client = _TestSubsonicClient(batches: [batch1, batch2]);

      await tester.pumpWidget(
        _buildTestApp(
          playerService: playerService,
          client: client,
          database: database,
          server: server,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Batch 1 First Song'), findsOneWidget);

      final shuffleIconFinder = find.descendant(
        of: find.byKey(const Key('daily-recommend-shuffle-button')),
        matching: find.byIcon(Icons.refresh_rounded),
      );
      final iconElement = tester.element(shuffleIconFinder);
      Focus.of(iconElement).requestFocus();
      await tester.pump();

      // Pure keyboard Space activation (no tester.tap)
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();

      expect(find.text('Batch 2 First Song'), findsOneWidget);
      expect(playerService.playCount, 0);
      expect(playerService.pauseCount, 0);
      expect(playerService.setQueueCalls, isEmpty);
    },
  );

  testWidgets(
    'pure keyboard Enter activation on shuffle button triggers shuffle without player commands',
    (tester) async {
      final client = _TestSubsonicClient(batches: [batch1, batch2]);

      await tester.pumpWidget(
        _buildTestApp(
          playerService: playerService,
          client: client,
          database: database,
          server: server,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Batch 1 First Song'), findsOneWidget);

      final shuffleIconFinder = find.descendant(
        of: find.byKey(const Key('daily-recommend-shuffle-button')),
        matching: find.byIcon(Icons.refresh_rounded),
      );
      final iconElement = tester.element(shuffleIconFinder);
      Focus.of(iconElement).requestFocus();
      await tester.pump();

      // Pure keyboard Enter activation (no tester.tap)
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      expect(find.text('Batch 2 First Song'), findsOneWidget);
      expect(playerService.playCount, 0);
      expect(playerService.pauseCount, 0);
      expect(playerService.setQueueCalls, isEmpty);
    },
  );

  testWidgets(
    'network failure on shuffle retains existing batch and does not trigger player commands',
    (tester) async {
      final client = _TestSubsonicClient(
        batches: [batch1],
        shouldThrowOnShuffle: true,
      );

      await tester.pumpWidget(
        _buildTestApp(
          playerService: playerService,
          client: client,
          database: database,
          server: server,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Batch 1 First Song'), findsOneWidget);

      await tester.tap(find.byKey(const Key('daily-recommend-shuffle-button')));
      await tester.pumpAndSettle();

      expect(find.text('Batch 1 First Song'), findsOneWidget);
      expect(playerService.playCount, 0);
      expect(playerService.setQueueCalls, isEmpty);
    },
  );

  testWidgets(
    'empty response on shuffle retains existing batch and does not trigger player commands',
    (tester) async {
      final client = _TestSubsonicClient(batches: [batch1, <Song>[]]);

      await tester.pumpWidget(
        _buildTestApp(
          playerService: playerService,
          client: client,
          database: database,
          server: server,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Batch 1 First Song'), findsOneWidget);

      await tester.tap(find.byKey(const Key('daily-recommend-shuffle-button')));
      await tester.pumpAndSettle();

      expect(find.text('Batch 1 First Song'), findsOneWidget);
      expect(playerService.playCount, 0);
      expect(playerService.setQueueCalls, isEmpty);
    },
  );
}
