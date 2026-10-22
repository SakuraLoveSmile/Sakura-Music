import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramusic/data/db/app_database.dart';

void main() {
  for (final oldVersion in [15, 16]) {
    test(
      'v$oldVersion upgrades channel to stable and preserves existing user data',
      () async {
        final directory = await Directory.systemTemp.createTemp(
          'music-channel-migration-',
        );
        addTearDown(() => directory.delete(recursive: true));
        final file = File('${directory.path}/isolated.sqlite');
        final seeded = AppDatabase(NativeDatabase(file));
        await seeded.saveSettings(
          localeCode: 'en',
          themeMode: 'dark',
          seedColorValue: 0xff123456,
          safeAudioMode: false,
          equalizerEnabled: true,
          membershipActive: true,
          membershipMethod: 'code',
        );
        await seeded.insertServer(
          ServersCompanion.insert(
            name: 'Saved library',
            baseUrl: 'https://example.invalid',
            username: 'local-user',
            password: '',
          ),
        );
        await seeded
            .into(seeded.downloads)
            .insert(
              DownloadsCompanion.insert(
                songId: 'saved-song',
                serverId: 1,
                title: 'Saved download',
                filePath: '/isolated/not-a-real-file.mp3',
                status: const Value('completed'),
                bytes: const Value(123),
              ),
            );
        await seeded
            .into(seeded.playbackStates)
            .insert(
              PlaybackStatesCompanion.insert(
                serverId: const Value(1),
                queueJson: '["saved-song"]',
                currentIndex: 0,
                positionMs: 456,
              ),
            );
        await seeded.setWebDavLastPath(1, '/Saved%20folder/');

        // Reconstruct the on-disk shape from before the channel and the
        // floating-lyrics appearance were introduced.
        await seeded.customStatement(
          'ALTER TABLE settings DROP COLUMN update_channel',
        );
        await seeded.customStatement(
          'ALTER TABLE settings DROP COLUMN lyrics_overlay_config',
        );
        final expected = <String, List<Map<String, dynamic>>>{};
        for (final table in [
          'settings',
          'servers',
          'downloads',
          'playback_states',
        ]) {
          expected[table] =
              (await seeded.customSelect('SELECT * FROM $table').get())
                  .map((row) => row.data)
                  .toList();
        }
        if (oldVersion == 15) {
          await seeded.customStatement('DROP TABLE web_dav_paths');
        }
        await seeded.customStatement('PRAGMA user_version = $oldVersion');
        await seeded.close();

        final upgraded = AppDatabase(NativeDatabase(file));
        addTearDown(upgraded.close);
        expect((await upgraded.getSettings())!.updateChannel, 'stable');
        for (final entry in expected.entries) {
          final actual =
              (await upgraded.customSelect('SELECT * FROM ${entry.key}').get())
                  .map(
                    (row) => Map<String, dynamic>.from(row.data)
                      ..remove('update_channel')
                      ..remove('lyrics_overlay_config'),
                  )
                  .toList();
          expect(
            actual,
            entry.value,
            reason: '${entry.key} must survive migration',
          );
        }
        expect(
          await upgraded.getWebDavLastPath(1),
          oldVersion == 15 ? '' : '/Saved%20folder/',
        );
        expect(
          (await upgraded.customSelect('PRAGMA user_version').getSingle())
              .read<int>('user_version'),
          18,
        );
      },
    );
  }

  test('pre-settings database creates the channel once during upgrade', () async {
    final directory = await Directory.systemTemp.createTemp(
      'music-channel-v3-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/isolated.sqlite');
    final seeded = AppDatabase(NativeDatabase(file));
    // V3 already had servers, playback states, search history and recent plays.
    for (final table in [
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
    expect((await upgraded.getSettings())!.updateChannel, 'stable');
    final columns = await upgraded
        .customSelect('PRAGMA table_info(settings)')
        .get();
    expect(
      columns.where((row) => row.read<String>('name') == 'update_channel'),
      hasLength(1),
    );
  });
}
