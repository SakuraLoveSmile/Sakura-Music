import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../data/lan_discovery_service.dart';
import '../../l10n/l10n.dart';
import 'widgets/server_config_form.dart';
import 'widgets/server_icons.dart';

/// Arguments passed to the config sub-page.
class AddServerConfigArgs {
  const AddServerConfigArgs({
    required this.protocol,
    this.prefillHost,
    this.prefillPort,
  });

  final ServerProtocolItem protocol;
  final String? prefillHost;
  final String? prefillPort;
}

/// Full-screen add-server page that mirrors the Apple native AddServerView:
/// a LAN discovery card and a manual grid of server types.
class AddServerScreen extends ConsumerStatefulWidget {
  const AddServerScreen({super.key});

  @override
  ConsumerState<AddServerScreen> createState() => _AddServerScreenState();
}

class _AddServerScreenState extends ConsumerState<AddServerScreen> {
  @override
  void initState() {
    super.initState();
    _ensurePermissions();
    // Kick off discovery once the first frame is laid out.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(lanDiscoveryProvider.notifier).start();
    });
  }

  Future<void> _ensurePermissions() async {
    try {
      if (Platform.isAndroid) {
        final sdk = (await DeviceInfoPlugin().androidInfo).version.sdkInt;
        if (sdk >= 33) {
          await Permission.nearbyWifiDevices.request();
        } else {
          await Permission.location.request();
        }
      }
    } catch (_) {
      // Missing permission only degrades discovery; the manual form still works.
    }
  }

  void _openProtocol(ServerProtocolItem item) {
    if (item.supported) {
      context.push(
        '/add-server/config',
        extra: AddServerConfigArgs(protocol: item),
      );
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.comingSoon)));
    }
  }

  void _openDiscovered(DiscoveredServer server) {
    final protocol = serverProtocols.firstWhere(
      (item) => item.name == server.displayType,
      orElse: () => serverProtocols.first,
    );
    context.push(
      '/add-server/config',
      extra: AddServerConfigArgs(
        protocol: protocol,
        prefillHost: server.host,
        prefillPort: server.port.toString(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final discovery = ref.watch(lanDiscoveryProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF121316),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            _TopBar(
              searching: discovery.searching,
              onBack: () {
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go('/welcome');
                }
              },
              onRefresh: () =>
                  ref.read(lanDiscoveryProvider.notifier).restart(),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
                children: <Widget>[
                  _SectionTitle(context.l10n.lanDiscovery),
                  const SizedBox(height: 12),
                  _LanDiscoveryCard(
                    state: discovery,
                    onTapServer: _openDiscovered,
                  ),
                  const SizedBox(height: 28),
                  _SectionTitle(context.l10n.manualAdd),
                  const SizedBox(height: 16),
                  GridView.extent(
                    maxCrossAxisExtent: 140,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    children: serverProtocols
                        .map(
                          (item) => _ProtocolCard(
                            item: item,
                            onTap: () => _openProtocol(item),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.searching,
    required this.onBack,
    required this.onRefresh,
  });

  final bool searching;
  final VoidCallback onBack;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: <Widget>[
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(
                Icons.chevron_left,
                size: 18,
                color: Colors.white,
              ),
              padding: EdgeInsets.zero,
              tooltip: context.l10n.back,
              onPressed: onBack,
            ),
          ),
          Expanded(
            child: Center(
              child: Text(
                context.l10n.addServerTitle,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: searching
                ? const Center(
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white70,
                      ),
                    ),
                  )
                : IconButton(
                    icon: const Icon(
                      Icons.refresh,
                      size: 18,
                      color: Colors.white70,
                    ),
                    padding: EdgeInsets.zero,
                    tooltip: context.l10n.lanRefresh,
                    onPressed: onRefresh,
                  ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _LanDiscoveryCard extends StatelessWidget {
  const _LanDiscoveryCard({required this.state, required this.onTapServer});

  final LanDiscoveryState state;
  final void Function(DiscoveredServer server) onTapServer;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 180,
      decoration: BoxDecoration(
        color: const Color(0xFF1A1B20),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
      ),
      child: state.searching && state.servers.isEmpty
          ? _Searching()
          : state.servers.isEmpty
          ? _EmptyLan()
          : _DiscoveredList(servers: state.servers, onTapServer: onTapServer),
    );
  }
}

class _Searching extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        const SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          context.l10n.searchingLan,
          style: const TextStyle(color: Colors.white, fontSize: 14),
        ),
      ],
    );
  }
}

class _EmptyLan extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Stack(
              alignment: Alignment.center,
              children: <Widget>[
                const Icon(
                  Icons.wifi_tethering,
                  size: 40,
                  color: Color(0x59FFFFFF),
                ),
                Transform.rotate(
                  angle: 0.785398,
                  child: Container(
                    width: 2.5,
                    height: 46,
                    color: Colors.white.withValues(alpha: 0.4),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              context.l10n.noServersFound,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              context.l10n.ensureSameNetwork,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DiscoveredList extends StatelessWidget {
  const _DiscoveredList({required this.servers, required this.onTapServer});

  final List<DiscoveredServer> servers;
  final void Function(DiscoveredServer server) onTapServer;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      itemCount: servers.length,
      separatorBuilder: (_, _) =>
          const Divider(height: 1, color: Color(0xFF242630)),
      itemBuilder: (context, index) {
        final server = servers[index];
        return ListTile(
          leading: ServerBrandIcon(
            id: server.displayType.toLowerCase(),
            size: 40,
          ),
          title: Text(
            server.name,
            style: const TextStyle(color: Colors.white, fontSize: 14),
          ),
          subtitle: Text(
            '${server.host}:${server.port}',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 12,
            ),
          ),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFF0A84FF).withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              server.displayType,
              style: const TextStyle(color: Color(0xFF0A84FF), fontSize: 11),
            ),
          ),
          onTap: () => onTapServer(server),
        );
      },
    );
  }
}

class _ProtocolCard extends StatelessWidget {
  const _ProtocolCard({required this.item, required this.onTap});

  final ServerProtocolItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          width: 120,
          height: 130,
          decoration: BoxDecoration(
            color: const Color(0xFF1A1B20),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              ServerBrandIcon(id: item.id, size: 58),
              const SizedBox(height: 14),
              Text(
                item.name,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Second-level page reached by tapping a supported server type or a
/// discovered LAN server. Embeds the shared [ServerConfigForm].
class AddServerConfigScreen extends ConsumerStatefulWidget {
  const AddServerConfigScreen({this.args, super.key});

  final AddServerConfigArgs? args;

  @override
  ConsumerState<AddServerConfigScreen> createState() =>
      _AddServerConfigScreenState();
}

class _AddServerConfigScreenState extends ConsumerState<AddServerConfigScreen> {
  @override
  Widget build(BuildContext context) {
    final args = widget.args;
    final protocol = args?.protocol ?? serverProtocols.first;

    return Scaffold(
      backgroundColor: const Color(0xFF121316),
      appBar: AppBar(
        backgroundColor: const Color(0xFF121316),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, color: Colors.white),
          tooltip: context.l10n.back,
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/welcome');
            }
          },
        ),
        title: Text(
          context.l10n.addServerTitle,
          style: const TextStyle(color: Colors.white, fontSize: 16),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ServerConfigForm(
                protocols: serverProtocols,
                fixedProtocol: protocol,
                prefillHost: args?.prefillHost,
                prefillPort: args?.prefillPort,
                onSaved: (_) {
                  context.go('/home');
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
