import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'db/app_database.dart';
import 'server_repository.dart';

/// Small persistence boundary for user preferences. Keeping the Drift details
/// here lets feature providers remain focused on state and validation.
class SettingsRepository {
  const SettingsRepository(this.database);

  final AppDatabase database;

  Future<Setting?> read() => database.getSettings();

  Future<void> updateAppearance({
    required String themeMode,
    required int seedColorValue,
  }) {
    return database.saveSettings(
      themeMode: themeMode,
      seedColorValue: seedColorValue,
    );
  }

  Future<void> updateLyricsOverlay({required bool enabled}) {
    return database.saveSettings(lyricsOverlayEnabled: enabled);
  }

  Future<void> updateLocale({required String localeCode}) {
    return database.saveSettings(localeCode: localeCode);
  }
}

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return SettingsRepository(ref.watch(databaseProvider));
});
