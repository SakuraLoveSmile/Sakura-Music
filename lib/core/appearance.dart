import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/settings_repository.dart';

const defaultSeedColorValue = 0xff1e7bf6;

class AppAppearance {
  const AppAppearance({
    this.themeMode = ThemeMode.system,
    this.seedColorValue = defaultSeedColorValue,
  });

  final ThemeMode themeMode;
  final int seedColorValue;

  AppAppearance copyWith({ThemeMode? themeMode, int? seedColorValue}) {
    return AppAppearance(
      themeMode: themeMode ?? this.themeMode,
      seedColorValue: seedColorValue ?? this.seedColorValue,
    );
  }
}

class AppearanceNotifier extends AsyncNotifier<AppAppearance> {
  @override
  Future<AppAppearance> build() async {
    final row = await ref.watch(settingsRepositoryProvider).read();
    return AppAppearance(
      themeMode: _themeModeFromString(row?.themeMode),
      seedColorValue: row?.seedColorValue ?? defaultSeedColorValue,
    );
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    await _save(
      (state.value ?? const AppAppearance()).copyWith(themeMode: mode),
    );
  }

  Future<void> setSeedColor(int value) async {
    await _save(
      (state.value ?? const AppAppearance()).copyWith(seedColorValue: value),
    );
  }

  Future<void> _save(AppAppearance next) async {
    final previous = state.value ?? const AppAppearance();
    state = AsyncData(next);
    try {
      await ref
          .read(settingsRepositoryProvider)
          .updateAppearance(
            themeMode: next.themeMode.name,
            seedColorValue: next.seedColorValue,
          );
    } catch (error, stackTrace) {
      state = AsyncData(previous);
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  static ThemeMode _themeModeFromString(String? value) {
    return switch (value) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }
}

final appearanceProvider =
    AsyncNotifierProvider<AppearanceNotifier, AppAppearance>(
      AppearanceNotifier.new,
    );
