import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramusic/core/security/credential_migration.dart';
import 'package:sakuramusic/core/security/credential_store.dart';
import 'package:sakuramusic/data/db/app_database.dart';
import 'package:sakuramusic/data/server_repository.dart';

/// In-memory stand-in for the platform keystore.
class _InMemoryCredentialStore implements CredentialStore {
  final Map<int, String> _passwords = <int, String>{};
  String? _listenBrainzToken;

  @override
  Future<String?> readServerPassword(int serverId) async =>
      _passwords[serverId];

  @override
  Future<void> writeServerPassword(int serverId, String password) async {
    _passwords[serverId] = password;
  }

  @override
  Future<void> deleteServerPassword(int serverId) async {
    _passwords.remove(serverId);
  }

  @override
  Future<String?> readListenBrainzToken() async => _listenBrainzToken;

  @override
  Future<void> writeListenBrainzToken(String? token) async {
    _listenBrainzToken = (token == null || token.isEmpty) ? null : token;
  }

  @override
  String? cachedServerPassword(int serverId) => _passwords[serverId];

  @override
  Future<void> warmUp(Iterable<int> serverIds) async {}
}

AppDatabase _memoryDb() => AppDatabase(NativeDatabase.memory());

void main() {
  group('CredentialMigrator', () {
    late AppDatabase database;
    late _InMemoryCredentialStore store;

    setUp(() {
      database = _memoryDb();
      store = _InMemoryCredentialStore();
    });

    tearDown(() async {
      await database.close();
    });

    test(
      'moves server passwords into the store and blanks the database',
      () async {
        final serverId = await database.insertServer(
          ServersCompanion.insert(
            name: 'Legacy',
            baseUrl: 'https://music.example.test',
            username: 'demo',
            password: 'plain-secret',
          ),
        );

        await CredentialMigrator(database: database, store: store).migrate();

        expect(await store.readServerPassword(serverId), 'plain-secret');
        expect((await database.getServer(serverId))!.password, isEmpty);
      },
    );

    test('is idempotent across repeated runs', () async {
      final serverId = await database.insertServer(
        ServersCompanion.insert(
          name: 'Legacy',
          baseUrl: 'https://music.example.test',
          username: 'demo',
          password: 'plain-secret',
        ),
      );
      final migrator = CredentialMigrator(database: database, store: store);

      await migrator.migrate();
      await migrator.migrate();
      await migrator.migrate();

      expect(await store.readServerPassword(serverId), 'plain-secret');
      expect((await database.getServer(serverId))!.password, isEmpty);
    });

    test(
      'a previously stored value survives an interrupted migration',
      () async {
        // Simulate a crash after the secure write but before the database was
        // cleared: the store already holds the (newer) credential while the
        // database still carries the stale plaintext.
        final serverId = await database.insertServer(
          ServersCompanion.insert(
            name: 'Legacy',
            baseUrl: 'https://music.example.test',
            username: 'demo',
            password: 'stale-db-copy',
          ),
        );
        await store.writeServerPassword(serverId, 'stored-on-first-run');

        await CredentialMigrator(database: database, store: store).migrate();

        // The database copy must never overwrite the stored credential.
        expect(await store.readServerPassword(serverId), 'stored-on-first-run');
        expect((await database.getServer(serverId))!.password, isEmpty);
      },
    );

    test('moves the ListenBrainz token into the store', () async {
      await database.saveSettings(listenBrainzToken: 'mb-token-123');

      await CredentialMigrator(database: database, store: store).migrate();

      expect(await store.readListenBrainzToken(), 'mb-token-123');
      expect((await database.getSettings())!.listenBrainzToken, isNull);

      // Idempotent: another run neither loses nor duplicates the token.
      await CredentialMigrator(database: database, store: store).migrate();
      expect(await store.readListenBrainzToken(), 'mb-token-123');
    });
  });

  group('deleteServerCascade', () {
    late AppDatabase database;
    late _InMemoryCredentialStore store;
    late ServerRepository repository;

    setUp(() {
      database = _memoryDb();
      store = _InMemoryCredentialStore();
      repository = ServerRepository(database, store);
    });

    tearDown(() async {
      await database.close();
    });

    test('removes the row, credential, caches and playback state but keeps '
        'downloads', () async {
      final serverId = await repository.addServer(
        name: 'Doomed',
        baseUrl: 'https://music.example.test',
        username: 'demo',
        password: 'secret',
      );
      await database.cacheAlbum(
        serverId: serverId,
        albumId: 'al-1',
        payload: '{}',
      );
      await database.cacheArtist(
        serverId: serverId,
        artistId: 'ar-1',
        payload: '{}',
      );
      await database.upsertDailyRecommend(serverId, '2026-08-29', '[]');
      await database.savePlaybackState(
        serverId: serverId,
        queueJson: '[]',
        currentIndex: 0,
        positionMs: 0,
        loopMode: 'off',
        shuffle: false,
        volume: 1,
        speed: 1,
      );
      await database.upsertDownload(
        songId: 'song-1',
        serverId: serverId,
        title: 'Downloaded song',
        artist: null,
        album: null,
        filePath: '/downloads/11/song-1.flac',
        coverArtId: null,
        ext: 'flac',
        status: 'completed',
      );

      await repository.deleteServerCascade(serverId);

      expect(await database.getServer(serverId), isNull);
      expect(await store.readServerPassword(serverId), isNull);
      expect(await database.getCachedAlbums(serverId), isEmpty);
      expect(await database.getCachedArtists(serverId), isEmpty);
      expect(await database.getDailyRecommend(serverId, '2026-08-29'), isNull);
      expect(await database.getPlaybackState(), isNull);
      // Download records (and their files) are intentionally preserved.
      expect(
        await database.getDownload('song-1', serverId: serverId),
        isNotNull,
      );
    });

    test('addServer stores an empty database password', () async {
      final serverId = await repository.addServer(
        name: 'New',
        baseUrl: 'https://music.example.test',
        username: 'demo',
        password: 'fresh-secret',
      );

      // New credentials never touch the plain database column.
      expect((await database.getServer(serverId))!.password, isEmpty);
      expect(await store.readServerPassword(serverId), 'fresh-secret');
      expect(store.cachedServerPassword(serverId), 'fresh-secret');
    });
  });
}
