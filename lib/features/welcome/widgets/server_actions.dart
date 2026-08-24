import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/db/app_database.dart';
import '../../../data/server_repository.dart';
import '../../../l10n/l10n.dart';

/// Shared delete flow used by the desktop sidebar and the mobile server
/// picker. Returns true when the server was actually removed.
Future<bool> confirmAndDeleteServer(
  BuildContext context,
  WidgetRef ref,
  Server server,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: const Color(0xFF22252E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(dialogContext.l10n.deleteServerTitle, style: const TextStyle(color: Colors.white)),
      content: Text(
        dialogContext.l10n.deleteServerConfirm(server.name),
        style: const TextStyle(color: Colors.white70),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(dialogContext.l10n.cancel, style: const TextStyle(color: Colors.white70)),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFFF453A),
          ),
          child: Text(dialogContext.l10n.delete),
        ),
      ],
    ),
  );

  if (confirmed != true) {
    return false;
  }
  await ref.read(serverRepositoryProvider).deleteServer(server.id);
  if (ref.read(selectedServerIdProvider) == server.id) {
    ref.read(selectedServerIdProvider.notifier).state = null;
  }
  return true;
}
