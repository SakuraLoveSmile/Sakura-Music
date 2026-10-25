import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramusic/data/db/app_database.dart';
import 'package:sakuramusic/data/db/tables.dart';
import 'package:sakuramusic/features/lyrics_overlay/lyrics_overlay_config.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('lyrics-config-migration');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test(
    'v17 database gains the appearance column with matching defaults',
    () async {
      final file = File('${tempDir.path}/v17.sqlite');
      final seeded = AppDatabase(NativeDatabase(file));
      await seeded.saveSettings(
        localeCode: 'en',
        themeMode: 'dark',
        lyricsOverlayEnabled: true,
      );
      // Reconstruct the on-disk shape from before the appearance column existed.
      await seeded.customStatement(
        'ALTER TABLE settings DROP COLUMN lyrics_overlay_config',
      );
      await seeded.customStatement(
        'ALTER TABLE settings DROP COLUMN feedback_launcher_enabled',
      );
      await seeded.customStatement('PRAGMA user_version = 17');
      final expected =
          (await seeded.customSelect('SELECT * FROM settings').get())
              .map((row) => Map<String, dynamic>.from(row.data))
              .toList();
      await seeded.close();

      final upgraded = AppDatabase(NativeDatabase(file));
      addTearDown(upgraded.close);

      expect(upgraded.schemaVersion, 19);
      final row = await upgraded.getSettings();
      expect(row, isNotNull);
      expect(row!.lyricsOverlayConfig, lyricsOverlayConfigDefaultsJson);
      expect(
        LyricsOverlayConfig.decode(row.lyricsOverlayConfig),
        LyricsOverlayConfig.defaults(),
      );
      // Existing user data survives the migration untouched.
      expect(row.localeCode, 'en');
      expect(row.themeMode, 'dark');
      expect(row.lyricsOverlayEnabled, isTrue);
      expect(
        expected.single['theme_mode'],
        row.themeMode,
        reason: 'the migration must not rewrite unrelated settings',
      );
      expect(
        (await upgraded.customSelect('PRAGMA user_version').getSingle())
            .read<int>('user_version'),
        19,
      );
    },
  );

  test(
    'pre-settings database creates the column once during upgrade',
    () async {
      final file = File('${tempDir.path}/v3.sqlite');
      final seeded = AppDatabase(NativeDatabase(file));
      for (final table in <String>[
        'settings',
        'downloads',
        'cached_albums',
        'cached_artists',
        'daily_recommends',
        'web_dav_paths',
      ]) {
        await seeded.customStatement('DROP TABLE $table');
      }
      await seeded.customStatement('ALTER TABLE servers DROP COLUMN type');
      await seeded.customStatement('PRAGMA user_version = 3');
      await seeded.close();

      final upgraded = AppDatabase(NativeDatabase(file));
      addTearDown(upgraded.close);
      await upgraded.saveSettings(localeCode: 'en');
      final row = await upgraded.getSettings();
      expect(row!.lyricsOverlayConfig, lyricsOverlayConfigDefaultsJson);

      final columns = await upgraded
          .customSelect('PRAGMA table_info(settings)')
          .get();
      expect(
        columns.where(
          (row) => row.read<String>('name') == 'lyrics_overlay_config',
        ),
        hasLength(1),
      );
      expect(
        (await upgraded.customSelect('PRAGMA user_version').getSingle())
            .read<int>('user_version'),
        19,
      );
    },
  );

  test(
    'a stored appearance survives a restart instead of being reset',
    () async {
      final file = File('${tempDir.path}/roundtrip.sqlite');
      final seeded = AppDatabase(NativeDatabase(file));
      const custom = LyricsOverlayConfig(
        fontScale: 1.4,
        textColor: 0xFF9BE7FF,
        backgroundOpacity: 40,
        cornerRadiusDp: 4,
        showNextLine: false,
        showCloseButton: false,
        position: LyricsOverlayPosition.bottom,
      );
      await seeded.saveSettings(lyricsOverlayConfig: custom.encode());
      await seeded.close();

      final reopened = AppDatabase(NativeDatabase(file));
      addTearDown(reopened.close);
      final row = await reopened.getSettings();
      expect(LyricsOverlayConfig.decode(row?.lyricsOverlayConfig), custom);
    },
  );
}
