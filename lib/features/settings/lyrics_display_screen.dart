import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../l10n/l10n.dart';
import '../lyrics_overlay/lyrics_overlay_config.dart';
import '../lyrics_overlay/lyrics_overlay_controller.dart';
import '../status_bar_lyrics/status_bar_lyrics_controller.dart';

/// Android "lyrics display" screen: the floating desktop overlay switch with
/// its live appearance settings, plus the Lyricon status-bar lyrics switch.
class LyricsDisplayScreen extends ConsumerWidget {
  const LyricsDisplayScreen({super.key});

  static const Color _background = Color(0xFF131418);
  static const Color _card = Color(0xFF1B1C22);
  static const Color _accent = Color(0xFF1E7BF6);
  static const Color _accentGreen = Color(0xFF30D158);

  /// Quick picks offered next to `lyricsOverlayTextColor`.
  static const List<Color> _textColorPresets = <Color>[
    Colors.white,
    Color(0xFFFFD1DC),
    Color(0xFFFFD54F),
    Color(0xFF9BE7FF),
    Color(0xFFFF8A80),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAndroid = Platform.isAndroid;
    final config =
        ref.watch(lyricsOverlayConfigProvider).value ??
        LyricsOverlayConfig.defaults();

    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: _background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.chevron_left_rounded,
            size: 28,
            color: Colors.white,
          ),
          tooltip: context.l10n.back,
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/settings');
            }
          },
        ),
        title: Text(
          context.l10n.lyricsDisplay,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
            children: <Widget>[
              if (isAndroid) ...<Widget>[
                _buildSectionTitle(context.l10n.lyricsOverlay),
                _buildOverlaySwitchCard(context, ref),
                const SizedBox(height: 24),
                _buildSectionTitle(context.l10n.lyricsDisplay),
                _buildAppearanceCard(context, ref, config),
                const SizedBox(height: 24),
              ],
              _buildSectionTitle(context.l10n.statusBarLyrics),
              _buildStatusBarLyricsCard(context, ref),
            ],
          ),
        ),
      ),
    );
  }

  /// Asks for the "display over other apps" permission before enabling the
  /// floating window; mirrors the behaviour of the old settings switch.
  Future<void> _toggleOverlay(
    BuildContext context,
    WidgetRef ref,
    bool enabled,
  ) async {
    final notifier = ref.read(lyricsOverlayControllerProvider.notifier);
    if (!enabled) {
      await notifier.setEnabled(false);
      return;
    }
    var status = await Permission.systemAlertWindow.status;
    if (!status.isGranted) {
      status = await Permission.systemAlertWindow.request();
    }
    if (!status.isGranted) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.lyricsOverlayPermissionNeeded)),
        );
      }
      return;
    }
    await notifier.setEnabled(true);
  }

  Widget _buildSectionTitle(String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 0, 6, 8),
      child: Text(
        label,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.4),
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  Widget _buildOverlaySwitchCard(BuildContext context, WidgetRef ref) {
    return _buildCard(
      child: Row(
        children: <Widget>[
          _buildIconBadge(Icons.lyrics_rounded, _accent),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              context.l10n.lyricsOverlay,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Switch(
            value: ref.watch(lyricsOverlayControllerProvider),
            activeTrackColor: _accent,
            onChanged: (value) {
              unawaited(_toggleOverlay(context, ref, value));
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBarLyricsCard(BuildContext context, WidgetRef ref) {
    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              _buildIconBadge(Icons.text_fields_rounded, _accentGreen),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  context.l10n.statusBarLyrics,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Switch(
                value: ref.watch(statusBarLyricsControllerProvider),
                activeTrackColor: _accentGreen,
                onChanged: (value) {
                  unawaited(
                    ref
                        .read(statusBarLyricsControllerProvider.notifier)
                        .setEnabled(value),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            context.l10n.lyriconAppearanceNote,
            style: TextStyle(
              fontSize: 12,
              height: 1.4,
              color: Colors.white.withValues(alpha: 0.45),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppearanceCard(
    BuildContext context,
    WidgetRef ref,
    LyricsOverlayConfig config,
  ) {
    final notifier = ref.read(lyricsOverlayConfigProvider.notifier);

    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _buildValueRow(
            context.l10n.lyricsOverlayFontSize,
            '${(config.fontScale * 100).round()}%',
          ),
          _buildSlider(
            value: config.fontScale,
            min: LyricsOverlayConfig.minFontScale,
            max: LyricsOverlayConfig.maxFontScale,
            divisions: 8,
            label: '${(config.fontScale * 100).round()}%',
            onChanged: (value) {
              unawaited(notifier.apply(config.copyWith(fontScale: value)));
            },
          ),
          _buildDivider(),
          _buildValueRow(context.l10n.lyricsOverlayTextColor, null),
          _buildTextColorRow(config, notifier),
          const SizedBox(height: 12),
          _buildDivider(),
          _buildValueRow(
            context.l10n.lyricsOverlayOpacity,
            '${(config.backgroundOpacity * 100 / 255).round()}%',
          ),
          _buildSlider(
            value: config.backgroundOpacity.toDouble(),
            min: LyricsOverlayConfig.minBackgroundOpacity.toDouble(),
            max: LyricsOverlayConfig.maxBackgroundOpacity.toDouble(),
            divisions: 51,
            label: '${(config.backgroundOpacity * 100 / 255).round()}%',
            onChanged: (value) {
              unawaited(
                notifier.apply(
                  config.copyWith(backgroundOpacity: value.round()),
                ),
              );
            },
          ),
          _buildDivider(),
          _buildValueRow(
            context.l10n.lyricsOverlayCornerRadius,
            '${config.cornerRadiusDp.round()} dp',
          ),
          _buildSlider(
            value: config.cornerRadiusDp,
            min: LyricsOverlayConfig.minCornerRadiusDp,
            max: LyricsOverlayConfig.maxCornerRadiusDp,
            divisions: 40,
            label: '${config.cornerRadiusDp.round()} dp',
            onChanged: (value) {
              unawaited(notifier.apply(config.copyWith(cornerRadiusDp: value)));
            },
          ),
          _buildDivider(),
          _buildSwitchRow(
            title: context.l10n.lyricsOverlayShowNextLine,
            value: config.showNextLine,
            onChanged: (value) {
              unawaited(notifier.apply(config.copyWith(showNextLine: value)));
            },
          ),
          _buildDivider(),
          _buildSwitchRow(
            title: context.l10n.lyricsOverlayShowCloseButton,
            value: config.showCloseButton,
            onChanged: (value) {
              unawaited(
                notifier.apply(config.copyWith(showCloseButton: value)),
              );
            },
          ),
          _buildDivider(),
          _buildValueRow(context.l10n.lyricsOverlayPosition, null),
          const SizedBox(height: 10),
          _buildPositionRow(context, config, notifier),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () {
                unawaited(notifier.reset());
              },
              style: TextButton.styleFrom(foregroundColor: Colors.white70),
              child: Text(
                context.l10n.lyricsOverlayReset,
                style: const TextStyle(fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextColorRow(
    LyricsOverlayConfig config,
    LyricsOverlayConfigController notifier,
  ) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: <Widget>[
          for (final color in _textColorPresets)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: _buildColorDot(
                color: color,
                selected: config.textColor == color.toARGB32(),
                onTap: () {
                  unawaited(
                    notifier.apply(
                      config.copyWith(textColor: color.toARGB32()),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildColorDot({
    required Color color,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: selected
                  ? Colors.white
                  : Colors.white.withValues(alpha: 0.16),
              width: 2,
            ),
          ),
          child: Container(
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
          ),
        ),
      ),
    );
  }

  Widget _buildPositionRow(
    BuildContext context,
    LyricsOverlayConfig config,
    LyricsOverlayConfigController notifier,
  ) {
    return Wrap(
      spacing: 10,
      runSpacing: 8,
      children: <Widget>[
        _buildPositionChip(
          label: context.l10n.lyricsOverlayPositionTop,
          config: config,
          notifier: notifier,
          position: LyricsOverlayPosition.top,
        ),
        _buildPositionChip(
          label: context.l10n.lyricsOverlayPositionCenter,
          config: config,
          notifier: notifier,
          position: LyricsOverlayPosition.center,
        ),
        _buildPositionChip(
          label: context.l10n.lyricsOverlayPositionBottom,
          config: config,
          notifier: notifier,
          position: LyricsOverlayPosition.bottom,
        ),
      ],
    );
  }

  Widget _buildPositionChip({
    required String label,
    required LyricsOverlayConfig config,
    required LyricsOverlayConfigController notifier,
    required LyricsOverlayPosition position,
  }) {
    final selected = config.position == position;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      onSelected: (_) {
        unawaited(notifier.apply(config.copyWith(position: position)));
      },
      backgroundColor: _background,
      selectedColor: _accent.withValues(alpha: 0.22),
      labelStyle: TextStyle(
        fontSize: 12.5,
        fontWeight: FontWeight.w600,
        color: selected ? Colors.white : Colors.white.withValues(alpha: 0.6),
      ),
      side: BorderSide(
        color: selected ? _accent : Colors.white.withValues(alpha: 0.08),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    );
  }

  Widget _buildValueRow(String title, String? value) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (value != null)
            Text(
              value,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.55),
                fontSize: 12.5,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSwitchRow({
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Switch(value: value, activeTrackColor: _accent, onChanged: onChanged),
      ],
    );
  }

  Widget _buildSlider({
    required double value,
    required double min,
    required double max,
    required int divisions,
    required String label,
    required ValueChanged<double> onChanged,
  }) {
    return Slider(
      value: value,
      min: min,
      max: max,
      divisions: divisions,
      activeColor: _accent,
      label: label,
      onChanged: onChanged,
    );
  }

  Widget _buildDivider() {
    return Divider(height: 20, color: Colors.white.withValues(alpha: 0.06));
  }

  Widget _buildIconBadge(IconData icon, Color color) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.16),
      ),
      child: Icon(icon, color: color, size: 20),
    );
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      padding: const EdgeInsets.all(18),
      child: child,
    );
  }
}
