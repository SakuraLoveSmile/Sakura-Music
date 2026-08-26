import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/update/update_models.dart';
import '../../../core/update/update_providers.dart';
import '../../../l10n/l10n.dart';

Future<void> showUpdateDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    useRootNavigator: true,
    barrierDismissible: false,
    builder: (_) => const UpdateDialog(),
  );
}

class UpdateDialog extends ConsumerWidget {
  const UpdateDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(updateControllerProvider);
    final release = state.release;
    if (release == null) {
      return const SizedBox.shrink();
    }

    final controller = ref.read(updateControllerProvider.notifier);
    final isIOS = Platform.isIOS;
    final isBusy =
        state.status == UpdateStatus.downloading ||
        state.status == UpdateStatus.installing;

    return AlertDialog(
      backgroundColor: const Color(0xFF1E2028),
      title: Row(
        children: <Widget>[
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFF1E7BF6).withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.system_update_rounded,
              color: Color(0xFF6EA8FF),
              size: 21,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              context.l10n.updateAvailable,
              style: const TextStyle(color: Colors.white, fontSize: 18),
            ),
          ),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 430),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                release.version,
                style: const TextStyle(
                  color: Color(0xFF6EA8FF),
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 14),
              if (release.notes.trim().isNotEmpty) ...[
                Text(
                  context.l10n.releaseNotes,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  release.notes.trim(),
                  style: const TextStyle(
                    color: Colors.white70,
                    height: 1.45,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 16),
              ],
              _assetInfo(context, state.asset),
              if (state.status == UpdateStatus.downloading) ...[
                const SizedBox(height: 18),
                LinearProgressIndicator(
                  value: state.totalBytes > 0
                      ? state.progress.clamp(0, 1)
                      : null,
                  minHeight: 5,
                  borderRadius: BorderRadius.circular(5),
                ),
                const SizedBox(height: 8),
                Text(
                  state.totalBytes > 0
                      ? context.l10n.updateDownloadingPercent(
                          (state.progress * 100).round(),
                        )
                      : context.l10n.updateDownloading,
                  style: const TextStyle(color: Colors.white60, fontSize: 12),
                ),
              ],
              if (state.status == UpdateStatus.installing) ...[
                const SizedBox(height: 18),
                const LinearProgressIndicator(minHeight: 5),
                const SizedBox(height: 8),
                Text(
                  context.l10n.preparingInstall,
                  style: const TextStyle(color: Colors.white60, fontSize: 12),
                ),
              ],
              if (state.status == UpdateStatus.error &&
                  state.errorMessage != null) ...[
                const SizedBox(height: 16),
                Text(
                  state.errorMessage!,
                  style: const TextStyle(
                    color: Color(0xFFFF8A80),
                    height: 1.4,
                    fontSize: 13,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: _actions(
        context,
        ref,
        controller,
        state,
        isIOS: isIOS,
        isBusy: isBusy,
      ),
    );
  }

  List<Widget> _actions(
    BuildContext context,
    WidgetRef ref,
    UpdateController controller,
    UpdateState state, {
    required bool isIOS,
    required bool isBusy,
  }) {
    if (state.status == UpdateStatus.downloading) {
      return <Widget>[
        TextButton(
          onPressed: controller.cancelDownload,
          child: Text(context.l10n.cancelDownload),
        ),
      ];
    }
    if (state.status == UpdateStatus.installing) {
      return const <Widget>[];
    }
    if (state.status == UpdateStatus.downloaded) {
      return <Widget>[
        TextButton(
          onPressed: () {
            controller.dismiss();
            Navigator.of(context).pop();
          },
          child: Text(context.l10n.installLater),
        ),
        FilledButton(
          onPressed: () async {
            await controller.install();
            if (context.mounted &&
                ref.read(updateControllerProvider).status ==
                    UpdateStatus.idle) {
              Navigator.of(context).pop();
            }
          },
          child: Text(
            Platform.isAndroid
                ? context.l10n.install
                : context.l10n.restartAndInstall,
          ),
        ),
      ];
    }
    if (state.status == UpdateStatus.error) {
      return <Widget>[
        TextButton(
          onPressed: () async {
            await controller.openReleasePage();
          },
          child: Text(context.l10n.openDownloadPage),
        ),
        if (state.asset != null)
          FilledButton(
            onPressed: controller.retryDownload,
            child: Text(context.l10n.retry),
          ),
      ];
    }
    if (isIOS) {
      return <Widget>[
        TextButton(
          onPressed: () {
            controller.dismiss();
            Navigator.of(context).pop();
          },
          child: Text(context.l10n.later),
        ),
        FilledButton(
          onPressed: () async {
            await controller.openReleasePage();
            if (context.mounted) Navigator.of(context).pop();
          },
          child: Text(context.l10n.openDownload),
        ),
      ];
    }
    if (state.asset == null) {
      return <Widget>[
        TextButton(
          onPressed: () {
            controller.dismiss();
            Navigator.of(context).pop();
          },
          child: Text(context.l10n.close),
        ),
        FilledButton(
          onPressed: () async {
            await controller.openReleasePage();
            if (context.mounted) Navigator.of(context).pop();
          },
          child: Text(context.l10n.openDownloadPage),
        ),
      ];
    }
    return <Widget>[
      TextButton(
        onPressed: () {
          controller.dismiss();
          Navigator.of(context).pop();
        },
        child: Text(context.l10n.later),
      ),
      FilledButton(
        onPressed: isBusy ? null : controller.startDownload,
        child: Text(context.l10n.updateNow),
      ),
    ];
  }

  Widget _assetInfo(BuildContext context, ReleaseAsset? asset) {
    if (asset == null) {
      return Text(
        context.l10n.noMatchingAsset,
        style: const TextStyle(
          color: Colors.white60,
          height: 1.4,
          fontSize: 12,
        ),
      );
    }
    return Text(
      context.l10n.assetInfo(asset.name, _formatBytes(asset.sizeBytes)),
      style: const TextStyle(color: Colors.white54, fontSize: 12),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}
