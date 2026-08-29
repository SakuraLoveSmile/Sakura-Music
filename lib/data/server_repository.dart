import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../core/security/credential_store.dart';
import 'db/app_database.dart';

class ServerRepository {
  const ServerRepository(this.database, this.credentials);

  final AppDatabase database;
  final CredentialStore credentials;

  Stream<List<Server>> watchServers() => database.watchAllServers();

  Future<Server?> getServer(int id) => database.getServer(id);

  /// Creates a server row and stores its password in the platform secure
  /// storage. The database row keeps an empty password column.
  Future<int> addServer({
    required String name,
    required String baseUrl,
    required String username,
    required String password,
    String? type,
  }) async {
    final id = await database.insertServer(
      ServersCompanion.insert(
        name: name,
        baseUrl: baseUrl,
        username: username,
        password: '',
        type: Value(type),
      ),
    );
    await credentials.writeServerPassword(id, password);
    return id;
  }

  /// Updates the server row and rotates the credential in secure storage.
  Future<bool> updateServer({
    required int id,
    required String name,
    required String baseUrl,
    required String username,
    required String password,
    String? type,
  }) async {
    final updated = await database.updateServer(
      id,
      ServersCompanion(
        name: Value(name),
        baseUrl: Value(baseUrl),
        username: Value(username),
        password: const Value(''),
        type: Value(type),
      ),
    );
    if (!updated) {
      return false;
    }
    await credentials.writeServerPassword(id, password);
    return true;
  }

  Future<int> deleteServer(int id) => database.deleteServer(id);

  /// Full teardown when the user removes a server: the row, its credential in
  /// secure storage, the per-server caches and the saved playback state.
  /// Download records and their files are intentionally kept — deleting those
  /// is a separate, explicit user decision.
  Future<void> deleteServerCascade(int id) async {
    await deleteServer(id);
    await credentials.deleteServerPassword(id);
    await database.clearServerData(id);
  }

  Future<int> recordPlay({required String songId, required int serverId}) {
    return database.addRecentPlay(songId: songId, serverId: serverId);
  }
}

final credentialStoreProvider = Provider<CredentialStore>((ref) {
  return SecureCredentialStore();
});

final databaseProvider = Provider<AppDatabase>((ref) {
  final database = AppDatabase();
  ref.onDispose(database.close);
  return database;
});

final serverRepositoryProvider = Provider<ServerRepository>((ref) {
  return ServerRepository(
    ref.watch(databaseProvider),
    ref.watch(credentialStoreProvider),
  );
});

final serversProvider = StreamProvider<List<Server>>((ref) {
  return ref.watch(serverRepositoryProvider).watchServers();
});

final selectedServerIdProvider = StateProvider<int?>((ref) => null);

final activeServerProvider = Provider<Server?>((ref) {
  final servers = ref.watch(serversProvider).value ?? const <Server>[];
  final selectedId = ref.watch(selectedServerIdProvider);
  if (selectedId != null) {
    for (final server in servers) {
      if (server.id == selectedId) {
        return server;
      }
    }
  }
  return servers.isEmpty ? null : servers.first;
});
