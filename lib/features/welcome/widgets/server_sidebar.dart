import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../data/db/app_database.dart';
import '../../../data/server_repository.dart';
import 'add_server_dialog.dart';
import '../../../l10n/l10n.dart';
import 'server_actions.dart';

class ServerSidebar extends ConsumerStatefulWidget {
  const ServerSidebar({
    required this.isWelcomeSelected,
    required this.onSelectWelcome,
    required this.onAddServer,
    super.key,
  });

  final bool isWelcomeSelected;
  final VoidCallback onSelectWelcome;
  final VoidCallback onAddServer;

  @override
  ConsumerState<ServerSidebar> createState() => _ServerSidebarState();
}

class _ServerSidebarState extends ConsumerState<ServerSidebar> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final serversAsync = ref.watch(serversProvider);
    final activeServer = ref.watch(activeServerProvider);

    return Container(
      width: 240,
      decoration: const BoxDecoration(
        color: Color(0xFF141519),
        border: Border(right: BorderSide(color: Color(0xFF22242B), width: 1)),
      ),
      child: SafeArea(
        right: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            // macOS traffic lights top bar (if desktop macOS or desktop)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
              child: Row(
                children: <Widget>[
                  if (Platform.isMacOS) ...[
                    _TrafficLightDot(color: const Color(0xFFFF5F56)),
                    const SizedBox(width: 8),
                    _TrafficLightDot(color: const Color(0xFFFFBD2E)),
                    const SizedBox(width: 8),
                    _TrafficLightDot(color: const Color(0xFF27C93F)),
                  ] else ...[
                    const Icon(
                      Icons.music_note_rounded,
                      color: Color(0xFF0A84FF),
                      size: 22,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      context.l10n.appName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Search box
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              child: Container(
                height: 34,
                decoration: BoxDecoration(
                  color: const Color(0xFF24262E),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: (val) => setState(() => _searchQuery = val.trim()),
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: context.l10n.search,
                    hintStyle: TextStyle(
                      color: Colors.white.withValues(alpha: 0.38),
                      fontSize: 13,
                    ),
                    prefixIcon: Icon(
                      Icons.search,
                      size: 17,
                      color: Colors.white.withValues(alpha: 0.4),
                    ),
                    prefixIconConstraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 14),
                            color: Colors.white54,
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 10),

            // Navigation items
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                children: <Widget>[
                  // 🎉 欢迎 button (highlighted when active)
                  _SidebarItem(
                    icon: Icons.celebration_rounded,
                    title: context.l10n.welcomeNav,
                    isSelected: widget.isWelcomeSelected,
                    onTap: widget.onSelectWelcome,
                  ),

                  const SizedBox(height: 16),

                  // Saved servers header
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        Text(
                          context.l10n.serversSection,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.4),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                        InkWell(
                          onTap: widget.onAddServer,
                          borderRadius: BorderRadius.circular(4),
                          child: Padding(
                            padding: const EdgeInsets.all(2),
                            child: Icon(
                              Icons.add,
                              size: 16,
                              color: Colors.white.withValues(alpha: 0.6),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Saved servers list
                  serversAsync.when(
                    loading: () => const Padding(
                      padding: EdgeInsets.all(12),
                      child: Center(
                        child: SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    ),
                    error: (err, stack) => Padding(
                      padding: const EdgeInsets.all(10),
                      child: Text(
                        context.l10n.loadFailed(err.toString()),
                        style: const TextStyle(
                          color: Color(0xFFFF6961),
                          fontSize: 12,
                        ),
                      ),
                    ),
                    data: (servers) {
                      final filtered = _searchQuery.isEmpty
                          ? servers
                          : servers
                                .where(
                                  (s) =>
                                      s.name.toLowerCase().contains(
                                        _searchQuery.toLowerCase(),
                                      ) ||
                                      s.baseUrl.toLowerCase().contains(
                                        _searchQuery.toLowerCase(),
                                      ),
                                )
                                .toList(growable: false);

                      if (filtered.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          child: Text(
                            servers.isEmpty
                                ? context.l10n.noServers
                                : context.l10n.noSearchResults,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.3),
                              fontSize: 12,
                            ),
                          ),
                        );
                      }

                      return Column(
                        children: filtered
                            .map((server) {
                              final isServerActive =
                                  !widget.isWelcomeSelected &&
                                  activeServer?.id == server.id;

                              return _ServerSidebarTile(
                                server: server,
                                isSelected: isServerActive,
                                onTap: () {
                                  ref
                                      .read(selectedServerIdProvider.notifier)
                                      .state = server
                                      .id;
                                  context.go('/home');
                                },
                                onEdit: () {
                                  AddServerDialog.show(
                                    context,
                                    serverToEdit: server,
                                  );
                                },
                                onDelete: () => confirmAndDeleteServer(
                                  context,
                                  ref,
                                  server,
                                ),
                              );
                            })
                            .toList(growable: false),
                      );
                    },
                  ),
                ],
              ),
            ),

            // Bottom Add Server footer
            Padding(
              padding: const EdgeInsets.all(12),
              child: OutlinedButton.icon(
                onPressed: widget.onAddServer,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: const Color(0xFF1E2028),
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: Text(
                  context.l10n.addServer,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrafficLightDot extends StatelessWidget {
  const _TrafficLightDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({
    required this.icon,
    required this.title,
    required this.isSelected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFF0A84FF) : Colors.transparent,
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
                  icon,
                  size: 18,
                  color: isSelected
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.7),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: isSelected
                          ? FontWeight.w600
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
}

class _ServerSidebarTile extends StatelessWidget {
  const _ServerSidebarTile({
    required this.server,
    required this.isSelected,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  final Server server;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 2),
      decoration: BoxDecoration(
        color: isSelected
            ? const Color(0xFF0A84FF).withValues(alpha: 0.25)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(
              children: <Widget>[
                Icon(
                  Icons.dns_outlined,
                  size: 17,
                  color: isSelected
                      ? const Color(0xFF0A84FF)
                      : Colors.white.withValues(alpha: 0.6),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        server.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.w500,
                          color: isSelected ? Colors.white : Colors.white70,
                        ),
                      ),
                      Text(
                        server.baseUrl.replaceFirst(RegExp(r'https?://'), ''),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.white.withValues(alpha: 0.35),
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  icon: Icon(
                    Icons.more_vert,
                    size: 16,
                    color: Colors.white.withValues(alpha: 0.4),
                  ),
                  tooltip: context.l10n.more,
                  padding: EdgeInsets.zero,
                  color: const Color(0xFF22252E),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  onSelected: (val) {
                    if (val == 'edit') onEdit();
                    if (val == 'delete') onDelete();
                  },
                  itemBuilder: (context) => <PopupMenuEntry<String>>[
                    PopupMenuItem<String>(
                      value: 'edit',
                      child: Row(
                        children: <Widget>[
                          const Icon(
                            Icons.edit_outlined,
                            size: 16,
                            color: Colors.white70,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            context.l10n.edit,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuItem<String>(
                      value: 'delete',
                      child: Row(
                        children: <Widget>[
                          const Icon(
                            Icons.delete_outline,
                            size: 16,
                            color: Color(0xFFFF453A),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            context.l10n.delete,
                            style: const TextStyle(
                              color: Color(0xFFFF453A),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
