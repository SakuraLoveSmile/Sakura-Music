import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/appearance.dart';
import '../../data/db/app_database.dart';
import '../../data/server_repository.dart';
import '../player/equalizer_panel.dart';
import '../welcome/widgets/add_server_dialog.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _autoPlayOnLaunch = false;
  bool _fadeTransition = false;
  bool _musicRoaming = false;
  String _downloadNetwork = '仅 Wi-Fi';
  String _audioQuality = '无损 / 自动';

  @override
  Widget build(BuildContext context) {
    final activeServer = ref.watch(activeServerProvider);
    final serversAsync = ref.watch(serversProvider);

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
          tooltip: '返回',
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/home');
            }
          },
        ),
        title: const Text(
          '设置',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: <Widget>[
          if (activeServer != null)
            PopupMenuButton<Server>(
              tooltip: '切换音乐库',
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
              tooltip: '设置',
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
              _buildSectionTitle('播放'),
              _buildCardContainer(<Widget>[
                _buildSwitchTile(
                  icon: Icons.play_arrow_rounded,
                  iconColor: const Color(0xFF0A84FF),
                  title: '启动后自动播放',
                  value: _autoPlayOnLaunch,
                  onChanged: (val) => setState(() => _autoPlayOnLaunch = val),
                ),
                _buildDivider(),
                _buildSwitchTile(
                  icon: Icons.volume_up_rounded,
                  iconColor: const Color(0xFF5856D6),
                  title: '淡入淡出',
                  value: _fadeTransition,
                  onChanged: (val) => setState(() => _fadeTransition = val),
                ),
                _buildDivider(),
                _buildSwitchTile(
                  icon: Icons.directions_walk_rounded,
                  iconColor: const Color(0xFF30B0C7),
                  title: '音樂漫遊',
                  value: _musicRoaming,
                  onChanged: (val) => setState(() => _musicRoaming = val),
                ),
                _buildDivider(),
                _buildActionTile(
                  icon: Icons.headphones_rounded,
                  iconColor: const Color(0xFFFF9500),
                  title: '有聲書/播客',
                  onTap: () => context.go('/radios'),
                ),
                _buildDivider(),
                _buildActionTile(
                  icon: Icons.graphic_eq_rounded,
                  iconColor: const Color(0xFFAF52DE),
                  title: '在线播放音质',
                  trailingText: _audioQuality,
                  onTap: () => _showAudioQualityDialog(),
                ),
                _buildDivider(),
                _buildActionTile(
                  icon: Icons.equalizer_rounded,
                  iconColor: const Color(0xFF34C759),
                  title: '均衡器设置',
                  onTap: () => showEqualizerPanel(context),
                ),
              ]),
              const SizedBox(height: 24),

              // 3. Network Section (网络)
              _buildSectionTitle('网络'),
              _buildCardContainer(<Widget>[
                _buildDropdownTile(
                  icon: Icons.download_rounded,
                  iconColor: const Color(0xFF34C759),
                  title: '后台下载',
                  value: _downloadNetwork,
                  options: const <String>['仅 Wi-Fi', '所有网络', '关闭'],
                  onChanged: (val) {
                    if (val != null) setState(() => _downloadNetwork = val);
                  },
                ),
                _buildDivider(),
                _buildActionTile(
                  icon: Icons.language_rounded,
                  iconColor: const Color(0xFF32ADE6),
                  title: '网络代理',
                  onTap: () => _showProxyDialog(),
                ),
              ]),
              const SizedBox(height: 24),

              // 4. Storage & Servers Section (存储与服务器)
              _buildSectionTitle('存储与服务'),
              _buildCardContainer(<Widget>[
                _buildActionTile(
                  icon: Icons.dns_rounded,
                  iconColor: const Color(0xFF1E7BF6),
                  title: '服务器管理',
                  trailingText: activeServer?.name ?? '未连接',
                  onTap: () => context.go('/welcome'),
                ),
                _buildDivider(),
                _buildActionTile(
                  icon: Icons.add_circle_outline_rounded,
                  iconColor: const Color(0xFF34C759),
                  title: '添加新服务器',
                  onTap: () => AddServerDialog.show(context),
                ),
                _buildDivider(),
                _buildActionTile(
                  icon: Icons.cleaning_services_rounded,
                  iconColor: const Color(0xFFFF453A),
                  title: '清除歌曲缓存',
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('已清除本地临时缓存数据')),
                    );
                  },
                ),
              ]),
              const SizedBox(height: 24),

              // 5. Appearance Section
              _buildSectionTitle('外观'),
              _buildCardContainer(<Widget>[
                _buildActionTile(
                  icon: Icons.palette_outlined,
                  iconColor: const Color(0xFFFF2D55),
                  title: '主题与颜色',
                  onTap: () => _showAppearanceDialog(context),
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
                const Expanded(
                  child: Text(
                    '会员',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Text(
                  '未开通',
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
              if (trailingText != null) ...[
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

  void _showAudioQualityDialog() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E2028),
        title: const Text('在线播放音质', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            _qualityOption('无损 / 自动 (优先原始音频流)'),
            _qualityOption('FLAC / WAV 极高音质'),
            _qualityOption('320 kbps MP3 高音质'),
            _qualityOption('192 kbps MP3 标准音质'),
            _qualityOption('128 kbps MP3 流畅节省流量'),
          ],
        ),
      ),
    );
  }

  Widget _qualityOption(String label) {
    final selected = _audioQuality.startsWith(label.split(' ').first);
    return ListTile(
      title: Text(
        label,
        style: const TextStyle(color: Colors.white70, fontSize: 13.5),
      ),
      trailing: selected
          ? const Icon(Icons.check, color: Color(0xFF1E7BF6))
          : null,
      onTap: () {
        setState(() => _audioQuality = label.split(' (').first);
        Navigator.of(context).pop();
      },
    );
  }

  void _showProxyDialog() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E2028),
        title: const Text('网络代理设置', style: TextStyle(color: Colors.white)),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            TextField(
              style: TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'HTTP / SOCKS5 代理地址',
                hintText: '127.0.0.1:7890',
              ),
            ),
          ],
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('网络代理设置已保存')));
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  void _showAppearanceDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E2028),
        title: const Text('主题外观', style: TextStyle(color: Colors.white)),
        content: Consumer(
          builder: (context, ref, _) {
            final appearance =
                ref.watch(appearanceProvider).value ?? const AppAppearance();
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                ListTile(
                  title: const Text(
                    '深色模式',
                    style: TextStyle(color: Colors.white),
                  ),
                  trailing: appearance.themeMode == ThemeMode.dark
                      ? const Icon(Icons.check, color: Color(0xFF1E7BF6))
                      : null,
                  onTap: () {
                    ref
                        .read(appearanceProvider.notifier)
                        .setThemeMode(ThemeMode.dark);
                    Navigator.of(context).pop();
                  },
                ),
                ListTile(
                  title: const Text(
                    '跟随系统',
                    style: TextStyle(color: Colors.white70),
                  ),
                  trailing: appearance.themeMode == ThemeMode.system
                      ? const Icon(Icons.check, color: Color(0xFF1E7BF6))
                      : null,
                  onTap: () {
                    ref
                        .read(appearanceProvider.notifier)
                        .setThemeMode(ThemeMode.system);
                    Navigator.of(context).pop();
                  },
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
