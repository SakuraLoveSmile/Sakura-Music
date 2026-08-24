import 'dart:async';

import 'package:flutter/material.dart';

import '../../audio/audio_player_service.dart';
import '../../l10n/l10n.dart';

Future<void> showQueuePanel(
  BuildContext context,
  AudioPlayerService service,
) async {
  final isWide = MediaQuery.sizeOf(context).width >= 720;
  if (isWide) {
    await showGeneralDialog<void>(
      context: context,
      barrierLabel: context.l10n.queueTitle,
      barrierDismissible: true,
      barrierColor: Colors.black54,
      pageBuilder: (context, animation, secondaryAnimation) {
        return Align(
          alignment: Alignment.centerRight,
          child: Material(
            elevation: 12,
            child: SizedBox(
              width: 380,
              height: double.infinity,
              child: SafeArea(child: QueuePanel(service: service)),
            ),
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final offset = Tween<Offset>(
          begin: const Offset(1, 0),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut));
        return SlideTransition(position: offset, child: child);
      },
    );
    return;
  }

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => SizedBox(
      height: MediaQuery.sizeOf(context).height * .78,
      child: QueuePanel(service: service),
    ),
  );
}

class QueuePanel extends StatelessWidget {
  const QueuePanel({required this.service, super.key});

  final AudioPlayerService service;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<({List<PlayableItem> queue, int? index})>(
      stream: service.snapshot
          .map((state) => (queue: state.queue, index: state.currentIndex))
          .distinct(),
      initialData: (
        queue: service.currentSnapshot?.queue ?? const <PlayableItem>[],
        index: service.currentSnapshot?.currentIndex,
      ),
      builder: (context, snapshot) {
        final state =
            snapshot.data ?? (queue: const <PlayableItem>[], index: null);
        if (state.queue.isEmpty) {
          return Center(child: Text(context.l10n.emptyQueue));
        }
        return Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 12, 8),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      context.l10n.queueTitle,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  Text(context.l10n.queueSongCount(state.queue.length)),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ReorderableListView.builder(
                padding: const EdgeInsets.only(bottom: 24),
                itemCount: state.queue.length,
                // onReorderItem only exists in newer Flutter releases; keep
                // onReorder so the project also analyzes on older SDKs.
                // ignore: deprecated_member_use
                onReorder: (oldIndex, newIndex) {
                  if (newIndex > oldIndex) {
                    newIndex -= 1;
                  }
                  unawaited(service.moveItem(oldIndex, newIndex));
                },
                itemBuilder: (context, index) {
                  final item = state.queue[index];
                  final isCurrent = index == state.index;
                  return Dismissible(
                    key: ValueKey('${item.id}-$index'),
                    direction: DismissDirection.endToStart,
                    background: const _DeleteBackground(),
                    onDismissed: (_) => unawaited(service.removeAt(index)),
                    child: ListTile(
                      selected: isCurrent,
                      selectedTileColor: Theme.of(
                        context,
                      ).colorScheme.primaryContainer.withValues(alpha: .5),
                      leading: Icon(
                        isCurrent ? Icons.graphic_eq : Icons.drag_handle,
                        color: isCurrent
                            ? Theme.of(context).colorScheme.primary
                            : null,
                      ),
                      title: Text(
                        item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        [
                          item.artist,
                          item.album,
                        ].whereType<String>().join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () async {
                        await service.playAt(index);
                        if (context.mounted) {
                          Navigator.of(context).pop();
                        }
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _DeleteBackground extends StatelessWidget {
  const _DeleteBackground();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Theme.of(context).colorScheme.errorContainer,
      child: Align(
        alignment: Alignment.centerRight,
        child: Padding(
          padding: const EdgeInsets.only(right: 24),
          child: Icon(
            Icons.delete_outline,
            color: Theme.of(context).colorScheme.onErrorContainer,
          ),
        ),
      ),
    );
  }
}
