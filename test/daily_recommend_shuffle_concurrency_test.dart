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

Song _song(String id) => Song(id: id, title: id);
String get _today {
  final now = DateTime.now();
  return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
}

class _Client extends Fake implements SubsonicClient {
  final requests = <Completer<List<Song>>>[];
  @override
  Future<List<Song>> getRandomSongs({
    int? size,
    String? genre,
    String? fromYear,
    String? toYear,
    String? musicFolderId,
  }) {
    expect(size, 20);
    final response = Completer<List<Song>>();
    requests.add(response);
    return response.future;
  }
}

class _Selection extends Notifier<Server> {
  _Selection(this.initial);
  final Server initial;
  @override
  Server build() => initial;
  void select(Server server) => state = server;
}

class _DatabaseSelection extends Notifier<AppDatabase> {
  _DatabaseSelection(this.initial);
  final AppDatabase initial;
  @override
  AppDatabase build() => initial;
  void select(AppDatabase database) => state = database;
}

class _GatedDatabase extends AppDatabase {
  _GatedDatabase() : super(NativeDatabase.memory());
  Completer<void>? writeEntered;
  Completer<void>? releaseWrite;
  Completer<void>? readEntered;
  Completer<void>? releaseRead;
  bool failNextWrite = false;
  bool failNextRead = false;

  void gateWrite() {
    writeEntered = Completer<void>();
    releaseWrite = Completer<void>();
  }

  void gateRead() {
    readEntered = Completer<void>();
    releaseRead = Completer<void>();
  }

  @override
  Future<DailyRecommend?> getDailyRecommend(int serverId, String date) async {
    final gate = releaseRead;
    if (gate != null) {
      releaseRead = null;
      readEntered!.complete();
      await gate.future;
    }
    if (failNextRead) {
      failNextRead = false;
      throw StateError('isolated read failure');
    }
    return super.getDailyRecommend(serverId, date);
  }

  @override
  Future<void> upsertDailyRecommend(
    int serverId,
    String date,
    String songsJson,
  ) async {
    final gate = releaseWrite;
    if (gate != null) {
      releaseWrite = null;
      writeEntered!.complete();
      await gate.future;
    }
    if (failNextWrite) {
      failNextWrite = false;
      throw StateError('isolated write failure');
    }
    await super.upsertDailyRecommend(serverId, date, songsJson);
  }
}

Future<void> _seed(AppDatabase database, int serverId, String id) => database
    .upsertDailyRecommend(serverId, _today, jsonEncode([_song(id).toJson()]));
Future<List<String>?> _ids(
  AppDatabase database,
  int serverId, [
  String? date,
]) async {
  final row = await database.getDailyRecommend(serverId, date ?? _today);
  return row == null
      ? null
      : (jsonDecode(row.songsJson) as List)
            .map((song) => song['id'] as String)
            .toList();
}

void main() {
  late _GatedDatabase database;
  late Server a;
  late Server b;

  setUp(() async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    database = _GatedDatabase();
    final aId = await database.insertServer(
      ServersCompanion.insert(
        name: 'A',
        baseUrl: 'https://a.invalid',
        username: 'a',
        password: '',
      ),
    );
    final bId = await database.insertServer(
      ServersCompanion.insert(
        name: 'B',
        baseUrl: 'https://b.invalid',
        username: 'b',
        password: '',
      ),
    );
    a = (await database.getServer(aId))!;
    b = (await database.getServer(bId))!;
    await _seed(database, a.id, 'a-initial');
    await _seed(database, b.id, 'b-initial');
  });
  tearDown(() async {
    DailyRecommendCacheCoordinator.reset(database);
    await database.close();
  });

  ProviderContainer containerFor(
    _Client client, {
    NotifierProvider<_Selection, Server>? selection,
  }) {
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(database),
        activeServerProvider.overrideWith(
          (ref) => selection == null ? a : ref.watch(selection),
        ),
        activeSubsonicClientProvider.overrideWithValue(client),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test(
    'server B shuffles while A is pending and old completion cannot release B lock',
    () async {
      final client = _Client();
      final selection = NotifierProvider<_Selection, Server>(
        () => _Selection(a),
      );
      final container = containerFor(client, selection: selection);
      await container.read(dailyRecommendSongsProvider.future);
      final notifier = container.read(dailyRecommendSongsProvider.notifier);
      final old = notifier.shuffle();
      container.read(selection.notifier).select(b);
      await container.read(dailyRecommendSongsProvider.future);
      final fresh = notifier.shuffle();
      expect(client.requests, hasLength(2));
      client.requests[0].complete([_song('a-fresh')]);
      await old;
      expect(notifier.isShuffling, isTrue);
      await notifier.shuffle();
      expect(client.requests, hasLength(2));
      client.requests[1].complete([_song('b-fresh')]);
      await fresh;
      expect(
        container.read(dailyRecommendSongsProvider).value!.first.id,
        'b-fresh',
      );
      expect(await _ids(database, a.id), ['a-fresh']);
      expect(await _ids(database, b.id), ['b-fresh']);
    },
  );

  test(
    'old only-current response uses its original batch after a server switch',
    () async {
      final client = _Client();
      final selection = NotifierProvider<_Selection, Server>(
        () => _Selection(a),
      );
      final container = containerFor(client, selection: selection);
      await container.read(dailyRecommendSongsProvider.future);
      final old = container
          .read(dailyRecommendSongsProvider.notifier)
          .shuffle();
      container.read(selection.notifier).select(b);
      await container.read(dailyRecommendSongsProvider.future);
      client.requests.single.complete([_song('a-initial'), _song('a-initial')]);
      await old;
      expect(await _ids(database, a.id), ['a-initial']);
      expect(
        container.read(dailyRecommendSongsProvider).value!.first.id,
        'b-initial',
      );
    },
  );

  test('notifier recreation keeps persistence tickets monotonic', () async {
    final client = _Client();
    final oldContainer = containerFor(client);
    await oldContainer.read(dailyRecommendSongsProvider.future);
    for (var i = 0; i < 3; i++) {
      final shuffle = oldContainer
          .read(dailyRecommendSongsProvider.notifier)
          .shuffle();
      client.requests.last.complete([_song('old-$i')]);
      await shuffle;
    }
    final newContainer = containerFor(client);
    await newContainer.read(dailyRecommendSongsProvider.future);
    final fresh = newContainer
        .read(dailyRecommendSongsProvider.notifier)
        .shuffle();
    client.requests.last.complete([_song('new-instance')]);
    await fresh;
    expect(await _ids(database, a.id), ['new-instance']);
  });

  test(
    'late high-local-generation request cannot overwrite a newer instance',
    () async {
      final client = _Client();
      final oldContainer = containerFor(client);
      await oldContainer.read(dailyRecommendSongsProvider.future);
      for (var i = 0; i < 3; i++) {
        final shuffle = oldContainer
            .read(dailyRecommendSongsProvider.notifier)
            .shuffle();
        client.requests.last.complete([_song('old-$i')]);
        await shuffle;
      }
      final old = oldContainer
          .read(dailyRecommendSongsProvider.notifier)
          .shuffle();
      final oldResponse = client.requests.last;
      final newContainer = containerFor(client);
      await newContainer.read(dailyRecommendSongsProvider.future);
      final fresh = newContainer
          .read(dailyRecommendSongsProvider.notifier)
          .shuffle();
      client.requests.last.complete([_song('new-instance')]);
      await fresh;
      oldResponse.complete([_song('old-late')]);
      await old;
      expect(await _ids(database, a.id), ['new-instance']);
    },
  );

  test(
    'UI rechecks server lifecycle after an actual gated database write',
    () async {
      final client = _Client();
      final selection = NotifierProvider<_Selection, Server>(
        () => _Selection(a),
      );
      final container = containerFor(client, selection: selection);
      await container.read(dailyRecommendSongsProvider.future);
      database.gateWrite();
      final release = database.releaseWrite!;
      final shuffle = container
          .read(dailyRecommendSongsProvider.notifier)
          .shuffle();
      client.requests.single.complete([_song('a-fresh')]);
      await database.writeEntered!.future;
      expect(
        container.read(dailyRecommendSongsProvider).value!.first.id,
        'a-initial',
        reason: 'publish only after the cache write finishes',
      );
      container.read(selection.notifier).select(b);
      await container.read(dailyRecommendSongsProvider.future);
      release.complete();
      await shuffle;
      expect(
        container.read(dailyRecommendSongsProvider).value!.first.id,
        'b-initial',
      );
      expect(await _ids(database, a.id), ['a-fresh']);
    },
  );

  test(
    'replacing database during write keeps the new database UI and cache',
    () async {
      final replacement = AppDatabase(NativeDatabase.memory());
      addTearDown(replacement.close);
      await _seed(replacement, a.id, 'replacement');
      final selection = NotifierProvider<_DatabaseSelection, AppDatabase>(
        () => _DatabaseSelection(database),
      );
      final client = _Client();
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWith((ref) => ref.watch(selection)),
          activeServerProvider.overrideWithValue(a),
          activeSubsonicClientProvider.overrideWithValue(client),
        ],
      );
      addTearDown(container.dispose);
      await container.read(dailyRecommendSongsProvider.future);
      database.gateWrite();
      final release = database.releaseWrite!;
      final shuffle = container
          .read(dailyRecommendSongsProvider.notifier)
          .shuffle();
      client.requests.single.complete([_song('original-database-response')]);
      await database.writeEntered!.future;
      container.read(selection.notifier).select(replacement);
      expect(
        (await container.read(dailyRecommendSongsProvider.future)).single.id,
        'replacement',
      );
      release.complete();
      await shuffle;
      expect(
        container.read(dailyRecommendSongsProvider).value!.single.id,
        'replacement',
      );
      expect(await _ids(replacement, a.id), ['replacement']);
      expect(await _ids(database, a.id), ['original-database-response']);
    },
  );

  test(
    'disposal during database write retains the captured cache write',
    () async {
      final client = _Client();
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(database),
          activeServerProvider.overrideWithValue(a),
          activeSubsonicClientProvider.overrideWithValue(client),
        ],
      );
      await container.read(dailyRecommendSongsProvider.future);
      database.gateWrite();
      final release = database.releaseWrite!;
      final shuffle = container
          .read(dailyRecommendSongsProvider.notifier)
          .shuffle();
      client.requests.single.complete([_song('a-initial'), _song('a-fresh')]);
      await database.writeEntered!.future;
      container.dispose();
      release.complete();
      await expectLater(shuffle, completes);
      expect(await _ids(database, a.id), ['a-fresh', 'a-initial']);
    },
  );

  test(
    'cache read and baseline registration serialize against older-date writes',
    () async {
      const newerDate = '2030-10-19';
      await database.upsertDailyRecommend(a.id, newerDate, '[]');
      database.gateRead();
      final release = database.releaseRead!;
      final read = DailyRecommendCacheCoordinator.readCache(
        database: database,
        serverId: a.id,
        date: newerDate,
      );
      await database.readEntered!.future;
      final write = DailyRecommendCacheCoordinator.upsert(
        database: database,
        serverId: a.id,
        date: '2030-10-18',
        generation: 999,
        songsJson: '[]',
      );
      release.complete();
      await read;
      await write;
      expect(await database.getDailyRecommend(a.id, newerDate), isNotNull);
      expect(await database.getDailyRecommend(a.id, '2030-10-18'), isNull);
    },
  );

  test(
    'persisted newer date is protected even when requested date misses cache',
    () async {
      await database.upsertDailyRecommend(a.id, '2030-10-19', '[]');
      await DailyRecommendCacheCoordinator.readCache(
        database: database,
        serverId: a.id,
        date: '2030-10-18',
      );
      await DailyRecommendCacheCoordinator.upsert(
        database: database,
        serverId: a.id,
        date: '2030-10-18',
        generation: 999,
        songsJson: '[]',
      );
      expect(await database.getDailyRecommend(a.id, '2030-10-19'), isNotNull);
    },
  );

  test(
    'failed queued read and write do not poison subsequent writes',
    () async {
      database.failNextRead = true;
      await expectLater(
        DailyRecommendCacheCoordinator.readCache(
          database: database,
          serverId: a.id,
          date: _today,
        ),
        throwsStateError,
      );
      database.failNextWrite = true;
      await DailyRecommendCacheCoordinator.upsert(
        database: database,
        serverId: a.id,
        date: _today,
        generation: 1,
        songsJson: '[]',
      );
      await DailyRecommendCacheCoordinator.upsert(
        database: database,
        serverId: a.id,
        date: _today,
        generation: 2,
        songsJson: jsonEncode([_song('recovered').toJson()]),
      );
      expect(await _ids(database, a.id), ['recovered']);
    },
  );
}
