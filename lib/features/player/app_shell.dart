import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:subsonic_api/subsonic_api.dart';

import '../../audio/audio_player_provider.dart';
import '../../core/providers.dart';
import '../../data/db/app_database.dart';
import '../../data/server_repository.dart';
import '../../l10n/l10n.dart';
import 'mini_player_bar.dart';

class _NavMenuItem {
  const _NavMenuItem({
    required this.index,
    required this.path,
    required this.icon,
    required this.selectedIcon,
  });

  final int index;
  final String path;
  final IconData icon;
  final IconData selectedIcon;
}

/// Bottom-bar destinations map to shell branches: favorites lives at branch
/// 6 and artists at branch 3 (this is not the order they appear in the bar).
const List<int> _bottomNavBranches = <int>[0, 1, 2, 6, 3];

/// Nav labels resolve from the route path so the menu items stay const.
String _navLabel(BuildContext context, String path) {
  return switch (path) {
    '/home' => context.l10n.navDiscover,
    '/songs' => context.l10n.navSongs,
    '/albums' => context.l10n.navAlbums,
    '/artists' => context.l10n.navArtists,
    '/genres' => context.l10n.navGenres,
    '/radios' => context.l10n.navRadios,
    '/favorites' => context.l10n.navFavorites,
    '/downloads' => context.l10n.navDownloads,
    _ => '',
  };
}

const _discoverItem = _NavMenuItem(
  index: 0,
  path: '/home',
  icon: Icons.explore_outlined,
  selectedIcon: Icons.explore_rounded,
);

const _libraryItems = <_NavMenuItem>[
  _NavMenuItem(
    index: 1,
    path: '/songs',
    icon: Icons.music_note_outlined,
    selectedIcon: Icons.music_note_rounded,
  ),
  _NavMenuItem(
    index: 2,
    path: '/albums',
    icon: Icons.album_outlined,
    selectedIcon: Icons.album_rounded,
  ),
  _NavMenuItem(
    index: 3,
    path: '/artists',
    icon: Icons.person_outline_rounded,
    selectedIcon: Icons.person_rounded,
  ),
  _NavMenuItem(
    index: 4,
    path: '/genres',
    icon: Icons.category_outlined,
    selectedIcon: Icons.category_rounded,
  ),
  _NavMenuItem(
    index: 5,
    path: '/radios',
    icon: Icons.radio_outlined,
    selectedIcon: Icons.radio_rounded,
  ),
];

const _personalItems = <_NavMenuItem>[
  _NavMenuItem(
    index: 6,
    path: '/favorites',
    icon: Icons.favorite_border_rounded,
    selectedIcon: Icons.favorite_rounded,
  ),
  _NavMenuItem(
    index: 7,
    path: '/downloads',
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
    final bottomNavIndex = _bottomNavBranches.indexOf(currentIndex);
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
            child: SafeArea(
              bottom: false,
              child: Column(
                children: <Widget>[
                  // Top Global Action Header
                  _TopActionBar(
                    isWide: isWide,
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
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            MiniPlayerBar(service: ref.watch(audioPlayerProvider)),
            if (!isWide)
              NavigationBar(
                // The bar shows a subset of the shell branches: favorites
                // lives at branch 6 and artists at branch 3, so destination
                // indexes must map through _bottomNavBranches.
                selectedIndex: bottomNavIndex < 0 ? 0 : bottomNavIndex,
                onDestinationSelected: (index) {
                  final branch = _bottomNavBranches[index];
                  navigationShell.goBranch(
                    branch,
                    initialLocation: branch == navigationShell.currentIndex,
                  );
                },
                destinations: <NavigationDestination>[
                  NavigationDestination(
                    icon: const Icon(Icons.explore_outlined),
                    selectedIcon: const Icon(Icons.explore_rounded),
                    label: context.l10n.navDiscover,
                  ),
                  NavigationDestination(
                    icon: const Icon(Icons.music_note_outlined),
                    selectedIcon: const Icon(Icons.music_note_rounded),
                    label: context.l10n.navSongs,
                  ),
                  NavigationDestination(
                    icon: const Icon(Icons.album_outlined),
                    selectedIcon: const Icon(Icons.album_rounded),
                    label: context.l10n.navAlbums,
                  ),
                  NavigationDestination(
                    icon: const Icon(Icons.favorite_border_rounded),
                    selectedIcon: const Icon(Icons.favorite_rounded),
                    label: context.l10n.navLiked,
                  ),
                  NavigationDestination(
                    icon: const Icon(Icons.person_outline_rounded),
                    selectedIcon: const Icon(Icons.person_rounded),
                    label: context.l10n.navArtists,
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _TopActionBar extends StatelessWidget {
  const _TopActionBar({
    required this.isWide,
    required this.activeServer,
    required this.serversAsync,
    required this.onSwitchServer,
  });

  final bool isWide;
  final Server? activeServer;
  final AsyncValue<List<Server>> serversAsync;
  final void Function(Server) onSwitchServer;

  String _formatServerSubtitle(Server server) {
    final uri = Uri.tryParse(server.baseUrl);
    final host = uri != null && uri.host.isNotEmpty
        ? (uri.hasPort && uri.port != 80 && uri.port != 443
            ? '${uri.host}:${uri.port}'
            : uri.host)
        : server.baseUrl;
    return '$host · ${server.username}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: Color(0xFF131418),
        border: Border(
          bottom: BorderSide(color: Color(0xFF1F2128), width: 0.8),
        ),
      ),
      child: Row(
        children: <Widget>[
          if (!isWide)
            PopupMenuButton<String>(
              tooltip: context.l10n.browse,
              offset: const Offset(0, 42),
              color: const Color(0xFF22252E),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              onSelected: (path) => context.go(path),
              itemBuilder: (context) => <PopupMenuEntry<String>>[
                PopupMenuItem<String>(
                  value: '/artists',
                  child: Row(
                    children: <Widget>[
                      const Icon(
                        Icons.person_rounded,
                        size: 18,
                        color: Colors.white70,
                      ),
                      const SizedBox(width: 10),
                      Text(context.l10n.navArtists),
                    ],
                  ),
                ),
                PopupMenuItem<String>(
                  value: '/genres',
                  child: Row(
                    children: <Widget>[
                      const Icon(
                        Icons.category_rounded,
                        size: 18,
                        color: Colors.white70,
                      ),
                      const SizedBox(width: 10),
                      Text(context.l10n.navGenres),
                    ],
                  ),
                ),
                PopupMenuItem<String>(
                  value: '/radios',
                  child: Row(
                    children: <Widget>[
                      const Icon(
                        Icons.radio_rounded,
                        size: 18,
                        color: Colors.white70,
                      ),
                      const SizedBox(width: 10),
                      Text(context.l10n.navRadios),
                    ],
                  ),
                ),
                PopupMenuItem<String>(
                  value: '/playlists',
                  child: Row(
                    children: <Widget>[
                      const Icon(
                        Icons.queue_music_rounded,
                        size: 18,
                        color: Colors.white70,
                      ),
                      const SizedBox(width: 10),
                      Text(context.l10n.playlistsLabel),
                    ],
                  ),
                ),
              ],
              child: Container(
                height: 34,
                width: 34,
                decoration: BoxDecoration(
                  color: const Color(0xFF1E2028),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                child: const Icon(
                  Icons.explore_outlined,
                  size: 18,
                  color: Colors.white70,
                ),
              ),
            ),
          const Spacer(),

          // Server Selector Button
          PopupMenuButton<dynamic>(
            tooltip: context.l10n.switchLibrary,
            offset: const Offset(0, 42),
            color: const Color(0xFF22252E),
            elevation: 8,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            onSelected: (value) {
              if (value is Server) {
                onSwitchServer(value);
              } else if (value == 'manage_servers') {
                context.go('/welcome');
              }
            },
            itemBuilder: (context) {
              final servers = serversAsync.value ?? <Server>[];
              return <PopupMenuEntry<dynamic>>[
                PopupMenuItem<dynamic>(
                  enabled: false,
                  child: Row(
                    children: <Widget>[
                      const Icon(
                        Icons.cloud_outlined,
                        size: 16,
                        color: Color(0xFF5BA4FF),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        context.l10n.connectedLibraries,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF5BA4FF),
                          letterSpacing: 0.2,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1.5,
                        ),
                        decoration: BoxDecoration(
                          color:
                              const Color(0xFF1E7BF6).withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${servers.length}',
                          style: const TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF5BA4FF),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const PopupMenuDivider(height: 1),
                if (servers.isEmpty)
                  PopupMenuItem<dynamic>(
                    enabled: false,
                    child: Text(
                      context.l10n.noServers,
                      style:
                          const TextStyle(color: Colors.white38, fontSize: 13),
                    ),
                  )
                else
                  ...servers.map((s) {
                    final isCurrent = activeServer?.id == s.id;
                    return PopupMenuItem<dynamic>(
                      value: s,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: <Widget>[
                            Container(
                              width: 30,
                              height: 30,
                              decoration: BoxDecoration(
                                color: isCurrent
                                    ? const Color(0xFF1E7BF6)
                                        .withValues(alpha: 0.18)
                                    : Colors.white.withValues(alpha: 0.05),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                isCurrent
                                    ? Icons.cloud_done_rounded
                                    : Icons.dns_outlined,
                                size: 16,
                                color: isCurrent
                                    ? const Color(0xFF5BA4FF)
                                    : Colors.white60,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  Text(
                                    s.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: isCurrent
                                          ? const Color(0xFF5BA4FF)
                                          : Colors.white,
                                      fontWeight: isCurrent
                                          ? FontWeight.bold
                                          : FontWeight.w500,
                                      fontSize: 13.5,
                                    ),
                                  ),
                                  const SizedBox(height: 1),
                                  Text(
                                    _formatServerSubtitle(s),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color:
                                          Colors.white.withValues(alpha: 0.4),
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (isCurrent)
                              const Padding(
                                padding: EdgeInsets.only(left: 6),
                                child: Icon(
                                  Icons.check_circle_rounded,
                                  size: 16,
                                  color: Color(0xFF1E7BF6),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  }),
                const PopupMenuDivider(height: 1),
                PopupMenuItem<dynamic>(
                  value: 'manage_servers',
                  child: Row(
                    children: <Widget>[
                      const Icon(
                        Icons.settings_suggest_outlined,
                        size: 17,
                        color: Colors.white70,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        context.l10n.serverManagement,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ];
            },
            child: Container(
              height: 34,
              padding: const EdgeInsets.symmetric(horizontal: 11),
              decoration: BoxDecoration(
                color: const Color(0xFF1E2028),
                borderRadius: BorderRadius.circular(17),
                border: Border.all(
                  color: activeServer != null
                      ? const Color(0xFF1E7BF6).withValues(alpha: 0.25)
                      : Colors.white.withValues(alpha: 0.08),
                  width: 1.0,
                ),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: activeServer != null
                          ? const Color(0xFF34C759)
                          : const Color(0xFFFF9500),
                      shape: BoxShape.circle,
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: (activeServer != null
                                  ? const Color(0xFF34C759)
                                  : const Color(0xFFFF9500))
                              .withValues(alpha: 0.6),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 7),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 140),
                    child: Text(
                      activeServer?.name ?? context.l10n.notConnected,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 16,
                    color: Colors.white.withValues(alpha: 0.6),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Search Button
          Container(
            height: 34,
            width: 34,
            decoration: BoxDecoration(
              color: const Color(0xFF1E2028),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
            child: IconButton(
              icon: const Icon(
                Icons.search_rounded,
                size: 18,
                color: Colors.white70,
              ),
              tooltip: context.l10n.search,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(width: 34, height: 34),
              onPressed: () => context.go('/search'),
            ),
          ),
          const SizedBox(width: 8),

          // Settings Button
          Container(
            height: 34,
            width: 34,
            decoration: BoxDecoration(
              color: const Color(0xFF1E2028),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
            child: IconButton(
              icon: const Icon(
                Icons.settings_outlined,
                size: 18,
                color: Colors.white70,
              ),
              tooltip: context.l10n.settings,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(width: 34, height: 34),
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
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                child: Row(
                  children: <Widget>[
                    const Icon(
                      Icons.music_note_rounded,
                      color: Color(0xFF1E7BF6),
                      size: 22,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      context.l10n.appName,
                      style: const TextStyle(
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
                        context.l10n.search,
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
                    context: context,
                    item: _discoverItem,
                    isSelected: currentIndex == _discoverItem.index,
                    onTap: () => navigationShell.goBranch(_discoverItem.index),
                  ),

                  const SizedBox(height: 16),

                  // 2. 音乐库 Group
                  _buildSectionHeader(context.l10n.librarySection),
                  ..._libraryItems.map(
                    (item) => _buildNavTile(
                      context: context,
                      item: item,
                      isSelected: currentIndex == item.index,
                      onTap: () => navigationShell.goBranch(item.index),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 3. 个人 Group
                  _buildSectionHeader(context.l10n.personalSection),
                  ..._personalItems.map(
                    (item) => _buildNavTile(
                      context: context,
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

            // Bottom Server Info & Settings
            Container(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              decoration: const BoxDecoration(
                border: Border(
                  top: BorderSide(color: Color(0xFF1F2128), width: 1.0),
                ),
              ),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => context.go('/welcome'),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 6,
                        ),
                        child: Row(
                          children: <Widget>[
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: activeServer != null
                                    ? const Color(0xFF34C759)
                                    : const Color(0xFFFF9500),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                activeServer?.name ?? context.l10n.notConnected,
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
                              Icons.unfold_more_rounded,
                              size: 15,
                              color: Colors.white.withValues(alpha: 0.35),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(
                      Icons.settings_outlined,
                      size: 18,
                      color: Colors.white60,
                    ),
                    tooltip: context.l10n.settings,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints.tightFor(
                      width: 32,
                      height: 32,
                    ),
                    onPressed: () => context.go('/settings'),
                  ),
                ],
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
    required BuildContext context,
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
                    _navLabel(context, item.path),
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
                context.l10n.myPlaylists,
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
                  context.l10n.noPlaylists,
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
