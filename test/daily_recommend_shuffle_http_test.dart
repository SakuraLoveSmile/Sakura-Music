import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramusic/core/providers.dart';
import 'package:sakuramusic/data/db/app_database.dart';
import 'package:sakuramusic/data/server_repository.dart';
import 'package:subsonic_api/subsonic_api.dart';

/// Regression coverage for the home daily-recommendation card's "shuffle"
/// button (the round button on the right edge of the card).
///
/// Tapping it must fetch a fresh random batch, bypassing today's cache, and
/// refresh the card without ever starting playback — the playback wiring is
/// deliberately absent from the provider. A failed request keeps the previous
/// batch instead of surfacing an error.

String _ok([Map<String, dynamic>? body]) {
  return jsonEncode(<String, dynamic>{
    'subsonic-response': <String, dynamic>{'status': 'ok', ...?body},
  });
}

String _randomSongsBody(List<Song> songs) {
  return _ok(<String, dynamic>{
    'randomSongs': <String, dynamic>{
      'song': <Map<String, dynamic>>[for (final song in songs) song.toJson()],
    },
  });
}

Song _song(String id) => Song(id: id, title: 'Song $id');

String _dateKey(DateTime now) {
  return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
}

/// Starts a loopback HTTP server backed by [handler]; the returned base URL
/// feeds a [SubsonicClient].
Future<(HttpServer, String)> _startServer(
  Future<void> Function(HttpRequest request) handler,
) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  server.listen((request) async {
    try {
      await handler(request);
    } catch (_) {
      try {
        await request.response.close();
      } catch (_) {}
    }
  });
  return (server, 'http://127.0.0.1:${server.port}');
}

Future<Server> _insertServer(AppDatabase database, String baseUrl) async {
  final serverId = await database.insertServer(
    ServersCompanion.insert(
      name: 'Navidrome',
      baseUrl: baseUrl,
      username: 'listener',
      password: '',
    ),
  );
  return (await database.getServer(serverId))!;
}

Future<void> _seedTodayCache(
  AppDatabase database,
  int serverId,
  List<Song> songs,
) {
  return database.upsertDailyRecommend(
    serverId,
    _dateKey(DateTime.now()),
    jsonEncode(songs.map((song) => song.toJson()).toList(growable: false)),
  );
}

Future<List<String>> _cachedSongIds(AppDatabase database, int serverId) async {
  final cached = await database.getDailyRecommend(
    serverId,
    _dateKey(DateTime.now()),
  );
  final decoded = jsonDecode(cached!.songsJson) as List<dynamic>;
  return <String>[
    for (final entry in decoded)
      (entry as Map<String, dynamic>)['id'] as String,
  ];
}

ProviderContainer _containerFor(
  AppDatabase database,
  Server server,
  String baseUrl,
) {
  return ProviderContainer(
    overrides: [
      databaseProvider.overrideWithValue(database),
      activeServerProvider.overrideWithValue(server),
      activeSubsonicClientProvider.overrideWithValue(
        SubsonicClient(
          baseUrl: baseUrl,
          username: 'listener',
          password: 'password',
        ),
      ),
    ],
  );
}

/// A loopback Subsonic endpoint whose responses stay pending until the test
/// releases them, so in-flight requests can be driven with explicit gates
/// instead of fixed sleeps.
class _GatedServer {
  _GatedServer._(this.server, this.baseUrl);

  final HttpServer server;
  final String baseUrl;

  final List<Uri> requests = <Uri>[];
  final List<Completer<void>> _arrived = <Completer<void>>[];
  final List<Completer<List<Song>>> _pending = <Completer<List<Song>>>[];

  static Future<_GatedServer> start() async {
    late final _GatedServer gated;
    final (server, baseUrl) = await _startServer((request) async {
      final index = gated.requests.length;
      gated.requests.add(request.uri);
      while (gated._arrived.length <= index) {
        gated._arrived.add(Completer<void>());
      }
      if (!gated._arrived[index].isCompleted) {
        gated._arrived[index].complete();
      }
      final pending = Completer<List<Song>>();
      gated._pending.add(pending);
      final songs = await pending.future;
      request.response
        ..headers.contentType = ContentType.json
        ..write(_randomSongsBody(songs));
      await request.response.close();
    });
    gated = _GatedServer._(server, baseUrl);
    return gated;
  }

  /// Completes once the [index]-th (0-based) request reached the server.
  Future<void> requestArrived(int index) {
    while (_arrived.length <= index) {
      _arrived.add(Completer<void>());
    }
    return _arrived[index].future;
  }

  /// Answers the [index]-th (0-based) request with [songs].
  void release(int index, List<Song> songs) => _pending[index].complete(songs);
}

void main() {
  test(
    'shuffle bypasses the daily cache, refreshes the card and updates it',
    () async {
      final requests = <Uri>[];
      final (httpServer, baseUrl) = await _startServer((request) async {
        requests.add(request.uri);
        request.response
          ..headers.contentType = ContentType.json
          ..write(_randomSongsBody(<Song>[_song('song-21'), _song('song-22')]));
        await request.response.close();
      });
      addTearDown(() => httpServer.close(force: true));

      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);

      final server = await _insertServer(database, baseUrl);
      await _seedTodayCache(database, server.id, <Song>[
        _song('song-1'),
        _song('song-2'),
      ]);

      final container = _containerFor(database, server, baseUrl);
      addTearDown(container.dispose);

      // The card starts from today's cached batch without hitting the server.
      final initial = await container.read(dailyRecommendSongsProvider.future);
      expect(initial.map((song) => song.id).toList(), <String>[
        'song-1',
        'song-2',
      ]);
      expect(requests, isEmpty);

      await container.read(dailyRecommendSongsProvider.notifier).shuffle();

      final state = container.read(dailyRecommendSongsProvider);
      expect(state.hasError, isFalse);
      expect(state.value!.map((song) => song.id).toList(), <String>[
        'song-21',
        'song-22',
      ]);
      // The fresh batch replaces today's cache so the card stays stable.
      expect(await _cachedSongIds(database, server.id), <String>[
        'song-21',
        'song-22',
      ]);
      expect(requests, hasLength(1));
      expect(requests.single.path, '/rest/getRandomSongs');
      expect(requests.single.queryParameters['size'], '20');
    },
  );

  test('a failed shuffle keeps the previous batch', () async {
    final (httpServer, baseUrl) = await _startServer((request) async {
      request.response.statusCode = HttpStatus.internalServerError;
      await request.response.close();
    });
    addTearDown(() => httpServer.close(force: true));

    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    final server = await _insertServer(database, baseUrl);
    await _seedTodayCache(database, server.id, <Song>[
      _song('song-1'),
      _song('song-2'),
    ]);

    final container = _containerFor(database, server, baseUrl);
    addTearDown(container.dispose);

    await container.read(dailyRecommendSongsProvider.future);

    await container.read(dailyRecommendSongsProvider.notifier).shuffle();

    final state = container.read(dailyRecommendSongsProvider);
    expect(state.hasError, isFalse);
    expect(state.value!.map((song) => song.id).toList(), <String>[
      'song-1',
      'song-2',
    ]);
    expect(await _cachedSongIds(database, server.id), <String>[
      'song-1',
      'song-2',
    ]);
  });

  test(
    'every shuffle bypasses the cache and always asks for size 20',
    () async {
      var response = <Song>[_song('song-21'), _song('song-22')];
      final requests = <Uri>[];
      final (httpServer, baseUrl) = await _startServer((request) async {
        requests.add(request.uri);
        request.response
          ..headers.contentType = ContentType.json
          ..write(_randomSongsBody(response));
        await request.response.close();
      });
      addTearDown(() => httpServer.close(force: true));

      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);

      final server = await _insertServer(database, baseUrl);
      await _seedTodayCache(database, server.id, <Song>[
        _song('song-1'),
        _song('song-2'),
      ]);

      final container = _containerFor(database, server, baseUrl);
      addTearDown(container.dispose);
      final notifier = container.read(dailyRecommendSongsProvider.notifier);

      await container.read(dailyRecommendSongsProvider.future);
      expect(
        requests,
        isEmpty,
        reason: 'the cached batch is served without HTTP',
      );

      await notifier.shuffle();
      expect(requests, hasLength(1));
      expect(requests.single.path, '/rest/getRandomSongs');
      expect(requests.single.queryParameters['size'], '20');

      // A second shuffle must hit the server again: the batch just written to
      // the cache is never served back to the user as a "fresh" result.
      response = <Song>[_song('song-31'), _song('song-32')];
      await notifier.shuffle();
      expect(requests, hasLength(2), reason: 'shuffle never serves the cache');
      expect(requests.last.queryParameters['size'], '20');
      expect(
        container
            .read(dailyRecommendSongsProvider)
            .value!
            .map((song) => song.id)
            .toSet(),
        <String>{'song-31', 'song-32'},
      );
    },
  );

  test(
    "a successful shuffle rewrites today's cache for the current server",
    () async {
      final requests = <Uri>[];
      final (httpServer, baseUrl) = await _startServer((request) async {
        requests.add(request.uri);
        request.response
          ..headers.contentType = ContentType.json
          ..write(_randomSongsBody(<Song>[_song('song-1'), _song('song-3')]));
        await request.response.close();
      });
      addTearDown(() => httpServer.close(force: true));

      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);

      final server = await _insertServer(database, baseUrl);
      await _seedTodayCache(database, server.id, <Song>[
        _song('song-1'),
        _song('song-2'),
      ]);

      final container = _containerFor(database, server, baseUrl);
      addTearDown(container.dispose);

      final initial = await container.read(dailyRecommendSongsProvider.future);
      expect(initial.map((song) => song.id).toList(), <String>[
        'song-1',
        'song-2',
      ]);

      await container.read(dailyRecommendSongsProvider.notifier).shuffle();

      final displayed = container
          .read(dailyRecommendSongsProvider)
          .value!
          .map((song) => song.id)
          .toList();
      expect(displayed.first, isNot('song-1'));
      expect(displayed, <String>['song-3', 'song-1']);
      expect(await _cachedSongIds(database, server.id), displayed);

      // Re-entering home rebuilds the provider from the cache: it must show the
      // refreshed order, not revert to the old first song.
      container.invalidate(dailyRecommendSongsProvider);
      final reentered = await container.read(
        dailyRecommendSongsProvider.future,
      );
      expect(reentered.map((song) => song.id).toList(), displayed);
      expect(reentered.first.id, isNot('song-1'));
      expect(requests, hasLength(1), reason: 'the refreshed cache is served');
    },
  );

  test(
    'rotation moves another response song to the front over many rounds',
    () async {
      var displayedFirst = 'song-1';
      final requests = <Uri>[];
      final (httpServer, baseUrl) = await _startServer((request) async {
        requests.add(request.uri);
        request.response
          ..headers.contentType = ContentType.json
          ..write(
            _randomSongsBody(<Song>[
              _song(displayedFirst),
              _song('song-other-1'),
              _song('song-other-2'),
            ]),
          );
        await request.response.close();
      });
      addTearDown(() => httpServer.close(force: true));

      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);

      final server = await _insertServer(database, baseUrl);
      await _seedTodayCache(database, server.id, <Song>[
        _song('song-1'),
        _song('song-2'),
      ]);

      final container = _containerFor(database, server, baseUrl);
      addTearDown(container.dispose);
      final notifier = container.read(dailyRecommendSongsProvider.notifier);
      await container.read(dailyRecommendSongsProvider.future);

      for (var round = 0; round < 30; round++) {
        final before = container
            .read(dailyRecommendSongsProvider)
            .value!
            .map((song) => song.id)
            .toList();
        await notifier.shuffle();
        final after = container
            .read(dailyRecommendSongsProvider)
            .value!
            .map((song) => song.id)
            .toList();
        expect(
          after.first,
          isNot(before.first),
          reason: 'round $round: the displayed first song must change',
        );
        expect(after, hasLength(3));
        expect(after.toSet(), <String>{
          displayedFirst,
          'song-other-1',
          'song-other-2',
        }, reason: 'round $round: every response song is retained');
        displayedFirst = after.first;
      }
      expect(requests, hasLength(30));
    },
  );

  test(
    'a response of only the displayed song keeps the card and cache',
    () async {
      final requests = <Uri>[];
      final (httpServer, baseUrl) = await _startServer((request) async {
        requests.add(request.uri);
        request.response
          ..headers.contentType = ContentType.json
          ..write(_randomSongsBody(<Song>[_song('song-1')]));
        await request.response.close();
      });
      addTearDown(() => httpServer.close(force: true));

      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);

      final server = await _insertServer(database, baseUrl);
      await _seedTodayCache(database, server.id, <Song>[
        _song('song-1'),
        _song('song-2'),
      ]);

      final container = _containerFor(database, server, baseUrl);
      addTearDown(container.dispose);
      await container.read(dailyRecommendSongsProvider.future);

      await container.read(dailyRecommendSongsProvider.notifier).shuffle();

      final state = container.read(dailyRecommendSongsProvider);
      expect(state.hasError, isFalse);
      expect(state.value!.map((song) => song.id).toList(), <String>[
        'song-1',
        'song-2',
      ]);
      expect(await _cachedSongIds(database, server.id), <String>[
        'song-1',
        'song-2',
      ]);
      expect(requests, hasLength(1));
    },
  );

  test('an empty response keeps the card and cache', () async {
    final requests = <Uri>[];
    final (httpServer, baseUrl) = await _startServer((request) async {
      requests.add(request.uri);
      request.response
        ..headers.contentType = ContentType.json
        ..write(_randomSongsBody(const <Song>[]));
      await request.response.close();
    });
    addTearDown(() => httpServer.close(force: true));

    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    final server = await _insertServer(database, baseUrl);
    await _seedTodayCache(database, server.id, <Song>[
      _song('song-1'),
      _song('song-2'),
    ]);

    final container = _containerFor(database, server, baseUrl);
    addTearDown(container.dispose);
    await container.read(dailyRecommendSongsProvider.future);

    await container.read(dailyRecommendSongsProvider.notifier).shuffle();

    final state = container.read(dailyRecommendSongsProvider);
    expect(state.hasError, isFalse);
    expect(state.value!.map((song) => song.id).toList(), <String>[
      'song-1',
      'song-2',
    ]);
    expect(await _cachedSongIds(database, server.id), <String>[
      'song-1',
      'song-2',
    ]);
    expect(requests, hasLength(1));
  });

  test(
    'a failed shuffle keeps the batch and the cache and never retries',
    () async {
      final requests = <Uri>[];
      final (httpServer, baseUrl) = await _startServer((request) async {
        requests.add(request.uri);
        request.response.statusCode = HttpStatus.internalServerError;
        await request.response.close();
      });
      addTearDown(() => httpServer.close(force: true));

      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);

      final server = await _insertServer(database, baseUrl);
      await _seedTodayCache(database, server.id, <Song>[
        _song('song-1'),
        _song('song-2'),
      ]);

      final container = _containerFor(database, server, baseUrl);
      addTearDown(container.dispose);
      await container.read(dailyRecommendSongsProvider.future);

      await container.read(dailyRecommendSongsProvider.notifier).shuffle();

      final state = container.read(dailyRecommendSongsProvider);
      expect(state.hasError, isFalse);
      expect(state.value!.map((song) => song.id).toList(), <String>[
        'song-1',
        'song-2',
      ]);
      expect(await _cachedSongIds(database, server.id), <String>[
        'song-1',
        'song-2',
      ]);
      expect(requests, hasLength(1), reason: 'a failure must not be retried');
    },
  );

  test(
    'repeated taps in flight are ignored and the guard is released after',
    () async {
      final gated = await _GatedServer.start();
      addTearDown(() => gated.server.close(force: true));

      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);

      final server = await _insertServer(database, gated.baseUrl);
      await _seedTodayCache(database, server.id, <Song>[
        _song('song-1'),
        _song('song-2'),
      ]);

      final container = _containerFor(database, server, gated.baseUrl);
      addTearDown(container.dispose);
      final notifier = container.read(dailyRecommendSongsProvider.notifier);
      await container.read(dailyRecommendSongsProvider.future);

      final first = notifier.shuffle();
      final second = notifier.shuffle();
      final third = notifier.shuffle();
      await gated.requestArrived(0);
      expect(gated.requests, hasLength(1));

      gated.release(0, <Song>[_song('song-21'), _song('song-22')]);
      await Future.wait(<Future<void>>[first, second, third]);
      expect(
        gated.requests,
        hasLength(1),
        reason: 'repeated taps must not reach the server',
      );
      expect(
        container
            .read(dailyRecommendSongsProvider)
            .value!
            .map((song) => song.id)
            .toSet(),
        <String>{'song-21', 'song-22'},
      );

      // The in-flight guard is released once the request finishes.
      final fourth = notifier.shuffle();
      await gated.requestArrived(1);
      gated.release(1, <Song>[_song('song-31'), _song('song-32')]);
      await fourth;
      expect(gated.requests, hasLength(2));
      expect(
        container
            .read(dailyRecommendSongsProvider)
            .value!
            .map((song) => song.id)
            .toSet(),
        <String>{'song-31', 'song-32'},
      );
    },
  );

  test(
    'a stale library response cannot touch the newly selected library',
    () async {
      final gatedA = await _GatedServer.start();
      addTearDown(() => gatedA.server.close(force: true));

      final requestsB = <Uri>[];
      final (httpServerB, baseUrlB) = await _startServer((request) async {
        requestsB.add(request.uri);
        request.response
          ..headers.contentType = ContentType.json
          ..write(
            _randomSongsBody(<Song>[_song('b-1'), _song('b-2'), _song('b-3')]),
          );
        await request.response.close();
      });
      addTearDown(() => httpServerB.close(force: true));

      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);

      final serverA = await _insertServer(database, gatedA.baseUrl);
      final serverB = await _insertServer(database, baseUrlB);
      await _seedTodayCache(database, serverA.id, <Song>[
        _song('a-1'),
        _song('a-2'),
      ]);
      await _seedTodayCache(database, serverB.id, <Song>[
        _song('b-1'),
        _song('b-2'),
      ]);

      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(database),
          serversProvider.overrideWithValue(
            AsyncValue.data(<Server>[serverA, serverB]),
          ),
          activeSubsonicClientProvider.overrideWith((ref) {
            final server = ref.watch(activeServerProvider);
            if (server == null) {
              return null;
            }
            return SubsonicClient(
              baseUrl: server.baseUrl,
              username: 'listener',
              password: 'password',
            );
          }),
        ],
      );
      addTearDown(container.dispose);
      container.read(selectedServerIdProvider.notifier).state = serverA.id;

      final notifier = container.read(dailyRecommendSongsProvider.notifier);
      final initial = await container.read(dailyRecommendSongsProvider.future);
      expect(initial.map((song) => song.id).toList(), <String>['a-1', 'a-2']);

      // Library A's shuffle is held in flight.
      final staleShuffle = notifier.shuffle();
      await gatedA.requestArrived(0);
      expect(gatedA.requests, hasLength(1));

      // Switch libraries while A's request is still open.
      container.read(selectedServerIdProvider.notifier).state = serverB.id;
      final switched = await container.read(dailyRecommendSongsProvider.future);
      expect(switched.map((song) => song.id).toList(), <String>['b-1', 'b-2']);

      // A shuffle for the new library must not be blocked by the stale mutex.
      final newShuffle = container
          .read(dailyRecommendSongsProvider.notifier)
          .shuffle();
      await newShuffle;
      expect(
        requestsB,
        hasLength(1),
        reason: 'the stale request must not block the new library',
      );

      final afterB = container
          .read(dailyRecommendSongsProvider)
          .value!
          .map((song) => song.id)
          .toList();
      expect(afterB.first, isNot('b-1'));
      expect(afterB.toSet(), <String>{'b-1', 'b-2', 'b-3'});
      expect(await _cachedSongIds(database, serverB.id), afterB);

      // Completing library A's late response must not touch B and must write
      // library A's own cache key.
      gatedA.release(0, <Song>[_song('a-1'), _song('a-2'), _song('a-3')]);
      await staleShuffle;

      expect(
        container
            .read(dailyRecommendSongsProvider)
            .value!
            .map((song) => song.id)
            .toList(),
        afterB,
        reason: 'a stale response must not change the new library card',
      );
      expect(await _cachedSongIds(database, serverB.id), afterB);
      expect(
        await _cachedSongIds(database, serverA.id),
        anyOf([
          equals(<String>['a-2', 'a-1', 'a-3']),
          equals(<String>['a-3', 'a-1', 'a-2']),
        ]),
        reason: 'the stale request rotates against its captured original batch',
      );
      expect(gatedA.requests, hasLength(1));
    },
  );

  test(
    'disposal during an in-flight shuffle still writes the captured key',
    () async {
      final gated = await _GatedServer.start();
      addTearDown(() => gated.server.close(force: true));

      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);

      final server = await _insertServer(database, gated.baseUrl);
      await _seedTodayCache(database, server.id, <Song>[
        _song('song-1'),
        _song('song-2'),
      ]);

      final container = _containerFor(database, server, gated.baseUrl);
      final notifier = container.read(dailyRecommendSongsProvider.notifier);
      await container.read(dailyRecommendSongsProvider.future);

      final shuffle = notifier.shuffle();
      await gated.requestArrived(0);

      container.dispose();
      gated.release(0, <Song>[_song('song-1'), _song('song-3')]);

      // Completing after disposal must not raise an unhandled "used after
      // dispose" error.
      await expectLater(shuffle, completes);
      expect(
        await _cachedSongIds(database, server.id),
        <String>['song-3', 'song-1'],
        reason: 'the originally captured cache key is still written',
      );
    },
  );

  test(
    'a duplicate of the displayed song comes back and another still leads',
    () async {
      // The server repeats the displayed song TWICE and adds a new one. The
      // card must still move to a different song, and every entry the server
      // sent must survive exactly once-per-original-occurrence.
      final requests = <Uri>[];
      final (httpServer, baseUrl) = await _startServer((request) async {
        requests.add(request.uri);
        request.response
          ..headers.contentType = ContentType.json
          ..write(
            _randomSongsBody(<Song>[
              _song('song-1'),
              _song('song-3'),
              _song('song-1'),
            ]),
          );
        await request.response.close();
      });
      addTearDown(() => httpServer.close(force: true));

      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);

      final server = await _insertServer(database, baseUrl);
      await _seedTodayCache(database, server.id, <Song>[
        _song('song-1'),
        _song('song-2'),
      ]);

      final container = _containerFor(database, server, baseUrl);
      addTearDown(container.dispose);
      await container.read(dailyRecommendSongsProvider.future);

      await container.read(dailyRecommendSongsProvider.notifier).shuffle();

      final shown = container
          .read(dailyRecommendSongsProvider)
          .value!
          .map((song) => song.id)
          .toList();
      expect(shown.first, isNot('song-1'));
      expect(shown.first, 'song-3');
      // Only the picked entry moved; the duplicate of the displayed song stays.
      expect(shown, hasLength(3));
      expect(shown.where((id) => id == 'song-1'), hasLength(2));
      expect(await _cachedSongIds(database, server.id), shown);
      expect(requests, hasLength(1));
    },
  );

  test(
    'the displayed song appearing later in the batch still rotates the card',
    () async {
      // First entry is already new, so the batch order is shown as-is; the
      // displayed song simply not being first is enough. This pins the case
      // where the repeated song is NOT at index 0.
      final requests = <Uri>[];
      final (httpServer, baseUrl) = await _startServer((request) async {
        requests.add(request.uri);
        request.response
          ..headers.contentType = ContentType.json
          ..write(
            _randomSongsBody(<Song>[
              _song('song-9'),
              _song('song-1'),
              _song('song-8'),
            ]),
          );
        await request.response.close();
      });
      addTearDown(() => httpServer.close(force: true));

      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);

      final server = await _insertServer(database, baseUrl);
      await _seedTodayCache(database, server.id, <Song>[
        _song('song-1'),
        _song('song-2'),
      ]);

      final container = _containerFor(database, server, baseUrl);
      addTearDown(container.dispose);
      await container.read(dailyRecommendSongsProvider.future);

      await container.read(dailyRecommendSongsProvider.notifier).shuffle();

      final shown = container
          .read(dailyRecommendSongsProvider)
          .value!
          .map((song) => song.id)
          .toList();
      expect(shown, <String>['song-9', 'song-1', 'song-8']);
      expect(await _cachedSongIds(database, server.id), shown);
      expect(requests, hasLength(1));
    },
  );

  test(
    'a rebuild of the same library mid-flight keeps the new state and cache',
    () async {
      // A rebuild (not a library switch) bumps the generation too: the late
      // response must not decide what the rebuilt provider shows, and must not
      // release a newer request's mutex.
      final gated = await _GatedServer.start();
      addTearDown(() => gated.server.close(force: true));

      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);

      final server = await _insertServer(database, gated.baseUrl);
      await _seedTodayCache(database, server.id, <Song>[
        _song('song-1'),
        _song('song-2'),
      ]);

      final container = _containerFor(database, server, gated.baseUrl);
      addTearDown(container.dispose);

      final notifier = container.read(dailyRecommendSongsProvider.notifier);
      await container.read(dailyRecommendSongsProvider.future);

      // Hold one shuffle in flight, then force a rebuild of the provider.
      final staleShuffle = notifier.shuffle();
      await gated.requestArrived(0);
      container.invalidate(dailyRecommendSongsProvider);
      expect(
        (await container.read(
          dailyRecommendSongsProvider.future,
        )).map((song) => song.id).toList(),
        <String>['song-1', 'song-2'],
      );

      // A fresh shuffle for the rebuilt provider must not be blocked.
      final fresh = container
          .read(dailyRecommendSongsProvider.notifier)
          .shuffle();
      await gated.requestArrived(1);
      gated.release(1, <Song>[_song('song-7'), _song('song-8')]);
      await fresh;
      final afterFresh = container
          .read(dailyRecommendSongsProvider)
          .value!
          .map((song) => song.id)
          .toList();
      expect(afterFresh, <String>['song-7', 'song-8']);

      // The stale response lands last and must change nothing.
      gated.release(0, <Song>[
        _song('song-1'),
        _song('song-2'),
        _song('song-3'),
      ]);
      await staleShuffle;
      expect(
        container
            .read(dailyRecommendSongsProvider)
            .value!
            .map((song) => song.id)
            .toList(),
        afterFresh,
        reason: 'a response from before the rebuild must not win',
      );
      expect(await _cachedSongIds(database, server.id), afterFresh);
    },
  );
}
