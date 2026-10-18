import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramusic/core/providers.dart';
import 'package:sakuramusic/data/db/app_database.dart';
import 'package:sakuramusic/data/server_repository.dart';
import 'package:subsonic_api/subsonic_api.dart';

class _FakeSubsonicClient extends Fake implements SubsonicClient {
  _FakeSubsonicClient({this.getRandomSongsHandler});

  Future<List<Song>> Function({
    int? size,
    String? genre,
    String? fromYear,
    String? toYear,
    String? musicFolderId,
  })?
  getRandomSongsHandler;

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
    if (getRandomSongsHandler != null) {
      return getRandomSongsHandler!(
        size: size,
        genre: genre,
        fromYear: fromYear,
        toYear: toYear,
        musicFolderId: musicFolderId,
      );
    }
    return <Song>[
      const Song(id: 'song-default-1', title: 'Song 1', artist: 'Artist 1'),
      const Song(id: 'song-default-2', title: 'Song 2', artist: 'Artist 2'),
    ];
  }
}

class _TestServerNotifier extends Notifier<Server?> {
  _TestServerNotifier(this._initial);
  final Server? _initial;

  @override
  Server? build() => _initial;

  void setServer(Server? server) {
    state = server;
  }
}

void main() {
  late AppDatabase database;
  late Server server1;
  late Server server2;

  setUp(() async {
    DailyRecommendCacheCoordinator.reset();
    database = AppDatabase(NativeDatabase.memory());
    final id1 = await database.insertServer(
      ServersCompanion.insert(
        name: 'Server 1',
        baseUrl: 'https://server1.example.com',
        username: 'user1',
        password: 'pwd',
      ),
    );
    final id2 = await database.insertServer(
      ServersCompanion.insert(
        name: 'Server 2',
        baseUrl: 'https://server2.example.com',
        username: 'user2',
        password: 'pwd',
      ),
    );
    server1 = (await database.getServer(id1))!;
    server2 = (await database.getServer(id2))!;
  });

  tearDown(() async {
    DailyRecommendCacheCoordinator.reset(database);
    DailyRecommendCacheCoordinator.reset();
    await database.close();
  });

  group('DailyRecommendSongsNotifier - Initial build & cache baseline', () {
    test('loads cached songs on startup without invoking client', () async {
      final now = DateTime.now();
      final date =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      const cachedSongs = <Song>[
        Song(id: 'cached-1', title: 'Cached Song 1', artist: 'Cached Artist'),
        Song(id: 'cached-2', title: 'Cached Song 2', artist: 'Cached Artist'),
      ];
      await database.upsertDailyRecommend(
        server1.id,
        date,
        jsonEncode(cachedSongs.map((s) => s.toJson()).toList()),
      );

      final client = _FakeSubsonicClient();
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(database),
          activeServerProvider.overrideWith((ref) => server1),
          activeSubsonicClientProvider.overrideWith((ref) => client),
        ],
      );
      addTearDown(container.dispose);

      final result = await container.read(dailyRecommendSongsProvider.future);
      expect(result.length, 2);
      expect(result.first.id, 'cached-1');
      expect(client.getRandomSongsCalls, 0);

      final committed = DailyRecommendCacheCoordinator.getCommittedState(
        server1.id,
        database: database,
      );
      expect(committed?.date, date);
      expect(committed?.generation, greaterThan(0));
    });

    test('fetches and caches when database has no existing cache', () async {
      final client = _FakeSubsonicClient(
        getRandomSongsHandler:
            ({fromYear, genre, musicFolderId, size, toYear}) async {
              return const <Song>[
                Song(id: 'net-1', title: 'Network Song 1', artist: 'Artist 1'),
                Song(id: 'net-2', title: 'Network Song 2', artist: 'Artist 2'),
              ];
            },
      );

      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(database),
          activeServerProvider.overrideWith((ref) => server1),
          activeSubsonicClientProvider.overrideWith((ref) => client),
        ],
      );
      addTearDown(container.dispose);

      final result = await container.read(dailyRecommendSongsProvider.future);
      expect(result.length, 2);
      expect(result.first.id, 'net-1');
      expect(client.getRandomSongsCalls, 1);

      final now = DateTime.now();
      final date =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final cachedRow = await database.getDailyRecommend(server1.id, date);
      expect(cachedRow, isNotNull);
      final decoded = jsonDecode(cachedRow!.songsJson) as List;
      expect(decoded.length, 2);
      expect(decoded[0]['id'], 'net-1');
    });

    test('handles empty initial network fetch gracefully', () async {
      final client = _FakeSubsonicClient(
        getRandomSongsHandler:
            ({fromYear, genre, musicFolderId, size, toYear}) async {
              return const <Song>[];
            },
      );

      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(database),
          activeServerProvider.overrideWith((ref) => server1),
          activeSubsonicClientProvider.overrideWith((ref) => client),
        ],
      );
      addTearDown(container.dispose);

      final result = await container.read(dailyRecommendSongsProvider.future);
      expect(result, isEmpty);
    });

    test(
      'handles initial network failure gracefully without throwing',
      () async {
        final client = _FakeSubsonicClient(
          getRandomSongsHandler:
              ({fromYear, genre, musicFolderId, size, toYear}) async {
                throw Exception('Subsonic server unreachable');
              },
        );

        final container = ProviderContainer(
          overrides: [
            databaseProvider.overrideWithValue(database),
            activeServerProvider.overrideWith((ref) => server1),
            activeSubsonicClientProvider.overrideWith((ref) => client),
          ],
        );
        addTearDown(container.dispose);

        final result = await container.read(dailyRecommendSongsProvider.future);
        expect(result, isEmpty);
      },
    );

    test(
      'recovers from corrupted database cache by falling back to network fetch',
      () async {
        final now = DateTime.now();
        final date =
            '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
        await database.upsertDailyRecommend(
          server1.id,
          date,
          'invalid json string',
        );

        final client = _FakeSubsonicClient(
          getRandomSongsHandler:
              ({fromYear, genre, musicFolderId, size, toYear}) async {
                return const <Song>[
                  Song(id: 'recovered-1', title: 'Recovered Song'),
                ];
              },
        );

        final container = ProviderContainer(
          overrides: [
            databaseProvider.overrideWithValue(database),
            activeServerProvider.overrideWith((ref) => server1),
            activeSubsonicClientProvider.overrideWith((ref) => client),
          ],
        );
        addTearDown(container.dispose);

        final result = await container.read(dailyRecommendSongsProvider.future);
        expect(result.first.id, 'recovered-1');
        expect(client.getRandomSongsCalls, 1);
      },
    );
  });

  group(
    'DailyRecommendSongsNotifier - Shuffle & Candidate replacement & Batch retention',
    () {
      test(
        'rotates different song to index 0 when new batch starts with the same song',
        () async {
          var callCount = 0;
          final client = _FakeSubsonicClient(
            getRandomSongsHandler:
                ({fromYear, genre, musicFolderId, size, toYear}) async {
                  callCount++;
                  if (callCount == 1) {
                    return const <Song>[
                      Song(id: 'song-A', title: 'Song A'),
                      Song(id: 'song-B', title: 'Song B'),
                    ];
                  } else {
                    return const <Song>[
                      Song(id: 'song-A', title: 'Song A'),
                      Song(id: 'song-C', title: 'Song C'),
                      Song(id: 'song-D', title: 'Song D'),
                    ];
                  }
                },
          );

          final container = ProviderContainer(
            overrides: [
              databaseProvider.overrideWithValue(database),
              activeServerProvider.overrideWith((ref) => server1),
              activeSubsonicClientProvider.overrideWith((ref) => client),
            ],
          );
          addTearDown(container.dispose);

          final initial = await container.read(
            dailyRecommendSongsProvider.future,
          );
          expect(initial.first.id, 'song-A');

          await container.read(dailyRecommendSongsProvider.notifier).shuffle();

          final updated = container.read(dailyRecommendSongsProvider).value!;
          expect(updated.length, 3);
          expect(updated[0].id, isNot('song-A'));
          expect(['song-C', 'song-D'], contains(updated[0].id));
          expect(
            updated.map((s) => s.id),
            containsAll(['song-A', 'song-C', 'song-D']),
          );
        },
      );

      test(
        'preserves order when new batch first song is already different',
        () async {
          var callCount = 0;
          final client = _FakeSubsonicClient(
            getRandomSongsHandler:
                ({fromYear, genre, musicFolderId, size, toYear}) async {
                  callCount++;
                  if (callCount == 1) {
                    return const <Song>[
                      Song(id: 'song-1', title: 'Song 1'),
                      Song(id: 'song-2', title: 'Song 2'),
                    ];
                  } else {
                    return const <Song>[
                      Song(id: 'song-3', title: 'Song 3'),
                      Song(id: 'song-4', title: 'Song 4'),
                    ];
                  }
                },
          );

          final container = ProviderContainer(
            overrides: [
              databaseProvider.overrideWithValue(database),
              activeServerProvider.overrideWith((ref) => server1),
              activeSubsonicClientProvider.overrideWith((ref) => client),
            ],
          );
          addTearDown(container.dispose);

          await container.read(dailyRecommendSongsProvider.future);
          await container.read(dailyRecommendSongsProvider.notifier).shuffle();

          final updated = container.read(dailyRecommendSongsProvider).value!;
          expect(updated.first.id, 'song-3');
          expect(updated[1].id, 'song-4');
        },
      );

      test(
        'preserves old batch and old cache when response only contains current song ID',
        () async {
          var callCount = 0;
          final client = _FakeSubsonicClient(
            getRandomSongsHandler:
                ({fromYear, genre, musicFolderId, size, toYear}) async {
                  callCount++;
                  if (callCount == 1) {
                    return const <Song>[
                      Song(id: 'song-A', title: 'Song A Initial'),
                      Song(id: 'song-B', title: 'Song B Initial'),
                    ];
                  } else {
                    return const <Song>[
                      Song(id: 'song-A', title: 'Song A Duplicate 1'),
                      Song(id: 'song-A', title: 'Song A Duplicate 2'),
                    ];
                  }
                },
          );

          final container = ProviderContainer(
            overrides: [
              databaseProvider.overrideWithValue(database),
              activeServerProvider.overrideWith((ref) => server1),
              activeSubsonicClientProvider.overrideWith((ref) => client),
            ],
          );
          addTearDown(container.dispose);

          final initial = await container.read(
            dailyRecommendSongsProvider.future,
          );
          expect(initial.first.id, 'song-A');

          await container.read(dailyRecommendSongsProvider.notifier).shuffle();

          final current = container.read(dailyRecommendSongsProvider).value!;
          expect(current.length, 2);
          expect(current[0].title, 'Song A Initial');
          expect(current[1].title, 'Song B Initial');
        },
      );

      test(
        'empty network response during shuffle preserves existing card state and cache',
        () async {
          var callCount = 0;
          final client = _FakeSubsonicClient(
            getRandomSongsHandler:
                ({fromYear, genre, musicFolderId, size, toYear}) async {
                  callCount++;
                  if (callCount == 1) {
                    return const <Song>[
                      Song(id: 'stable-1', title: 'Stable Song 1'),
                    ];
                  }
                  return const <Song>[];
                },
          );

          final container = ProviderContainer(
            overrides: [
              databaseProvider.overrideWithValue(database),
              activeServerProvider.overrideWith((ref) => server1),
              activeSubsonicClientProvider.overrideWith((ref) => client),
            ],
          );
          addTearDown(container.dispose);

          await container.read(dailyRecommendSongsProvider.future);
          await container.read(dailyRecommendSongsProvider.notifier).shuffle();

          final currentState = container.read(dailyRecommendSongsProvider);
          expect(currentState.value?.first.id, 'stable-1');
        },
      );

      test(
        'network exception during shuffle preserves existing card state',
        () async {
          var callCount = 0;
          final client = _FakeSubsonicClient(
            getRandomSongsHandler:
                ({fromYear, genre, musicFolderId, size, toYear}) async {
                  callCount++;
                  if (callCount == 1) {
                    return const <Song>[
                      Song(id: 'keep-1', title: 'Keep Song 1'),
                      Song(id: 'keep-2', title: 'Keep Song 2'),
                    ];
                  }
                  throw Exception('Connection reset by peer');
                },
          );

          final container = ProviderContainer(
            overrides: [
              databaseProvider.overrideWithValue(database),
              activeServerProvider.overrideWith((ref) => server1),
              activeSubsonicClientProvider.overrideWith((ref) => client),
            ],
          );
          addTearDown(container.dispose);

          await container.read(dailyRecommendSongsProvider.future);
          expect(
            container.read(dailyRecommendSongsProvider).value?.first.id,
            'keep-1',
          );

          await container.read(dailyRecommendSongsProvider.notifier).shuffle();

          final currentState = container.read(dailyRecommendSongsProvider);
          expect(currentState.hasValue, isTrue);
          expect(currentState.value?.first.id, 'keep-1');
        },
      );

      test('shuffle returns safely when server or client is null', () async {
        final container = ProviderContainer(
          overrides: [
            databaseProvider.overrideWithValue(database),
            activeServerProvider.overrideWith((ref) => null),
            activeSubsonicClientProvider.overrideWith((ref) => null),
          ],
        );
        addTearDown(container.dispose);

        await expectLater(
          container.read(dailyRecommendSongsProvider.notifier).shuffle(),
          completes,
        );
        final result = container.read(dailyRecommendSongsProvider);
        expect(result.value ?? const <Song>[], isEmpty);
      });
    },
  );

  group(
    'DailyRecommendSongsNotifier - Lock ownership & Concurrency superseding',
    () {
      test('request lock drops duplicate concurrent shuffle calls', () async {
        final completer = Completer<List<Song>>();
        var fetchCalls = 0;

        final client = _FakeSubsonicClient(
          getRandomSongsHandler:
              ({fromYear, genre, musicFolderId, size, toYear}) async {
                fetchCalls++;
                if (fetchCalls == 1) {
                  return const <Song>[
                    Song(id: 'song-init', title: 'Init Song'),
                  ];
                }
                return completer.future;
              },
        );

        final container = ProviderContainer(
          overrides: [
            databaseProvider.overrideWithValue(database),
            activeServerProvider.overrideWith((ref) => server1),
            activeSubsonicClientProvider.overrideWith((ref) => client),
          ],
        );
        addTearDown(container.dispose);

        await container.read(dailyRecommendSongsProvider.future);
        expect(fetchCalls, 1);

        final notifier = container.read(dailyRecommendSongsProvider.notifier);

        final f1 = notifier.shuffle();
        final f2 = notifier.shuffle();
        final f3 = notifier.shuffle();
        final f4 = notifier.shuffle();

        completer.complete(const <Song>[
          Song(id: 'song-batch-2', title: 'Batch 2 Song'),
        ]);

        await Future.wait([f1, f2, f3, f4]);

        expect(fetchCalls, 2);
        expect(
          container.read(dailyRecommendSongsProvider).value?.first.id,
          'song-batch-2',
        );
      });
      test(
        'lock ownership ensures only the active ticket holder releases the lock',
        () async {
          final completer = Completer<List<Song>>();
          final client = _FakeSubsonicClient(
            getRandomSongsHandler:
                ({fromYear, genre, musicFolderId, size, toYear}) async {
                  return completer.future;
                },
          );

          final container = ProviderContainer(
            overrides: [
              databaseProvider.overrideWithValue(database),
              activeServerProvider.overrideWith((ref) => server1),
              activeSubsonicClientProvider.overrideWith((ref) => client),
            ],
          );
          addTearDown(container.dispose);

          final notifier = container.read(dailyRecommendSongsProvider.notifier);
          final shuffleFuture = notifier.shuffle();
          expect(notifier.isShuffling, isTrue);

          // Complete the shuffle
          completer.complete(const <Song>[
            Song(id: 'song-lock-1', title: 'Lock Test Song'),
          ]);
          await shuffleFuture;

          expect(notifier.isShuffling, isFalse);
        },
      );

      test(
        'stale generation response is superseded and does not overwrite newer state',
        () async {
          final completerGen1 = Completer<List<Song>>();
          final completerGen2 = Completer<List<Song>>();
          var callIndex = 0;

          final client = _FakeSubsonicClient(
            getRandomSongsHandler:
                ({fromYear, genre, musicFolderId, size, toYear}) async {
                  callIndex++;
                  if (callIndex == 1) {
                    return const <Song>[Song(id: 'initial', title: 'Initial')];
                  } else if (callIndex == 2) {
                    return completerGen1.future;
                  } else {
                    return completerGen2.future;
                  }
                },
          );

          final container = ProviderContainer(
            overrides: [
              databaseProvider.overrideWithValue(database),
              activeServerProvider.overrideWith((ref) => server1),
              activeSubsonicClientProvider.overrideWith((ref) => client),
            ],
          );
          addTearDown(container.dispose);

          await container.read(dailyRecommendSongsProvider.future);
          final notifier = container.read(dailyRecommendSongsProvider.notifier);

          // Start shuffle 1 (gen 2)
          final f1 = notifier.shuffle();
          expect(notifier.isShuffling, isTrue);

          // Clear database cache so that invalidate re-fetches from network for gen 3
          await database.delete(database.dailyRecommends).go();

          // Refresh provider, triggering build() (gen 3)
          container.invalidate(dailyRecommendSongsProvider);
          final fGen2Build = container.read(dailyRecommendSongsProvider.future);
          // Complete Gen 3 (the new build)
          completerGen2.complete(const <Song>[
            Song(id: 'gen-3-song', title: 'Gen 3 Song'),
          ]);
          await fGen2Build;
          expect(
            container.read(dailyRecommendSongsProvider).value?.first.id,
            'gen-3-song',
          );

          // Now complete the stale Gen 2 shuffle
          completerGen1.complete(const <Song>[
            Song(id: 'gen-2-stale-song', title: 'Gen 2 Stale Song'),
          ]);
          await f1;

          // UI state must retain gen-3-song!
          expect(
            container.read(dailyRecommendSongsProvider).value?.first.id,
            'gen-3-song',
          );
        },
      );
    },
  );

  group(
    'DailyRecommendCacheCoordinator - DB write serialization, Queueing & Isolation',
    () {
      test(
        'newer generation overwrites older generation on same date',
        () async {
          const date = '2026-10-09';
          await DailyRecommendCacheCoordinator.upsert(
            database: database,
            serverId: server1.id,
            date: date,
            generation: 1,
            songsJson: jsonEncode([
              {'id': 'gen-1', 'title': 'Gen 1'},
            ]),
          );

          await DailyRecommendCacheCoordinator.upsert(
            database: database,
            serverId: server1.id,
            date: date,
            generation: 2,
            songsJson: jsonEncode([
              {'id': 'gen-2', 'title': 'Gen 2'},
            ]),
          );

          final cached = await database.getDailyRecommend(server1.id, date);
          expect(cached?.songsJson, contains('gen-2'));
          final state = DailyRecommendCacheCoordinator.getCommittedState(
            server1.id,
            database: database,
          );
          expect(state?.generation, 2);
        },
      );

      test(
        'older generation does NOT overwrite newer generation on same date',
        () async {
          const date = '2026-10-09';
          await DailyRecommendCacheCoordinator.upsert(
            database: database,
            serverId: server1.id,
            date: date,
            generation: 5,
            songsJson: jsonEncode([
              {'id': 'gen-5', 'title': 'Gen 5'},
            ]),
          );

          await DailyRecommendCacheCoordinator.upsert(
            database: database,
            serverId: server1.id,
            date: date,
            generation: 3,
            songsJson: jsonEncode([
              {'id': 'gen-3', 'title': 'Gen 3'},
            ]),
          );

          final cached = await database.getDailyRecommend(server1.id, date);
          expect(cached?.songsJson, contains('gen-5'));
          expect(cached?.songsJson, isNot(contains('gen-3')));
          final state = DailyRecommendCacheCoordinator.getCommittedState(
            server1.id,
            database: database,
          );
          expect(state?.generation, 5);
        },
      );

      test(
        'newer date supersedes older date regardless of generation',
        () async {
          await DailyRecommendCacheCoordinator.upsert(
            database: database,
            serverId: server1.id,
            date: '2026-10-09',
            generation: 10,
            songsJson: jsonEncode([
              {'id': 'day1', 'title': 'Day 1'},
            ]),
          );

          await DailyRecommendCacheCoordinator.upsert(
            database: database,
            serverId: server1.id,
            date: '2026-10-10',
            generation: 1,
            songsJson: jsonEncode([
              {'id': 'day2', 'title': 'Day 2'},
            ]),
          );

          final cached = await database.getDailyRecommend(
            server1.id,
            '2026-10-10',
          );
          expect(cached?.songsJson, contains('day2'));

          await DailyRecommendCacheCoordinator.upsert(
            database: database,
            serverId: server1.id,
            date: '2026-10-08',
            generation: 99,
            songsJson: jsonEncode([
              {'id': 'stale-day', 'title': 'Stale Day'},
            ]),
          );

          final staleCached = await database.getDailyRecommend(
            server1.id,
            '2026-10-08',
          );
          expect(staleCached, isNull);
        },
      );

      test(
        'cache coordinator isolates writes across different serverIds',
        () async {
          const date = '2026-10-09';
          await DailyRecommendCacheCoordinator.upsert(
            database: database,
            serverId: server1.id,
            date: date,
            generation: 2,
            songsJson: jsonEncode([
              {'id': 's1-song', 'title': 'Server 1 Song'},
            ]),
          );

          await DailyRecommendCacheCoordinator.upsert(
            database: database,
            serverId: server2.id,
            date: date,
            generation: 1,
            songsJson: jsonEncode([
              {'id': 's2-song', 'title': 'Server 2 Song'},
            ]),
          );

          final s1 = await database.getDailyRecommend(server1.id, date);
          final s2 = await database.getDailyRecommend(server2.id, date);
          expect(s1?.songsJson, contains('s1-song'));
          expect(s2?.songsJson, contains('s2-song'));
        },
      );

      test(
        'cache coordinator isolates state across different AppDatabase instances',
        () async {
          driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
          final dbA = AppDatabase(NativeDatabase.memory());
          final dbB = AppDatabase(NativeDatabase.memory());
          addTearDown(dbA.close);
          addTearDown(dbB.close);

          const date = '2026-10-09';
          await DailyRecommendCacheCoordinator.upsert(
            database: dbA,
            serverId: 1,
            date: date,
            generation: 10,
            songsJson: jsonEncode([
              {'id': 'dbA-song', 'title': 'DbA Song'},
            ]),
          );

          await DailyRecommendCacheCoordinator.upsert(
            database: dbB,
            serverId: 1,
            date: date,
            generation: 2,
            songsJson: jsonEncode([
              {'id': 'dbB-song', 'title': 'DbB Song'},
            ]),
          );

          final stateA = DailyRecommendCacheCoordinator.getCommittedState(
            1,
            database: dbA,
          );
          final stateB = DailyRecommendCacheCoordinator.getCommittedState(
            1,
            database: dbB,
          );

          expect(stateA?.generation, 10);
          expect(stateB?.generation, 2);

          final rowA = await dbA.getDailyRecommend(1, date);
          final rowB = await dbB.getDailyRecommend(1, date);
          expect(rowA?.songsJson, contains('dbA-song'));
          expect(rowB?.songsJson, contains('dbB-song'));
        },
      );

      test(
        'readCache waits for in-flight DB write queue before reading',
        () async {
          const date = '2026-10-09';

          // Enqueue a slow write by chaining through coordinator queue
          final writeFuture = DailyRecommendCacheCoordinator.upsert(
            database: database,
            serverId: server1.id,
            date: date,
            generation: 1,
            songsJson: jsonEncode([
              {'id': 'queued-write', 'title': 'Queued Write Song'},
            ]),
          );

          // readCache should await the in-flight upsert and see the written row
          final readFuture = DailyRecommendCacheCoordinator.readCache(
            database: database,
            serverId: server1.id,
            date: date,
          );

          await writeFuture;
          final readResult = await readFuture;
          expect(readResult?.songsJson, contains('queued-write'));
        },
      );
    },
  );

  group('DailyRecommendSongsNotifier - Server switching & Disposal isolation', () {
    test(
      'switching active server drops pending responses from previous server on UI but caches to original DB key',
      () async {
        final completerServer1 = Completer<List<Song>>();
        var clientCalls = 0;

        final client = _FakeSubsonicClient(
          getRandomSongsHandler:
              ({fromYear, genre, musicFolderId, size, toYear}) async {
                clientCalls++;
                if (clientCalls == 1) {
                  return const <Song>[Song(id: 's1-init', title: 'S1 Init')];
                } else if (clientCalls == 2) {
                  return completerServer1.future;
                } else {
                  return const <Song>[Song(id: 's2-init', title: 'S2 Init')];
                }
              },
        );

        final serverNotifier = NotifierProvider<_TestServerNotifier, Server?>(
          () => _TestServerNotifier(server1),
        );

        final container = ProviderContainer(
          overrides: [
            databaseProvider.overrideWithValue(database),
            activeServerProvider.overrideWith(
              (ref) => ref.watch(serverNotifier),
            ),
            activeSubsonicClientProvider.overrideWith((ref) => client),
          ],
        );
        addTearDown(container.dispose);

        final s1Initial = await container.read(
          dailyRecommendSongsProvider.future,
        );
        expect(s1Initial.first.id, 's1-init');

        // Start slow shuffle for server 1
        final shuffleFuture = container
            .read(dailyRecommendSongsProvider.notifier)
            .shuffle();

        // Switch active server to Server 2
        container.read(serverNotifier.notifier).setServer(server2);

        // Re-read provider for server 2
        final s2Initial = await container.read(
          dailyRecommendSongsProvider.future,
        );
        expect(s2Initial.first.id, 's2-init');

        // Complete server 1's slow shuffle
        completerServer1.complete(const <Song>[
          Song(id: 's1-delayed', title: 'S1 Delayed'),
        ]);
        await shuffleFuture;

        // State must still be Server 2's data!
        expect(
          container.read(dailyRecommendSongsProvider).value?.first.id,
          's2-init',
        );

        // But Server 1's DB cache must have received the write
        final now = DateTime.now();
        final date =
            '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
        final s1Cache = await database.getDailyRecommend(server1.id, date);
        expect(s1Cache?.songsJson, contains('s1-delayed'));
      },
    );

    test(
      'disposing container while shuffle is in-flight does not crash and does not update state',
      () async {
        final completer = Completer<List<Song>>();
        final client = _FakeSubsonicClient(
          getRandomSongsHandler:
              ({fromYear, genre, musicFolderId, size, toYear}) async {
                return completer.future;
              },
        );

        final container = ProviderContainer(
          overrides: [
            databaseProvider.overrideWithValue(database),
            activeServerProvider.overrideWith((ref) => server1),
            activeSubsonicClientProvider.overrideWith((ref) => client),
          ],
        );

        final future = container
            .read(dailyRecommendSongsProvider.notifier)
            .shuffle();

        container.dispose();

        completer.complete(const <Song>[
          Song(id: 'disposed-song', title: 'Disposed Song'),
        ]);

        await expectLater(future, completes);
      },
    );
  });
}
