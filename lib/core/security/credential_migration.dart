import '../../data/db/app_database.dart';
import '../crash_report.dart';
import 'credential_store.dart';

/// Moves credentials that older builds stored in the plain database
/// (`Servers.password`, `Settings.listenBrainzToken`) into the platform
/// secure storage.
///
/// The migration is idempotent and interruption-safe:
///
/// * it never clears the database value before the secure write was
///   confirmed by reading it back, so a crash between the two steps leaves
///   both copies intact and the next start simply retries;
/// * a value already present in secure storage is kept — a database copy
///   from an earlier run never overwrites it.
///
/// When secure storage is unavailable (e.g. a desktop without a keyring
/// service) the failure is logged and the database values stay untouched, so
/// the app keeps working exactly like before.
class CredentialMigrator {
  const CredentialMigrator({required this.database, required this.store});

  final AppDatabase database;
  final CredentialStore store;

  Future<void> migrate() async {
    try {
      await _migrateServerPasswords();
      await _migrateListenBrainzToken();
    } catch (error, stack) {
      logCrash(error, stack, context: 'credentialMigration');
    }
  }

  Future<void> _migrateServerPasswords() async {
    final servers = await database.getAllServers();
    for (final server in servers) {
      if (server.password.isEmpty) {
        continue;
      }
      final existing = await store.readServerPassword(server.id);
      if (existing == null || existing.isEmpty) {
        await store.writeServerPassword(server.id, server.password);
      }
      final confirmed = await store.readServerPassword(server.id);
      if (confirmed != null && confirmed.isNotEmpty) {
        await database.updateServerPassword(server.id, '');
      }
    }
  }

  Future<void> _migrateListenBrainzToken() async {
    final settings = await database.getSettings();
    final token = settings?.listenBrainzToken;
    if (token == null || token.isEmpty) {
      return;
    }
    final existing = await store.readListenBrainzToken();
    if (existing == null || existing.isEmpty) {
      await store.writeListenBrainzToken(token);
    }
    final confirmed = await store.readListenBrainzToken();
    if (confirmed != null && confirmed.isNotEmpty) {
      await database.saveSettings(clearListenBrainzToken: true);
    }
  }
}
