import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../audio/equalizer_models.dart';
import '../../audio/equalizer_service.dart';
import '../../l10n/l10n.dart';

Future<void> showEqualizerPanel(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 16),
        child: const EqualizerControls(),
      ),
    ),
  );
}

class EqualizerControls extends ConsumerWidget {
  const EqualizerControls({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(equalizerProvider);
    final supported = !Platform.isIOS;
    return Card(
      margin: const EdgeInsets.fromLTRB(0, 0, 0, 12),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: value.when(
          loading: () => const LinearProgressIndicator(),
          error: (error, stackTrace) =>
              Text(context.l10n.equalizerLoadFailed(error.toString())),
          data: (settings) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      context.l10n.equalizerTitle,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  if (!supported)
                    Text(context.l10n.iosNotSupported, style: const TextStyle(fontSize: 12)),
                ],
              ),
              const SizedBox(height: 8),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: Text(context.l10n.enableEqualizer),
                value: settings.enabled,
                onChanged: supported
                    ? (enabled) => ref
                          .read(equalizerProvider.notifier)
                          .setEnabled(enabled)
                    : null,
              ),
              DropdownButtonFormField<EqualizerPreset>(
                initialValue: settings.preset,
                decoration: InputDecoration(labelText: context.l10n.presetLabel),
                items: EqualizerPreset.values
                    .map(
                      (preset) => DropdownMenuItem<EqualizerPreset>(
                        value: preset,
                        child: Text(_presetLabel(context, preset)),
                      ),
                    )
                    .toList(growable: false),
                onChanged: supported
                    ? (preset) {
                        if (preset != null) {
                          unawaited(
                            ref
                                .read(equalizerProvider.notifier)
                                .setPreset(preset),
                          );
                        }
                      }
                    : null,
              ),
              const SizedBox(height: 16),
              for (var index = 0; index < equalizerFrequencies.length; index++)
                Row(
                  children: <Widget>[
                    SizedBox(width: 58, child: Text(_frequencyLabel(index))),
                    Expanded(
                      child: Slider(
                        min: -12,
                        max: 12,
                        divisions: 48,
                        value: settings.gains[index].clamp(-12, 12).toDouble(),
                        label: '${settings.gains[index].toStringAsFixed(1)} dB',
                        onChanged: supported
                            ? (gain) => unawaited(
                                ref
                                    .read(equalizerProvider.notifier)
                                    .setGain(index, gain),
                              )
                            : null,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

String _presetLabel(BuildContext context, EqualizerPreset preset) {
  return switch (preset) {
    EqualizerPreset.flat => context.l10n.presetFlat,
    EqualizerPreset.pop => context.l10n.presetPop,
    EqualizerPreset.rock => context.l10n.presetRock,
    EqualizerPreset.classical => context.l10n.presetClassical,
    EqualizerPreset.vocal => context.l10n.presetVocal,
  };
}

String _frequencyLabel(int index) {
  final frequency = equalizerFrequencies[index];
  if (frequency >= 1000) {
    return '${(frequency / 1000).toStringAsFixed(frequency % 1000 == 0 ? 0 : 1)}k';
  }
  return '${frequency.toInt()}';
}
