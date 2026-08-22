import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/server_repository.dart';
import 'audio_player_provider.dart';
import 'equalizer_models.dart';

class EqualizerNotifier extends AsyncNotifier<EqualizerSettings> {
  @override
  Future<EqualizerSettings> build() async {
    final settings = EqualizerSettings.fromRow(
      await ref.watch(databaseProvider).getSettings(),
    );
    try {
      await ref.read(audioPlayerProvider).setEqualizer(settings);
    } catch (_) {
      // A platform effect may be unavailable; preferences remain usable.
    }
    return settings;
  }

  Future<void> setEnabled(bool enabled) async {
    await _save(
      (state.value ?? const EqualizerSettings()).copyWith(enabled: enabled),
    );
  }

  Future<void> setGain(int index, double gain) async {
    final current = state.value ?? const EqualizerSettings();
    final gains = [...current.gains];
    gains[index] = gain.clamp(-12, 12).toDouble();
    await _save(current.copyWith(gains: gains, preset: EqualizerPreset.flat));
  }

  Future<void> setPreset(EqualizerPreset preset) async {
    await _save(
      (state.value ?? const EqualizerSettings()).copyWith(
        gains: preset.gains,
        preset: preset,
      ),
    );
  }

  Future<void> _save(EqualizerSettings next) async {
    final previous = state.value ?? const EqualizerSettings();
    state = AsyncData(next);
    try {
      await ref
          .read(databaseProvider)
          .saveSettings(
            equalizerEnabled: next.enabled,
            equalizerGainsJson: jsonEncode(next.gains),
            equalizerPreset: next.preset.name,
          );
      await ref.read(audioPlayerProvider).setEqualizer(next);
    } catch (error, stackTrace) {
      state = AsyncData(previous);
      Error.throwWithStackTrace(error, stackTrace);
    }
  }
}

final equalizerProvider =
    AsyncNotifierProvider<EqualizerNotifier, EqualizerSettings>(
      EqualizerNotifier.new,
    );
