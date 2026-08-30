import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramusic/core/providers.dart';
import 'package:sakuramusic/core/security/credential_migration.dart';
import 'package:sakuramusic/core/security/credential_store.dart';
import 'package:sakuramusic/data/db/app_database.dart';
import 'package:sakuramusic/data/server_repository.dart';
import 'package:sakuramusic/features/home/home_screen.dart';
import 'package:sakuramusic/features/shared/media_widgets.dart';
import 'package:sakuramusic/l10n/app_localizations.dart';

/// Regression coverage for the alpha.9 Android breakage.
///
/// alpha.9 migrated passwords into the platform secure storage but then let
/// the ProviderScope build a SECOND credential store with a cold cache, so
/// `cachedServerPassword` returned null, the active Subsonic client became
/// null and HomeScreen crashed on a null assertion ("界面渲染出错").
///
/// These tests pin the fixed contract: the store warmed during bootstrap is
/// the same instance the providers see, and a missing credential degrades to
/// a readable UI state instead of an exception.
void main() {
  AppDatabase memoryDb() => AppDatabase(NativeDatabase.memory());

  Future<int> insertServer(
    AppDatabase database, {
    String password = '',
  }) {
    return database.insertServer(
      ServersCompanion.insert(
        name: 'Navidrome',
        baseUrl: 'http://music.example.test:4533',
        username: 'listener',
        password: password,
      ),
    );
  }

  /// Builds a container whose server list is a resolved snapshot, so the
  /// credential chain under test is exercised synchronously (the drift watch
  /// stream itself is not what these tests are about).
  ProviderContainer containerFor(
    AppDatabase database,
    CredentialStore store,
    List<Server> servers,
  ) {
    return ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(database),
        credentialStoreProvider.overrideWithValue(store),
        serversProvider.overrideWithValue(AsyncValue.data(servers)),
      ],
    );
  }

  test('credentialStoreProvider fails loudly without the bootstrap override',
      () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    // Riverpod wraps provider build errors in its own exception type; the
    // contract under test is that an un-overridden read never silently
    // constructs a second store — it must throw.
    expect(
      () => container.read(credentialStoreProvider),
      throwsA(anything),
    );
  });

  test(
      'legacy plaintext database password migrates and the bootstrap store '
      'serves a working client (alpha8 -> alpha10)', () async {
    final database = memoryDb();
    addTearDown(database.close);
    final serverId = await insertServer(
      database,
      password: 'legacy-plain-secret',
    );

    // Bootstrap: migrate and warm up the SAME store handed to ProviderScope.
    final bootstrapStore = _FakeCredentialStore(_FakeKeystore());
    await CredentialMigrator(database: database, store: bootstrapStore)
        .migrate();
    await bootstrapStore.warmUp([serverId]);

    // The plaintext column is cleared only after the store holds the secret.
    expect((await database.getServer(serverId))!.password, isEmpty);
    expect(await bootstrapStore.readServerPassword(serverId), isNotEmpty);

    final server = (await database.getServer(serverId))!;
    final container = containerFor(database, bootstrapStore, [server]);
    addTearDown(container.dispose);

    expect(container.read(activeServerConnectionProvider), isNotNull);
    expect(container.read(activeSubsonicClientProvider), isNotNull);
  });

  test(
      'restart with alpha.9-migrated data: a fresh store warms up from '
      'secure storage and the client resolves (the alpha.9 regression)',
      () async {
    final database = memoryDb();
    addTearDown(database.close);
    final keystore = _FakeKeystore();

    // Session 1: the user adds a server; the row keeps an empty password
    // column and the secret lives only in secure storage — exactly the state
    // an alpha.9 device is left in.
    final sessionStore = _FakeCredentialStore(keystore);
    final repository = ServerRepository(database, sessionStore);
    final serverId = await repository.addServer(
      name: 'Navidrome',
      baseUrl: 'http://music.example.test:4533',
      username: 'listener',
      password: 'restart-secret',
    );
    expect((await database.getServer(serverId))!.password, isEmpty);

    // The process dies; only the database and secure storage survive.
    // Session 2: a brand-new store instance with a cold cache.
    final restartedStore = _FakeCredentialStore(keystore);
    expect(
      restartedStore.cachedServerPassword(serverId),
      isNull,
      reason: 'a fresh store must start with a cold cache',
    );

    // Startup warms the cache BEFORE any provider can build a client.
    await restartedStore.warmUp([serverId]);
    expect(restartedStore.cachedServerPassword(serverId), 'restart-secret');

    final server = (await database.getServer(serverId))!;
    final container = containerFor(database, restartedStore, [server]);
    addTearDown(container.dispose);

    expect(container.read(activeServerConnectionProvider), isNotNull);
    expect(container.read(activeSubsonicClientProvider), isNotNull);
  });

  test(
      'a cold store that never warms up yields a null client '
      '(the alpha.9 bug shape)', () async {
    final database = memoryDb();
    addTearDown(database.close);
    final serverId = await insertServer(database);
    final keystore = _FakeKeystore();
    keystore.values['sakuramusic.server.password.$serverId'] =
        'never-warmed-secret';

    // No warmUp — mirrors a second, unwarmed store instance.
    final coldStore = _FakeCredentialStore(keystore);
    final server = (await database.getServer(serverId))!;
    final container = containerFor(database, coldStore, [server]);
    addTearDown(container.dispose);

    expect(container.read(activeServerConnectionProvider), isNull);
    expect(container.read(activeSubsonicClientProvider), isNull);
  });

  testWidgets(
      'truly missing credentials render an unavailable state, never a '
      'render error', (tester) async {
    final database = memoryDb();
    addTearDown(database.close);
    final serverId = await insertServer(database);

    // Nothing in secure storage and nothing in the database.
    final store = _FakeCredentialStore(_FakeKeystore());
    await store.warmUp([serverId]);

    final server = (await database.getServer(serverId))!;
    final container = containerFor(database, store, [server]);
    addTearDown(container.dispose);

    expect(container.read(activeServerConnectionProvider), isNull);
    expect(container.read(activeSubsonicClientProvider), isNull);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('zh'),
          home: const Scaffold(body: HomeScreen()),
        ),
      ),
    );
    await tester.pump();

    // Building HomeScreen must not throw and must not hit the framework
    // ErrorWidget; it shows the dedicated credential state instead.
    expect(tester.takeException(), isNull);
    expect(find.byType(ServerCredentialUnavailableView), findsOneWidget);
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.text('服务器凭据不可用'), findsOneWidget);
  });
}

/// Persistent backing storage shared by every [_FakeCredentialStore].
class _FakeKeystore {
  final Map<String, String> values = <String, String>{};
}

/// Mirrors [SecureCredentialStore]: an in-memory mirror warmed at startup in
/// front of the persistent keystore. Each instance has its own cache but they
/// share the same disk, so discarding one and creating another simulates a
/// full process restart.
class _FakeCredentialStore implements CredentialStore {
  _FakeCredentialStore(this._disk);

  static const _serverKeyPrefix = 'sakuramusic.server.password.';

  final _FakeKeystore _disk;
  final Map<int, String?> _cache = <int, String?>{};

  @override
  Future<String?> readServerPassword(int serverId) async {
    if (_cache.containsKey(serverId)) {
      return _cache[serverId];
    }
    final value = _disk.values['$_serverKeyPrefix$serverId'];
    _cache[serverId] = value;
    return value;
  }

  @override
  Future<void> writeServerPassword(int serverId, String password) async {
    _disk.values['$_serverKeyPrefix$serverId'] = password;
    _cache[serverId] = password;
  }

  @override
  Future<void> deleteServerPassword(int serverId) async {
    _disk.values.remove('$_serverKeyPrefix$serverId');
    _cache[serverId] = null;
  }

  @override
  Future<String?> readListenBrainzToken() async =>
      _disk.values['sakuramusic.listenbrainz.token'];

  @override
  Future<void> writeListenBrainzToken(String? token) async {
    const key = 'sakuramusic.listenbrainz.token';
    if (token == null || token.isEmpty) {
      _disk.values.remove(key);
    } else {
      _disk.values[key] = token;
    }
  }

  @override
  String? cachedServerPassword(int serverId) => _cache[serverId];

  @override
  Future<void> warmUp(Iterable<int> serverIds) async {
    for (final serverId in serverIds) {
      await readServerPassword(serverId);
    }
  }
}
