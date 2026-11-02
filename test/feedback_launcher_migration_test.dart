import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramusic/data/db/app_database.dart';

/// Appearance blob written while seeding; the migration must keep it as-is.
const _seededOverlayConfig =
    '{"fontScale":1.2,"textColor":4294967295,"backgroundOpacity":184,'
    '"cornerRadiusDp":18.0,"showNextLine":true,"showCloseButton":true,'
    '"position":"top"}';

Future<Map<String, Object?>> _seedFullRow(AppDatabase database) {
  return database.saveSettings(
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
  ).then((_) async => <String, Object?>{});
}

Future<List<Map<String, dynamic>>> _rows(AppDatabase database) async {
  return (await database.customSelect('SELECT * FROM settings').get())
      .map((row) => Map<String, dynamic>.from(row.data))
      .toList();
}

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp(
      'feedback-orb-migration',
    );
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test(
    'v18 database gains the orb style and gestures with matching defaults',
    () async {
      final file = File('${tempDir.path}/v18.sqlite');
      final seeded = AppDatabase(NativeDatabase(file));
      await _seedFullRow(seeded);
      // Reconstruct the on-disk shape from before the orb existed (v18): no
      // v19 switch and none of the v20 host-owned orb columns.
      for (final String column in <String>[
        'feedback_launcher_enabled',
        'feedback_orb_idle_style',
        'feedback_wake_gestures',
      ]) {
        await seeded.customStatement(
          'ALTER TABLE settings DROP COLUMN $column',
        );
      }
      await seeded.customStatement('PRAGMA user_version = 18');
      final expected = await _rows(seeded);
      await seeded.close();

      final upgraded = AppDatabase(NativeDatabase(file));
      addTearDown(upgraded.close);

      expect(upgraded.schemaVersion, 20);
      final row = await upgraded.getSettings();
      expect(row, isNotNull);
      // V19 default keeps the orb, and v20 maps a visible orb to `handle`.
      expect(row!.feedbackLauncherEnabled, isTrue);
      expect(row.feedbackOrbIdleStyle, 'handle');
      expect(row.feedbackWakeGestures, '[]');
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

      // The stored row must stay identical apart from the added columns.
      expect(expected, hasLength(1));
      final actual = (await _rows(upgraded))
          .map(
            (Map<String, dynamic> row) => row
              ..remove('feedback_launcher_enabled')
              ..remove('feedback_orb_idle_style')
              ..remove('feedback_wake_gestures'),
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
      final Map<String, String?> defaults = <String, String?>{
        for (final row in columns)
          row.read<String>('name'): row.read<String?>('dflt_value'),
      };
      // drift renders `Constant(...)` as SQL literals for SQLite.
      expect(defaults['feedback_orb_idle_style']?.trim(), "'handle'");
      expect(defaults['feedback_wake_gestures']?.trim(), "'[]'");
      expect(
        (await upgraded.customSelect('PRAGMA user_version').getSingle())
            .read<int>('user_version'),
        20,
      );
    },
  );

  test(
    'a hidden v19 orb upgrades to the hidden idle style and keeps its data',
    () async {
      final file = File('${tempDir.path}/v19-hidden.sqlite');
      final seeded = AppDatabase(NativeDatabase(file));
      await seeded.saveSettings(
        feedbackLauncherEnabled: false,
        localeCode: 'en',
        membershipActive: true,
      );
      // Reconstruct the v19 shape: the v20 columns do not exist yet.
      await seeded.customStatement(
        'ALTER TABLE settings DROP COLUMN feedback_orb_idle_style',
      );
      await seeded.customStatement(
        'ALTER TABLE settings DROP COLUMN feedback_wake_gestures',
      );
      await seeded.customStatement('PRAGMA user_version = 19');
      await seeded.close();

      final upgraded = AppDatabase(NativeDatabase(file));
      addTearDown(upgraded.close);

      final row = await upgraded.getSettings();
      expect(row, isNotNull);
      expect(row!.feedbackLauncherEnabled, isFalse);
      expect(
        row.feedbackOrbIdleStyle,
        'hidden',
        reason: 'the explicit opt-out must become the component hidden style',
      );
      expect(row.feedbackWakeGestures, '[]');
      expect(row.localeCode, 'en');
      expect(row.membershipActive, isTrue);
    },
  );

  test('orb style and wake gestures survive a restart', () async {
    final file = File('${tempDir.path}/roundtrip.sqlite');
    final seeded = AppDatabase(NativeDatabase(file));
    await seeded.saveSettings(
      feedbackOrbIdleStyle: 'edge',
      feedbackWakeGestures: '["three-finger-swipe-up"]',
    );
    await seeded.close();

    final reopened = AppDatabase(NativeDatabase(file));
    addTearDown(reopened.close);
    final row = await reopened.getSettings();
    expect(row, isNotNull);
    expect(row!.feedbackOrbIdleStyle, 'edge');
    expect(row.feedbackWakeGestures, '["three-finger-swipe-up"]');
    expect(reopened.schemaVersion, 20);
  });
}
