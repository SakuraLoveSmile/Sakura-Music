import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:subsonic_api/subsonic_api.dart';

import '../../audio/audio_player_provider.dart';
import '../../core/providers.dart';
import '../../data/db/app_database.dart';
import '../../data/server_repository.dart';
import 'mini_player_bar.dart';

class _NavMenuItem {
  const _NavMenuItem({
    required this.index,
    required this.path,
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });

  final int index;
  final String path;
  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

const _discoverItem = _NavMenuItem(
  index: 0,
  path: '/home',
  label: '发现',
  icon: Icons.explore_outlined,
  selectedIcon: Icons.explore_rounded,
);

const _libraryItems = <_NavMenuItem>[
  _NavMenuItem(
    index: 1,
    path: '/songs',
    label: '歌曲',
    icon: Icons.music_note_outlined,
    selectedIcon: Icons.music_note_rounded,
  ),
  _NavMenuItem(
    index: 2,
    path: '/albums',
    label: '专辑',
    icon: Icons.album_outlined,
    selectedIcon: Icons.album_rounded,
  ),
  _NavMenuItem(
    index: 3,
    path: '/artists',
    label: '艺术家',
    icon: Icons.person_outline_rounded,
    selectedIcon: Icons.person_rounded,
  ),
  _NavMenuItem(
    index: 4,
    path: '/genres',
    label: '流派',
    icon: Icons.category_outlined,
    selectedIcon: Icons.category_rounded,
  ),
  _NavMenuItem(
    index: 5,
    path: '/radios',
    label: '电台',
    icon: Icons.radio_outlined,
    selectedIcon: Icons.radio_rounded,
  ),
];

const _personalItems = <_NavMenuItem>[
  _NavMenuItem(
    index: 6,
    path: '/favorites',
    label: '我喜欢的',
    icon: Icons.favorite_border_rounded,
    selectedIcon: Icons.favorite_rounded,
  ),
  _NavMenuItem(
    index: 7,
    path: '/downloads',
    label: '下载管理',
    icon: Icons.download_outlined,
    selectedIcon: Icons.download_done_rounded,
  ),
];

class AppShell extends ConsumerWidget {
  const AppShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentIndex = navigationShell.currentIndex;
    final isWide = MediaQuery.sizeOf(context).width >= 720;
    final playlistsAsync = ref.watch(playlistsProvider);
    final activeServer = ref.watch(activeServerProvider);
    final serversAsync = ref.watch(serversProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF131418),
      body: Row(
        children: <Widget>[
          if (isWide)
            _DesktopSidebar(
              currentIndex: currentIndex,
              navigationShell: navigationShell,
              playlistsAsync: playlistsAsync,
              activeServer: activeServer,
              serversAsync: serversAsync,
              onSwitchServer: (server) {
                ref.read(selectedServerIdProvider.notifier).state = server.id;
              },
            ),
          Expanded(
            child: Column(
              children: <Widget>[
                // Top Global Action Header
                _TopActionBar(
                  activeServer: activeServer,
                  serversAsync: serversAsync,
                  onSwitchServer: (server) {
                    ref.read(selectedServerIdProvider.notifier).state =
                        server.id;
                  },
                ),
                Expanded(child: navigationShell),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          MiniPlayerBar(service: ref.watch(audioPlayerProvider)),
          if (!isWide)
            NavigationBar(
              selectedIndex: currentIndex.clamp(0, 4),
              onDestinationSelected: (index) {
                navigationShell.goBranch(
                  index,
                  initialLocation: index == navigationShell.currentIndex,
                );
              },
              destinations: const <NavigationDestination>[
                NavigationDestination(
                  icon: Icon(Icons.explore_outlined),
                  selectedIcon: Icon(Icons.explore_rounded),
                  label: '发现',
                ),
                NavigationDestination(
                  icon: Icon(Icons.music_note_outlined),
                  selectedIcon: Icon(Icons.music_note_rounded),
                  label: '歌曲',
                ),
                NavigationDestination(
                  icon: Icon(Icons.album_outlined),
                  selectedIcon: Icon(Icons.album_rounded),
                  label: '专辑',
                ),
                NavigationDestination(
                  icon: Icon(Icons.favorite_border_rounded),
                  selectedIcon: Icon(Icons.favorite_rounded),
                  label: '喜欢',
                ),
                NavigationDestination(
                  icon: Icon(Icons.download_outlined),
                  selectedIcon: Icon(Icons.download_done_rounded),
                  label: '下载',
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _TopActionBar extends StatelessWidget {
  const _TopActionBar({
    required this.activeServer,
    required this.serversAsync,
    required this.onSwitchServer,
  });

  final Server? activeServer;
  final AsyncValue<List<Server>> serversAsync;
  final void Function(Server) onSwitchServer;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: Color(0xFF131418),
        border: Border(
          bottom: BorderSide(color: Color(0xFF1F2128), width: 0.8),
        ),
      ),
      child: Row(
        children: <Widget>[
          const Spacer(),

          // Server Switch Disc Icon / Popup
          if (activeServer != null)
            PopupMenuButton<Server>(
              tooltip: '切换音乐库',
              offset: const Offset(0, 40),
              color: const Color(0xFF22252E),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              onSelected: onSwitchServer,
              itemBuilder: (context) {
                final servers = serversAsync.value ?? <Server>[];
                return <PopupMenuEntry<Server>>[
                  const PopupMenuItem<Server>(
                    enabled: false,
                    child: Text(
                      '已连接的音乐库',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.white54,
                      ),
                    ),
                  ),
                  ...servers.map(
                    (s) => PopupMenuItem<Server>(
                      value: s,
                      child: Row(
                        children: <Widget>[
                          Icon(
                            Icons.album_rounded,
                            size: 16,
                            color: s.id == activeServer!.id
                                ? const Color(0xFF1E7BF6)
                                : Colors.white70,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              s.name,
                              style: TextStyle(
                                color: s.id == activeServer!.id
                                    ? const Color(0xFF1E7BF6)
                                    : Colors.white,
                                fontWeight: s.id == activeServer!.id
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                          ),
                          if (s.id == activeServer!.id)
                            const Icon(
                              Icons.check,
                              size: 16,
                              color: Color(0xFF1E7BF6),
                            ),
                        ],
                      ),
                    ),
                  ),
                ];
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E2028),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const Icon(
                      Icons.album_rounded,
                      size: 16,
                      color: Color(0xFF1E7BF6),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      activeServer!.name,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.arrow_drop_down,
                      size: 16,
                      color: Colors.white70,
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(width: 8),

          // Search Button
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF1E2028),
              borderRadius: BorderRadius.circular(8),
            ),
            child: IconButton(
              icon: const Icon(
                Icons.search_rounded,
                size: 18,
                color: Colors.white70,
              ),
              tooltip: '搜索',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(width: 32, height: 32),
              onPressed: () => context.go('/search'),
            ),
          ),
          const SizedBox(width: 8),

          // Settings Button
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF1E2028),
              borderRadius: BorderRadius.circular(8),
            ),
            child: IconButton(
              icon: const Icon(
                Icons.settings_outlined,
                size: 18,
                color: Colors.white70,
              ),
              tooltip: '设置',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(width: 32, height: 32),
              onPressed: () => context.go('/settings'),
            ),
          ),
        ],
      ),
    );
  }
}

class _DesktopSidebar extends StatelessWidget {
  const _DesktopSidebar({
    required this.currentIndex,
    required this.navigationShell,
    required this.playlistsAsync,
    required this.activeServer,
    required this.serversAsync,
    required this.onSwitchServer,
  });

  final int currentIndex;
  final StatefulNavigationShell navigationShell;
  final AsyncValue<List<Playlist>> playlistsAsync;
  final Server? activeServer;
  final AsyncValue<List<Server>> serversAsync;
  final void Function(Server) onSwitchServer;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 236,
      decoration: const BoxDecoration(
        color: Color(0xFF141519),
        border: Border(right: BorderSide(color: Color(0xFF22242B), width: 1.0)),
      ),
      child: SafeArea(
        right: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            // macOS already renders these controls in the native title bar.
            // Keep the same breathing room without drawing a second set of
            // traffic lights inside the Flutter content area.
            if (Platform.isMacOS)
              const SizedBox(height: 37)
            else
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 14, 16, 12),
                child: Row(
                  children: <Widget>[
                    Icon(
                      Icons.music_note_rounded,
                      color: Color(0xFF1E7BF6),
                      size: 22,
                    ),
                    SizedBox(width: 8),
                    Text(
                      '音流',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),

            // Search Box (Rounded Dark Gray)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => context.go('/search'),
                child: Container(
                  height: 34,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF22242D),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.05),
                    ),
                  ),
                  child: Row(
                    children: <Widget>[
                      Icon(
                        Icons.search_rounded,
                        size: 17,
                        color: Colors.white.withValues(alpha: 0.45),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '搜索',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withValues(alpha: 0.4),
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 10),

            // Scrollable Menu Groups
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                children: <Widget>[
                  // 1. 发现 Group
                  _buildNavTile(
                    item: _discoverItem,
                    isSelected: currentIndex == _discoverItem.index,
                    onTap: () => navigationShell.goBranch(_discoverItem.index),
                  ),

                  const SizedBox(height: 16),

                  // 2. 音乐库 Group
                  _buildSectionHeader('音乐库'),
                  ..._libraryItems.map(
                    (item) => _buildNavTile(
                      item: item,
                      isSelected: currentIndex == item.index,
                      onTap: () => navigationShell.goBranch(item.index),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 3. 个人 Group
                  _buildSectionHeader('个人'),
                  ..._personalItems.map(
                    (item) => _buildNavTile(
                      item: item,
                      isSelected: currentIndex == item.index,
                      onTap: () => navigationShell.goBranch(item.index),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 4. 我的歌单 Group
                  _buildPlaylistsSection(context),

                  const SizedBox(height: 20),
                ],
              ),
            ),

            // Bottom Server Info
            if (activeServer != null)
              Container(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                decoration: const BoxDecoration(
                  border: Border(
                    top: BorderSide(color: Color(0xFF1F2128), width: 1.0),
                  ),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => context.go('/welcome'),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 4,
                    ),
                    child: Row(
                      children: <Widget>[
                        const Icon(
                          Icons.cloud_done_rounded,
                          size: 16,
                          color: Color(0xFF34C759),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            activeServer!.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.white70,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        Icon(
                          Icons.chevron_right_rounded,
                          size: 16,
                          color: Colors.white.withValues(alpha: 0.3),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 6),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Colors.white.withValues(alpha: 0.35),
          letterSpacing: 0.6,
        ),
      ),
    );
  }

  Widget _buildNavTile({
    required _NavMenuItem item,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 2),
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFF1E7BF6) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: <Widget>[
                Icon(
                  isSelected ? item.selectedIcon : item.icon,
                  size: 18,
                  color: isSelected
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.7),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    item.label,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.w500,
                      color: isSelected
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.85),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlaylistsSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 6, 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text(
                '我的歌单',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: 0.35),
                  letterSpacing: 0.6,
                ),
              ),
              InkWell(
                onTap: () => navigationShell.goBranch(8),
                borderRadius: BorderRadius.circular(4),
                child: Padding(
                  padding: const EdgeInsets.all(2),
                  child: Icon(
                    Icons.chevron_right_rounded,
                    size: 16,
                    color: Colors.white.withValues(alpha: 0.4),
                  ),
                ),
              ),
            ],
          ),
        ),
        playlistsAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: SizedBox.square(
              dimension: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Color(0xFF1E7BF6),
              ),
            ),
          ),
          error: (err, _) => const SizedBox.shrink(),
          data: (playlists) {
            if (playlists.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                child: Text(
                  '暂无歌单',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.3),
                  ),
                ),
              );
            }

            return Column(
              children: playlists.take(12).map((playlist) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 2),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () => context.go('/playlists/${playlist.id}'),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 7,
                        ),
                        child: Row(
                          children: <Widget>[
                            Icon(
                              Icons.queue_music_rounded,
                              size: 16,
                              color: Colors.white.withValues(alpha: 0.5),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                playlist.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.white.withValues(alpha: 0.75),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }
}
