import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramusic/core/update/update_channel.dart';
import 'package:sakuramusic/core/update/update_models.dart';
import 'package:sakuramusic/data/db/app_database.dart';
import 'package:sakuramusic/data/server_repository.dart';
import 'package:sakuramusic/data/settings_repository.dart';

class _GatedSettingsRepository extends SettingsRepository {
  _GatedSettingsRepository(super.database);

  Completer<void>? saveGate;
  bool failSave = false;

  @override
  Future<void> updateUpdateChannel({required String updateChannel}) async {
    await saveGate?.future;
    if (failSave) throw StateError('isolated write failure');
    await super.updateUpdateChannel(updateChannel: updateChannel);
  }
}

void main() {
  late AppDatabase database;
  late _GatedSettingsRepository repository;
  late ProviderContainer container;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    repository = _GatedSettingsRepository(database);
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(database),
        settingsRepositoryProvider.overrideWithValue(repository),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await database.close();
  });

  test(
    'new users start stable and saved channel survives provider recreation',
    () async {
      expect(
        await container.read(updateChannelProvider.future),
        UpdateChannel.stable,
      );
      await database.saveSettings(localeCode: 'en', membershipActive: true);
      await container
          .read(updateChannelProvider.notifier)
          .setChannel(UpdateChannel.prerelease);
      expect((await database.getSettings())!.updateChannel, 'prerelease');
      container.invalidate(updateChannelProvider);
      expect(
        await container.read(updateChannelProvider.future),
        UpdateChannel.prerelease,
      );
      final row = (await database.getSettings())!;
      expect(row.localeCode, 'en');
      expect(row.membershipActive, isTrue);
      await repository.updateLocale(localeCode: 'zh');
      expect((await database.getSettings())!.updateChannel, 'prerelease');
    },
  );

  test(
    'selection only changes after durable save and write failure keeps old selection',
    () async {
      await container.read(updateChannelProvider.future);
      repository.saveGate = Completer<void>();
      final save = container
          .read(updateChannelProvider.notifier)
          .setChannel(UpdateChannel.prerelease);
      await Future<void>.delayed(Duration.zero);
      expect(container.read(updateChannelProvider).isLoading, isTrue);
      expect(container.read(updateChannelProvider).value, UpdateChannel.stable);
      var resolvedDuringSave = false;
      final pendingPreference = container
          .read(updateChannelProvider.future)
          .then((value) {
            resolvedDuringSave = true;
            return value;
          });
      await Future<void>.delayed(Duration.zero);
      expect(resolvedDuringSave, isFalse);
      expect(await database.getSettings(), isNull);
      repository.saveGate!.complete();
      await save;
      expect(await pendingPreference, UpdateChannel.prerelease);
      expect(
        container.read(updateChannelProvider).value,
        UpdateChannel.prerelease,
      );
      repository.failSave = true;
      await expectLater(
        container
            .read(updateChannelProvider.notifier)
            .setChannel(UpdateChannel.stable),
        throwsStateError,
      );
      expect(container.read(updateChannelProvider).isLoading, isFalse);
      expect(
        container.read(updateChannelProvider).value,
        UpdateChannel.prerelease,
      );
      expect((await database.getSettings())!.updateChannel, 'prerelease');
    },
  );

  test(
    'unknown stored values default to stable without rewriting other preferences',
    () async {
      await database.saveSettings(
        updateChannel: 'future-channel',
        localeCode: 'en',
      );
      expect(
        await container.read(updateChannelProvider.future),
        UpdateChannel.stable,
      );
      expect((await database.getSettings())!.localeCode, 'en');
    },
  );
}
