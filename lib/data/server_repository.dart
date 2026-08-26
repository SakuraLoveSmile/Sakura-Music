import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import 'db/app_database.dart';

class ServerRepository {
  const ServerRepository(this.database);

  final AppDatabase database;

  Stream<List<Server>> watchServers() => database.watchAllServers();

  Future<Server?> getServer(int id) => database.getServer(id);

  Future<int> addServer({
    required String name,
    required String baseUrl,
    required String username,
    required String password,
    String? type,
  }) {
    return database.insertServer(
      ServersCompanion.insert(
        name: name,
        baseUrl: baseUrl,
        username: username,
        password: password,
        type: Value(type),
      ),
    );
  }

  Future<bool> updateServer({
    required int id,
    required String name,
    required String baseUrl,
    required String username,
    required String password,
    String? type,
  }) {
    return database.updateServer(
      id,
      ServersCompanion(
        name: Value(name),
        baseUrl: Value(baseUrl),
        username: Value(username),
        password: Value(password),
        type: Value(type),
      ),
    );
  }

  Future<int> deleteServer(int id) => database.deleteServer(id);

  Future<int> recordPlay({required String songId, required int serverId}) {
    return database.addRecentPlay(songId: songId, serverId: serverId);
  }
}

final databaseProvider = Provider<AppDatabase>((ref) {
  final database = AppDatabase();
  ref.onDispose(database.close);
  return database;
});

final serverRepositoryProvider = Provider<ServerRepository>((ref) {
  return ServerRepository(ref.watch(databaseProvider));
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
