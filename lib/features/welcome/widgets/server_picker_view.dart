import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../data/db/app_database.dart';
import '../../../data/server_repository.dart';
import 'add_server_dialog.dart';
import '../../../l10n/l10n.dart';
import 'feature_cards.dart';
import 'server_actions.dart';
import 'server_url.dart';

/// Phone-width media-library picker. It replaces the marketing page as the
/// main content of `/welcome` on narrow screens: servers are the primary
/// object here, and adding one no longer jumps into the app.
class ServerPickerView extends ConsumerWidget {
  const ServerPickerView({
    required this.onAddServer,
    this.highlightServerId,
    super.key,
  });

  final VoidCallback onAddServer;
  final int? highlightServerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final serversAsync = ref.watch(serversProvider);

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 20, 0),
            child: Row(
              children: <Widget>[
                const Spacer(),
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E2028),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: IconButton(
                    icon: const Icon(
                      Icons.settings_outlined,
                      size: 19,
                      color: Colors.white70,
                    ),
                    tooltip: context.l10n.settings,
                    onPressed: () => context.push('/settings'),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: serversAsync.when(
              loading: () => const Center(
                child: SizedBox.square(
                  dimension: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
              error: (error, stackTrace) => _ErrorPane(message: '$error'),
              data: (servers) {
                if (servers.isEmpty) {
                  return _EmptyPicker(onAddServer: onAddServer);
                }
                return _PickerContent(
                  servers: servers,
                  highlightServerId: highlightServerId,
                  onAddServer: onAddServer,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _PickerContent extends ConsumerWidget {
  const _PickerContent({
    required this.servers,
    required this.onAddServer,
    this.highlightServerId,
  });

  final List<Server> servers;
  final VoidCallback onAddServer;
  final int? highlightServerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeServer = ref.watch(activeServerProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 0),
          child: Column(
            children: <Widget>[
              const WelcomeAppLogo(size: 64),
              const SizedBox(height: 14),
              Text(
                context.l10n.chooseLibrary,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.4,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                context.l10n.serverCount(servers.length),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.45),
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            itemCount: servers.length,
            separatorBuilder: (context, index) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final server = servers[index];
              return _ServerCard(
                server: server,
                isActive: activeServer?.id == server.id,
                highlight: highlightServerId == server.id,
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: FilledButton.icon(
            onPressed: onAddServer,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF0A84FF),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            icon: const Icon(Icons.add_rounded, size: 20),
            label: Text(
              context.l10n.addServer,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }
}

class _ServerCard extends ConsumerWidget {
  const _ServerCard({
    required this.server,
    required this.isActive,
    required this.highlight,
  });

  final Server server;
  final bool isActive;
  final bool highlight;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final serverType = inferServerType(server.baseUrl);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: const Color(0xFF181A20),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isActive || highlight
              ? const Color(0xFF0A84FF)
              : Colors.white.withValues(alpha: 0.07),
          width: isActive || highlight ? 1.6 : 1,
        ),
        boxShadow: highlight
            ? <BoxShadow>[
                BoxShadow(
                  color: const Color(0xFF0A84FF).withValues(alpha: 0.35),
                  blurRadius: 22,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () {
            ref.read(selectedServerIdProvider.notifier).state = server.id;
            context.go('/home');
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: <Widget>[
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0A84FF).withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.dns_rounded,
                    color: Color(0xFF0A84FF),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Flexible(
                            child: Text(
                              server.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          if (serverType != null) ...<Widget>[
                            const SizedBox(width: 6),
                            _ServerTypeBadge(type: serverType),
                          ],
                          if (isActive) ...<Widget>[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF30D158).withValues(
                                  alpha: 0.16,
                                ),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                context.l10n.currentBadge,
                                style: const TextStyle(
                                  color: Color(0xFF32D74B),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        server.baseUrl.replaceFirst(RegExp(r'https?://'), ''),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.38),
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  icon: Icon(
                    Icons.more_vert,
                    size: 18,
                    color: Colors.white.withValues(alpha: 0.4),
                  ),
                  tooltip: context.l10n.more,
                  padding: EdgeInsets.zero,
                  color: const Color(0xFF22252E),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  onSelected: (value) {
                    if (value == 'edit') {
                      AddServerDialog.show(context, serverToEdit: server);
                    } else if (value == 'delete') {
                      confirmAndDeleteServer(context, ref, server);
                    }
                  },
                  itemBuilder: (context) => <PopupMenuEntry<String>>[
                    PopupMenuItem<String>(
                      value: 'edit',
                      child: Row(
                        children: <Widget>[
                          const Icon(Icons.edit_outlined, size: 16, color: Colors.white70),
                          const SizedBox(width: 8),
                          Text(context.l10n.edit, style: const TextStyle(color: Colors.white, fontSize: 13)),
                        ],
                      ),
                    ),
                    PopupMenuItem<String>(
                      value: 'delete',
                      child: Row(
                        children: <Widget>[
                          const Icon(Icons.delete_outline, size: 16, color: Color(0xFFFF453A)),
                          const SizedBox(width: 8),
                          Text(context.l10n.delete, style: const TextStyle(color: Color(0xFFFF453A), fontSize: 13)),
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

class _ServerTypeBadge extends StatelessWidget {
  const _ServerTypeBadge({required this.type});

  final String type;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFF5856D6).withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        type,
        style: const TextStyle(
          color: Color(0xFF9E9BF2),
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _EmptyPicker extends StatelessWidget {
  const _EmptyPicker({required this.onAddServer});

  final VoidCallback onAddServer;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[Color(0xFF0A84FF), Color(0xFF0055B3)],
                ),
                borderRadius: BorderRadius.circular(32),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: const Color(0xFF0A84FF).withValues(alpha: 0.3),
                    blurRadius: 30,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: const Icon(
                Icons.library_music_rounded,
                color: Colors.white,
                size: 52,
              ),
            ),
            const SizedBox(height: 22),
            Text(
              context.l10n.emptyPickerTitle,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 19,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              context.l10n.emptyPickerDesc,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 13.5,
              ),
            ),
            const SizedBox(height: 26),
            FilledButton.icon(
              onPressed: onAddServer,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF0A84FF),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 26,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
              icon: const Icon(Icons.add_circle, size: 20),
              label: Text(
                context.l10n.addFirstServer,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorPane extends StatelessWidget {
  const _ErrorPane({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          context.l10n.loadFailed(message),
          textAlign: TextAlign.center,
          style: const TextStyle(color: Color(0xFFFF6961), fontSize: 13),
        ),
      ),
    );
  }
}
