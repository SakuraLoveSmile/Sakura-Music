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

  Future<void> updateSafeAudioMode({required bool enabled}) {
    return database.saveSettings(safeAudioMode: enabled);
  }

  Future<void> updateLocale({required String localeCode}) {
    return database.saveSettings(localeCode: localeCode);
  }

  Future<void> updateMembership({
    required bool active,
    required String? method,
  }) {
    return database.saveSettings(
      membershipActive: active,
      membershipMethod: method,
      clearMembershipMethod: method == null,
    );
  }
}

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return SettingsRepository(ref.watch(databaseProvider));
});

typedef MembershipState = ({bool active, String? method});

const membershipActivationCode = 'sakurasep';

class MembershipController extends AsyncNotifier<MembershipState> {
  @override
  Future<MembershipState> build() async {
    final row = await ref.watch(settingsRepositoryProvider).read();
    return (
      active: row?.membershipActive ?? false,
      method: row?.membershipMethod,
    );
  }

  Future<bool> activateWithCode(String code) async {
    if (code.trim() != membershipActivationCode) {
      return false;
    }
    state = const AsyncData((active: true, method: 'code'));
    try {
      await ref.read(settingsRepositoryProvider).updateMembership(
        active: true,
        method: 'code',
      );
      return true;
    } catch (error, stackTrace) {
      ref.invalidateSelf();
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  Future<void> setStarActivation(bool enabled) async {
    final next = enabled
        ? (active: true, method: 'star')
        : (active: false, method: null);
    final previous = state.value ?? (active: false, method: null);
    state = AsyncData(next);
    try {
      await ref.read(settingsRepositoryProvider).updateMembership(
        active: next.active,
        method: next.method,
      );
    } catch (error, stackTrace) {
      state = AsyncData(previous);
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  Future<void> deactivate() async {
    const next = (active: false, method: null);
    final previous = state.value ?? (active: false, method: null);
    state = const AsyncData(next);
    try {
      await ref.read(settingsRepositoryProvider).updateMembership(
        active: false,
        method: null,
      );
    } catch (error, stackTrace) {
      state = AsyncData(previous);
      Error.throwWithStackTrace(error, stackTrace);
    }
  }
}

final membershipControllerProvider =
    AsyncNotifierProvider<MembershipController, MembershipState>(
      MembershipController.new,
    );

