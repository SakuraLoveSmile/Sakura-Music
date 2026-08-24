import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/locale.dart';
import '../../l10n/l10n.dart';
import '../../core/update/update_providers.dart';
import '../../data/db/app_database.dart';
import '../../data/server_repository.dart';
import '../../features/lyrics_overlay/lyrics_overlay_controller.dart';
import '../player/equalizer_panel.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _autoPlayOnLaunch = false;
  bool _fadeTransition = false;
  bool _musicRoaming = false;
  int _downloadNetworkIndex = 0;
  int _audioQualityIndex = 0;

  @override
  Widget build(BuildContext context) {
    final activeServer = ref.watch(activeServerProvider);
    final serversAsync = ref.watch(serversProvider);
    final appVersion = ref.watch(appVersionProvider);
    final updateState = ref.watch(updateControllerProvider);
    final localeCode = ref.watch(localeCodeProvider);
    final downloadNetworkOptions = <String>[
      context.l10n.downloadWifiOnly,
      context.l10n.downloadAnyNetwork,
      context.l10n.downloadOff,
    ];

    return Scaffold(
      backgroundColor: const Color(0xFF131418),
      appBar: AppBar(
        backgroundColor: const Color(0xFF131418),
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
              context.go('/home');
            }
          },
        ),
        title: Text(
          context.l10n.settings,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: <Widget>[
          if (activeServer != null)
            PopupMenuButton<Server>(
              tooltip: context.l10n.switchLibrary,
              offset: const Offset(0, 40),
              color: const Color(0xFF22252E),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              onSelected: (server) {
                ref.read(selectedServerIdProvider.notifier).state = server.id;
              },
              itemBuilder: (context) {
                final servers = serversAsync.value ?? <Server>[];
                return servers
                    .map(
                      (s) => PopupMenuItem<Server>(
                        value: s,
                        child: Row(
                          children: <Widget>[
                            Icon(
                              Icons.album_rounded,
                              size: 16,
                              color: s.id == activeServer.id
                                  ? const Color(0xFF1E7BF6)
                                  : Colors.white70,
                            ),
                            const SizedBox(width: 8),
                            Expanded(child: Text(s.name)),
                          ],
                        ),
                      ),
                    )
                    .toList();
              },
              child: Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E2028),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.album_rounded,
                  size: 18,
                  color: Color(0xFF1E7BF6),
                ),
              ),
            ),
          Container(
            margin: const EdgeInsets.only(right: 16),
            decoration: BoxDecoration(
              color: const Color(0xFF1E2028),
              borderRadius: BorderRadius.circular(8),
            ),
            child: IconButton(
              icon: const Icon(
                Icons.settings_outlined,
                size: 18,
                color: Color(0xFF1E7BF6),
              ),
              tooltip: context.l10n.settings,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(width: 32, height: 32),
              onPressed: () {},
            ),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
            children: <Widget>[
              // 1. VIP Membership Card
              _buildVIPCard(context),
              const SizedBox(height: 24),

              // 2. Playback Section (播放)
              _buildSectionTitle(context.l10n.sectionPlayback),
              _buildCardContainer(<Widget>[
                _buildSwitchTile(
                  icon: Icons.play_arrow_rounded,
                  iconColor: const Color(0xFF0A84FF),
                  title: context.l10n.autoPlayOnLaunch,
                  value: _autoPlayOnLaunch,
                  onChanged: (val) => setState(() => _autoPlayOnLaunch = val),
                ),
                _buildDivider(),
                _buildSwitchTile(
                  icon: Icons.volume_up_rounded,
                  iconColor: const Color(0xFF5856D6),
                  title: context.l10n.fadeTransition,
                  value: _fadeTransition,
                  onChanged: (val) => setState(() => _fadeTransition = val),
                ),
                _buildDivider(),
                _buildSwitchTile(
                  icon: Icons.directions_walk_rounded,
                  iconColor: const Color(0xFF30B0C7),
                  title: context.l10n.musicRoaming,
                  value: _musicRoaming,
                  onChanged: (val) => setState(() => _musicRoaming = val),
                ),
                _buildDivider(),
                _buildActionTile(
                  icon: Icons.headphones_rounded,
                  iconColor: const Color(0xFFFF9500),
                  title: context.l10n.audiobooksPodcasts,
                  onTap: () => context.go('/radios'),
                ),
                _buildDivider(),
                _buildActionTile(
                  icon: Icons.graphic_eq_rounded,
                  iconColor: const Color(0xFFAF52DE),
                  title: context.l10n.streamingQuality,
                  trailingText: _qualityLabels()[_audioQualityIndex],
                  onTap: () => _showAudioQualityDialog(),
                ),
                _buildDivider(),
                _buildActionTile(
                  icon: Icons.equalizer_rounded,
                  iconColor: const Color(0xFF34C759),
                  title: context.l10n.equalizerSettings,
                  onTap: () => showEqualizerPanel(context),
                ),
                _buildDivider(),
                _buildActionTile(
                  icon: Icons.bug_report_rounded,
                  iconColor: const Color(0xFF64D2FF),
                  title: context.l10n.debugDiagnostics,
                  onTap: () => context.push('/debug'),
                ),
                if (Platform.isAndroid) ...<Widget>[
                  _buildDivider(),
                  _buildSwitchTile(
                    icon: Icons.lyrics_rounded,
                    iconColor: const Color(0xFF1E7BF6),
                    title: context.l10n.lyricsOverlay,
                    value: ref.watch(lyricsOverlayControllerProvider),
                    onChanged: _toggleLyricsOverlay,
                  ),
                ],
              ]),
              const SizedBox(height: 24),

              // 3. Network Section (网络)
              _buildSectionTitle(context.l10n.sectionNetwork),
              _buildCardContainer(<Widget>[
                _buildDropdownTile(
                  icon: Icons.download_rounded,
                  iconColor: const Color(0xFF34C759),
                  title: context.l10n.backgroundDownload,
                  value: downloadNetworkOptions[_downloadNetworkIndex],
                  options: downloadNetworkOptions,
                  onChanged: (val) {
                    final index = downloadNetworkOptions.indexOf(val ?? '');
                    if (index >= 0) {
                      setState(() => _downloadNetworkIndex = index);
                    }
                  },
                ),
                _buildDivider(),
                _buildActionTile(
                  icon: Icons.language_rounded,
                  iconColor: const Color(0xFF32ADE6),
                  title: context.l10n.networkProxy,
                  onTap: () => _showProxyDialog(),
                ),
              ]),
              const SizedBox(height: 24),

              // 4. Storage & Servers Section (存储与服务器)
              _buildSectionTitle(context.l10n.sectionStorage),
              _buildCardContainer(<Widget>[
                _buildActionTile(
                  icon: Icons.dns_rounded,
                  iconColor: const Color(0xFF1E7BF6),
                  title: context.l10n.serverManagement,
                  trailingText: activeServer?.name ?? context.l10n.notConnected,
                  onTap: () => context.go('/welcome'),
                ),
                _buildDivider(),
                _buildActionTile(
                  icon: Icons.add_circle_outline_rounded,
                  iconColor: const Color(0xFF34C759),
                  title: context.l10n.addNewServer,
                  onTap: () => context.push('/add-server'),
                ),
                _buildDivider(),
                _buildActionTile(
                  icon: Icons.cleaning_services_rounded,
                  iconColor: const Color(0xFFFF453A),
                  title: context.l10n.clearCache,
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(context.l10n.cacheCleared)),
                    );
                  },
                ),
              ]),
              const SizedBox(height: 24),

              // 5. Appearance Section
              _buildSectionTitle(context.l10n.sectionAppearance),
              _buildCardContainer(<Widget>[
                _buildActionTile(
                  icon: Icons.translate_rounded,
                  iconColor: const Color(0xFF5856D6),
                  title: context.l10n.language,
                  trailingText: switch (localeCode) {
                    'system' => context.l10n.followSystem,
                    'en' => 'English',
                    _ => '简体中文',
                  },
                  onTap: _showLanguageDialog,
                ),
              ]),
              const SizedBox(height: 24),

              // 6. About Section
              _buildSectionTitle(context.l10n.sectionAbout),
              _buildCardContainer(<Widget>[
                _buildActionTile(
                  icon: Icons.info_outline_rounded,
                  iconColor: const Color(0xFF5E5CE6),
                  title: context.l10n.currentVersion,
                  trailingText: appVersion.when(
                    data: (info) => '${info.version}+${info.buildNumber}',
                    loading: () => context.l10n.loading,
                    error: (_, _) => context.l10n.unknown,
                  ),
                  onTap: () {},
                ),
                _buildDivider(),
                _buildActionTile(
                  icon: Icons.system_update_alt_rounded,
                  iconColor: const Color(0xFF1E7BF6),
                  title: context.l10n.checkUpdates,
                  trailingText: _updateStatusText(updateState),
                  trailingWidget: updateState.status == UpdateStatus.checking
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : null,
                  onTap: _checkForUpdates,
                ),
              ]),
              const SizedBox(height: 36),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVIPCard(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1B1C22),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => context.go('/membership'),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: <Widget>[
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF9500),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.workspace_premium_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    context.l10n.membership,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Text(
                  context.l10n.notActivated,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.4),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: Colors.white.withValues(alpha: 0.35),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 0, 6, 8),
      child: Text(
        title,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.4),
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  Widget _buildCardContainer(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1B1C22),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: children),
    );
  }

  Widget _buildDivider() {
    return const Divider(
      height: 1,
      thickness: 0.8,
      indent: 58,
      endIndent: 16,
      color: Color(0xFF242630),
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: <Widget>[
          _squircleIcon(icon, iconColor),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Switch(
            value: value,
            activeTrackColor: const Color(0xFF1E7BF6),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    String? trailingText,
    Widget? trailingWidget,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: <Widget>[
              _squircleIcon(icon, iconColor),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (trailingWidget != null) ...[
                trailingWidget,
                const SizedBox(width: 8),
              ] else if (trailingText != null) ...[
                Text(
                  trailingText,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.45),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(width: 4),
              ],
              Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: Colors.white.withValues(alpha: 0.35),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _toggleLyricsOverlay(bool enabled) async {
    if (!enabled) {
      await ref
          .read(lyricsOverlayControllerProvider.notifier)
          .setEnabled(false);
      return;
    }
    var status = await Permission.systemAlertWindow.status;
    if (!status.isGranted) {
      status = await Permission.systemAlertWindow.request();
    }
    if (!status.isGranted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.lyricsOverlayPermissionNeeded)),
        );
      }
      return;
    }
    await ref.read(lyricsOverlayControllerProvider.notifier).setEnabled(true);
  }

  String? _updateStatusText(UpdateState state) {
    return switch (state.status) {
      UpdateStatus.available => context.l10n.updateAvailable,
      UpdateStatus.downloading => context.l10n.downloading,
      UpdateStatus.downloaded => context.l10n.downloaded,
      UpdateStatus.installing => context.l10n.installing,
      UpdateStatus.error => context.l10n.retry,
      _ => null,
    };
  }

  Future<void> _checkForUpdates() async {
    await ref.read(updateControllerProvider.notifier).check();
    if (!mounted) return;
    final state = ref.read(updateControllerProvider);
    if (state.status == UpdateStatus.idle) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.upToDate)));
    } else if (state.status == UpdateStatus.error) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        SnackBar(
          content: Text(state.errorMessage ?? context.l10n.updateCheckFailed),
        ),
      );
    }
  }

  Widget _buildDropdownTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
    required List<String> options,
    required ValueChanged<String?> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: <Widget>[
          _squircleIcon(icon, iconColor),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          DropdownButton<String>(
            value: value,
            underline: const SizedBox.shrink(),
            dropdownColor: const Color(0xFF242630),
            borderRadius: BorderRadius.circular(12),
            icon: Icon(
              Icons.unfold_more_rounded,
              size: 18,
              color: Colors.white.withValues(alpha: 0.5),
            ),
            items: options
                .map(
                  (opt) => DropdownMenuItem<String>(
                    value: opt,
                    child: Text(
                      opt,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                    ),
                  ),
                )
                .toList(),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _squircleIcon(IconData icon, Color color) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: Colors.white, size: 18),
    );
  }

  List<String> _qualityLabels() {
    return <String>[
      context.l10n.qualityLosslessAuto,
      context.l10n.qualityFlacWav,
      context.l10n.quality320,
      context.l10n.quality192,
      context.l10n.quality128,
    ];
  }

  void _showAudioQualityDialog() {
    final labels = _qualityLabels();
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF1E2028),
        title: Text(
          context.l10n.streamingQuality,
          style: const TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            for (final (index, label) in labels.indexed)
              _qualityOption(index, label),
          ],
        ),
      ),
    );
  }

  Widget _qualityOption(int index, String label) {
    final selected = _audioQualityIndex == index;
    return ListTile(
      title: Text(
        label,
        style: const TextStyle(color: Colors.white70, fontSize: 13.5),
      ),
      trailing: selected
          ? const Icon(Icons.check, color: Color(0xFF1E7BF6))
          : null,
      onTap: () {
        setState(() => _audioQualityIndex = index);
        Navigator.of(context).pop();
      },
    );
  }

  void _showLanguageDialog() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF1E2028),
        title: Text(
          dialogContext.l10n.language,
          style: const TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            _languageOption(
              dialogContext,
              code: 'system',
              label: dialogContext.l10n.followSystem,
            ),
            _languageOption(dialogContext, code: 'zh', label: '简体中文'),
            _languageOption(dialogContext, code: 'en', label: 'English'),
          ],
        ),
      ),
    );
  }

  Widget _languageOption(
    BuildContext dialogContext, {
    required String code,
    required String label,
  }) {
    final selected = ref.read(localeCodeProvider) == code;
    return ListTile(
      title: Text(
        label,
        style: TextStyle(
          color: selected ? Colors.white : Colors.white70,
          fontSize: 13.5,
        ),
      ),
      trailing: selected
          ? const Icon(Icons.check, color: Color(0xFF1E7BF6))
          : null,
      onTap: () {
        ref.read(localeCodeProvider.notifier).setLocale(code);
        Navigator.of(dialogContext).pop();
      },
    );
  }

  void _showProxyDialog() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF1E2028),
        title: Text(dialogContext.l10n.proxyDialogTitle, style: const TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            TextField(
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: dialogContext.l10n.proxyAddressLabel,
                hintText: '127.0.0.1:7890',
              ),
            ),
          ],
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(dialogContext.l10n.cancel),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              ScaffoldMessenger.of(dialogContext).showSnackBar(
                SnackBar(content: Text(dialogContext.l10n.proxySaved)),
              );
            },
            child: Text(dialogContext.l10n.save),
          ),
        ],
      ),
    );
  }
}
