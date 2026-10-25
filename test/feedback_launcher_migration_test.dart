import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramusic/data/db/app_database.dart';

/// Appearance blob written while seeding; the migration must keep it as-is.
const _seededOverlayConfig =
    '{"fontScale":1.2,"textColor":4294967295,"backgroundOpacity":184,'
    '"cornerRadiusDp":18.0,"showNextLine":true,"showCloseButton":true,'
    '"position":"top"}';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp(
      'feedback-launcher-migration',
    );
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test(
    'v18 database gains the feedback orb column with matching defaults',
    () async {
      final file = File('${tempDir.path}/v18.sqlite');
      final seeded = AppDatabase(NativeDatabase(file));
      await seeded.saveSettings(
        themeMode: 'dark',
        seedColorValue: 0xff123456,
        equalizerEnabled: true,
        equalizerGainsJson: '[1,2,3,4,5]',
        equalizerPreset: 'rock',
        listenBrainzToken: 'seeded-token',
        listenBrainzEnabled: true,
        lyricsOverlayEnabled: true,
        statusBarLyricsEnabled: true,
        lyricsOverlayConfig: _seededOverlayConfig,
        safeAudioMode: false,
        localeCode: 'en',
        membershipActive: true,
        membershipMethod: 'code',
        updateChannel: 'prerelease',
      );
      // Reconstruct the on-disk shape from before the feedback orb existed.
      await seeded.customStatement(
        'ALTER TABLE settings DROP COLUMN feedback_launcher_enabled',
      );
      await seeded.customStatement('PRAGMA user_version = 18');
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
      // Upgraded installs keep the orb, matching the column default.
      expect(row!.feedbackLauncherEnabled, isTrue);
      // Existing user data survives the migration untouched.
      const reason = 'the migration must not rewrite unrelated settings';
      expect(row.themeMode, 'dark', reason: reason);
      expect(row.seedColorValue, 0xff123456, reason: reason);
      expect(row.equalizerEnabled, isTrue, reason: reason);
      expect(row.equalizerGainsJson, '[1,2,3,4,5]', reason: reason);
      expect(row.equalizerPreset, 'rock', reason: reason);
      expect(row.listenBrainzToken, 'seeded-token', reason: reason);
      expect(row.listenBrainzEnabled, isTrue, reason: reason);
      expect(row.lyricsOverlayEnabled, isTrue, reason: reason);
      expect(row.statusBarLyricsEnabled, isTrue, reason: reason);
      expect(row.lyricsOverlayConfig, _seededOverlayConfig, reason: reason);
      expect(row.safeAudioMode, isFalse, reason: reason);
      expect(row.localeCode, 'en', reason: reason);
      expect(row.membershipActive, isTrue, reason: reason);
      expect(row.membershipMethod, 'code', reason: reason);
      expect(row.updateChannel, 'prerelease', reason: reason);

      // The stored row must stay identical apart from the added column.
      expect(expected, hasLength(1));
      final actual =
          (await upgraded.customSelect('SELECT * FROM settings').get())
              .map(
                (snapshot) =>
                    Map<String, dynamic>.from(snapshot.data)
                      ..remove('feedback_launcher_enabled'),
              )
              .toList();
      expect(
        actual,
        expected,
        reason: 'the migration must not rewrite unrelated settings',
      );

      final columns = await upgraded
          .customSelect('PRAGMA table_info(settings)')
          .get();
      final added = columns.where(
        (column) => column.read<String>('name') == 'feedback_launcher_enabled',
      );
      expect(added, hasLength(1));
      // drift renders `Constant(true)` as `DEFAULT 1` for SQLite.
      expect(
        '${added.single.data['dflt_value']}'.trim(),
        '1',
        reason: 'the default must keep the orb visible after the upgrade',
      );
      expect(
        (await upgraded.customSelect('PRAGMA user_version').getSingle())
            .read<int>('user_version'),
        19,
      );
    },
  );

  test(
    'a disabled feedback orb survives a restart instead of being reset',
    () async {
      final file = File('${tempDir.path}/roundtrip.sqlite');
      final seeded = AppDatabase(NativeDatabase(file));
      // The column default is true; an explicit opt-out has to be stored.
      await seeded.saveSettings(feedbackLauncherEnabled: false);
      await seeded.close();

      final reopened = AppDatabase(NativeDatabase(file));
      addTearDown(reopened.close);
      final row = await reopened.getSettings();
      expect(row, isNotNull);
      expect(row!.feedbackLauncherEnabled, isFalse);
      expect(reopened.schemaVersion, 19);
    },
  );
}
