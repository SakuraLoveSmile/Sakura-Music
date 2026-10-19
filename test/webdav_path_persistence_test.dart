import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramusic/data/db/app_database.dart';

/// Data-layer coverage for the WebDAV "last browsed folder" memory.
///
/// The browse screen reads this value on mount and writes it on every
/// navigation, so the row must round-trip exactly (percent-encoded hrefs are
/// stored verbatim), overwrite in place, stay per-server, and disappear when a
/// server is removed. The last test proves the V16 schema upgrade really
/// creates the table on a database written by V15.
void main() {
  group('WebDAV last-path persistence', () {
    late AppDatabase database;

    setUp(() {
      database = AppDatabase(NativeDatabase.memory());
    });

    tearDown(() => database.close());

    test('schema version is 17 and the table is created', () async {
      expect(database.schemaVersion, 17);
      expect(await database.select(database.webDavPaths).get(), isEmpty);
    });

    test('round-trips a percent-encoded path per server', () async {
      // Unknown server: root, never an error.
      expect(await database.getWebDavLastPath(1), '');
      expect(await database.getWebDavLastPath(2), '');

      await database.setWebDavLastPath(1, '/Backup/%E9%9F/');
      expect(await database.getWebDavLastPath(1), '/Backup/%E9%9F/');

      // The path is stored verbatim, including a fully encoded folder name and
      // the trailing slash the WebDAV listing uses for collections.
      await database.setWebDavLastPath(1, '/Backup/%E9%9F%B3%E4%B9%90/');
      expect(
        await database.getWebDavLastPath(1),
        '/Backup/%E9%9F%B3%E4%B9%90/',
      );

      // Another server keeps its own memory.
      await database.setWebDavLastPath(2, '/Music/');
      expect(await database.getWebDavLastPath(2), '/Music/');
      expect(
        await database.getWebDavLastPath(1),
        '/Backup/%E9%9F%B3%E4%B9%90/',
      );
    });

    test('repeated sets overwrite the single per-server row', () async {
      await database.setWebDavLastPath(1, '/Backup/%E9%9F/');
      await database.setWebDavLastPath(1, '/Backup/%E9%9F%B3%E4%B9%90/');
      await database.setWebDavLastPath(1, '');

      final rows = await database.select(database.webDavPaths).get();
      expect(rows, hasLength(1));
      expect(rows.single.serverId, 1);
      expect(rows.single.lastPath, '');
      expect(await database.getWebDavLastPath(1), '');

      // Back to a folder after the root: the row is reused, not duplicated.
      final beforeOverwrite =
          (await database.select(database.webDavPaths).get()).single.updatedAt;
      await database.setWebDavLastPath(1, '/Backup/%E9%9F/');
      final reused = await database.select(database.webDavPaths).get();
      expect(reused, hasLength(1));
      expect(reused.single.lastPath, '/Backup/%E9%9F/');
      expect(reused.single.updatedAt.isBefore(beforeOverwrite), isFalse);
    });

    test('clearServerData cascades to the stored path', () async {
      await database.setWebDavLastPath(1, '/Backup/%E9%9F/');
      await database.setWebDavLastPath(2, '/Music/');

      await database.clearServerData(1);

      expect(await database.getWebDavLastPath(1), '');
      expect(await database.select(database.webDavPaths).get(), hasLength(1));
      // The unrelated server keeps its memory.
      expect(await database.getWebDavLastPath(2), '/Music/');
    });

    test('the V16 upgrade creates the table on a V15 database', () async {
      final directory = Directory.systemTemp.createTempSync(
        'sakuramusic-webdav-path',
      );
      addTearDown(() {
        if (directory.existsSync()) {
          directory.deleteSync(recursive: true);
        }
      });
      final file = File('${directory.path}/app.sqlite');

      // Open the current schema, then rewind to the shape a V15 build left:
      // neither the path table nor the channel column exists yet.
      final seeded = AppDatabase(NativeDatabase(file));
      await seeded.customStatement(
        'ALTER TABLE settings DROP COLUMN update_channel',
      );
      await seeded.customStatement(
        'DROP TABLE ${seeded.webDavPaths.actualTableName}',
      );
      await seeded.customStatement('PRAGMA user_version = 15');
      await seeded.close();

      final upgraded = AppDatabase(NativeDatabase(file));
      addTearDown(upgraded.close);

      // The migration must have (re)created the table: reading an unknown
      // server returns root and a write round-trips.
      expect(await upgraded.getWebDavLastPath(7), '');
      await upgraded.setWebDavLastPath(7, '/Backup/%E9%9F/');
      expect(await upgraded.getWebDavLastPath(7), '/Backup/%E9%9F/');
    });
  });
}
