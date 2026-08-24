import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/db/app_database.dart';
import '../../../l10n/l10n.dart';
import 'server_config_form.dart';
import 'server_url.dart';

/// Protocols offered in the legacy edit / add dialog (free mode). The new
/// full-screen add-server page uses its own grid of protocols.
final List<ServerProtocolItem> _dialogProtocols = <ServerProtocolItem>[
  ServerProtocolItem(
    id: 'Navidrome',
    name: 'Navidrome',
    defaultPort: serverTypeDefaultPorts['Navidrome'] ?? '4533',
  ),
  ServerProtocolItem(
    id: 'Subsonic',
    name: 'Subsonic',
    defaultPort: serverTypeDefaultPorts['Subsonic'] ?? '4040',
  ),
  ServerProtocolItem(
    id: 'OpenSubsonic',
    name: 'OpenSubsonic',
    defaultPort: serverTypeDefaultPorts['OpenSubsonic'] ?? '4040',
  ),
  ServerProtocolItem(
    id: 'Emby',
    name: 'Emby',
    defaultPort: serverTypeDefaultPorts['Emby'] ?? '8096',
  ),
];

class AddServerDialog extends ConsumerStatefulWidget {
  const AddServerDialog({
    this.serverToEdit,
    super.key,
  });

  final Server? serverToEdit;

  static Future<bool?> show(BuildContext context, {Server? serverToEdit}) {
    return showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.7),
      builder: (context) => AddServerDialog(serverToEdit: serverToEdit),
    );
  }

  @override
  ConsumerState<AddServerDialog> createState() => _AddServerDialogState();
}

class _AddServerDialogState extends ConsumerState<AddServerDialog> {
  @override
  Widget build(BuildContext context) {
    final isEditing = widget.serverToEdit != null;

    return Dialog(
      backgroundColor: const Color(0xFF1C1E24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(
          color: Colors.white.withValues(alpha: 0.12),
          width: 1,
        ),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 24, 28, 24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: const Color(0xFF0A84FF).withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.dns_rounded,
                        color: Color(0xFF0A84FF),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        isEditing
                            ? context.l10n.editServer
                            : context.l10n.addServer,
                        style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white70),
                      tooltip: context.l10n.close,
                      onPressed: () => Navigator.of(context).pop(false),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                ServerConfigForm(
                  protocols: _dialogProtocols,
                  serverToEdit: widget.serverToEdit,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
