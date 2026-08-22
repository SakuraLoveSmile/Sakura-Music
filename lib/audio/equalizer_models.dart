import 'dart:convert';

import '../data/db/app_database.dart';

const equalizerFrequencies = <double>[60, 230, 910, 3600, 14000];

enum EqualizerPreset { flat, pop, rock, classical, vocal }

extension EqualizerPresetLabel on EqualizerPreset {
  String get label => switch (this) {
    EqualizerPreset.flat => '平直',
    EqualizerPreset.pop => '流行',
    EqualizerPreset.rock => '摇滚',
    EqualizerPreset.classical => '古典',
    EqualizerPreset.vocal => '人声',
  };

  List<double> get gains => switch (this) {
    EqualizerPreset.flat => const <double>[0, 0, 0, 0, 0],
    EqualizerPreset.pop => const <double>[3, 1, -1, 1, 3],
    EqualizerPreset.rock => const <double>[4, 2, -1, 2, 4],
    EqualizerPreset.classical => const <double>[0, 0, 0, 2, 3],
    EqualizerPreset.vocal => const <double>[-2, 1, 3, 2, -1],
  };
}

class EqualizerSettings {
  const EqualizerSettings({
    this.enabled = false,
    this.gains = const <double>[0, 0, 0, 0, 0],
    this.preset = EqualizerPreset.flat,
  });

  final bool enabled;
  final List<double> gains;
  final EqualizerPreset preset;

  EqualizerSettings copyWith({
    bool? enabled,
    List<double>? gains,
    EqualizerPreset? preset,
  }) {
    return EqualizerSettings(
      enabled: enabled ?? this.enabled,
      gains: List<double>.unmodifiable(gains ?? this.gains),
      preset: preset ?? this.preset,
    );
  }

  static EqualizerSettings fromRow(Setting? row) {
    return EqualizerSettings(
      enabled: row?.equalizerEnabled ?? false,
      gains: _decodeGains(row?.equalizerGainsJson),
      preset: _presetFromString(row?.equalizerPreset),
    );
  }

  static List<double> _decodeGains(String? value) {
    try {
      final decoded = jsonDecode(value ?? '');
      if (decoded is List) {
        return List<double>.unmodifiable(
          List<double>.generate(
            equalizerFrequencies.length,
            (index) => decoded.length > index && decoded[index] is num
                ? (decoded[index] as num).toDouble().clamp(-12, 12).toDouble()
                : 0,
          ),
        );
      }
    } catch (_) {
      // Fall through to the neutral preset for malformed local settings.
    }
    return const <double>[0, 0, 0, 0, 0];
  }

  static EqualizerPreset _presetFromString(String? value) {
    return EqualizerPreset.values.firstWhere(
      (preset) => preset.name == value,
      orElse: () => EqualizerPreset.flat,
    );
  }
}
