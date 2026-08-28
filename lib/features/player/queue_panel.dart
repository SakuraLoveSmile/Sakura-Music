import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
            color: const Color(0xFF161720),
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
    backgroundColor: const Color(0xFF161720),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    showDragHandle: true,
    builder: (context) => SizedBox(
      height: MediaQuery.sizeOf(context).height * .78,
      child: QueuePanel(service: service),
    ),
  );
}

class QueuePanel extends StatefulWidget {
  const QueuePanel({required this.service, super.key});

  final AudioPlayerService service;

  @override
  State<QueuePanel> createState() => _QueuePanelState();
}

class _QueuePanelState extends State<QueuePanel> {
  final ScrollController _scrollController = ScrollController();
  int? _lastIndex;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToCurrent(int index) {
    if (!_scrollController.hasClients) return;
    const itemHeight = 68.0;
    final targetOffset = (index * itemHeight) - 120.0;
    _scrollController.animateTo(
      targetOffset.clamp(0.0, _scrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _confirmClearQueue(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF222530),
        title: Text(ctx.l10n.clearQueue, style: const TextStyle(color: Colors.white)),
        content: Text(
          ctx.l10n.clearQueueConfirm,
          style: const TextStyle(color: Colors.white70),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(ctx.l10n.cancel, style: const TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            child: Text(ctx.l10n.clearQueue),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      HapticFeedback.mediumImpact();
      await widget.service.setQueue(<PlayableItem>[]);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<({List<PlayableItem> queue, int? index})>(
      stream: widget.service.snapshot
          .map((state) => (queue: state.queue, index: state.currentIndex))
          .distinct(),
      initialData: (
        queue: widget.service.currentSnapshot?.queue ?? const <PlayableItem>[],
        index: widget.service.currentSnapshot?.currentIndex,
      ),
      builder: (context, snapshot) {
        final state =
            snapshot.data ?? (queue: const <PlayableItem>[], index: null);

        if (state.queue.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Icon(Icons.queue_music_rounded, size: 48, color: Colors.white24),
                const SizedBox(height: 12),
                Text(
                  context.l10n.emptyQueue,
                  style: const TextStyle(color: Colors.white54, fontSize: 14),
                ),
              ],
            ),
          );
        }

        // Auto scroll to current index on first load or index change
        if (state.index != null && state.index != _lastIndex) {
          _lastIndex = state.index;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && state.index != null) {
              _scrollToCurrent(state.index!);
            }
          });
        }

        return Column(
          children: <Widget>[
            // Header Row
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 12, 8),
              child: Row(
                children: <Widget>[
                  Text(
                    context.l10n.queueTitle,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${state.queue.length}',
                      style: const TextStyle(fontSize: 12, color: Colors.white70, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const Spacer(),
                  if (state.index != null)
                    IconButton(
                      tooltip: context.l10n.locatePlaying,
                      icon: const Icon(Icons.my_location_rounded, size: 20, color: Color(0xFF5BA4FF)),
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        _scrollToCurrent(state.index!);
                      },
                    ),
                  IconButton(
                    tooltip: context.l10n.clearQueue,
                    icon: const Icon(Icons.delete_sweep_outlined, size: 22, color: Colors.white54),
                    onPressed: () => _confirmClearQueue(context),
                  ),
                ],
              ),
            ),
            Divider(color: Colors.white.withValues(alpha: 0.08), height: 1),

            // Queue List
            Expanded(
              child: ReorderableListView.builder(
                scrollController: _scrollController,
                padding: const EdgeInsets.only(bottom: 24, top: 4),
                itemCount: state.queue.length,
                // ignore: deprecated_member_use
                onReorder: (oldIndex, newIndex) {
                  if (newIndex > oldIndex) {
                    newIndex -= 1;
                  }
                  unawaited(widget.service.moveItem(oldIndex, newIndex));
                },
                itemBuilder: (context, index) {
                  final item = state.queue[index];
                  final isCurrent = index == state.index;

                  return Dismissible(
                    key: ValueKey('${item.id}-$index'),
                    direction: DismissDirection.endToStart,
                    background: const _DeleteBackground(),
                    onDismissed: (_) => unawaited(widget.service.removeAt(index)),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: isCurrent
                            ? const Color(0xFF1E7BF6).withValues(alpha: 0.15)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        border: isCurrent
                            ? Border.all(color: const Color(0xFF1E7BF6).withValues(alpha: 0.4), width: 0.8)
                            : null,
                      ),
                      child: ListTile(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        leading: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: isCurrent
                                ? const Color(0xFF1E7BF6).withValues(alpha: 0.25)
                                : Colors.white.withValues(alpha: 0.04),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            isCurrent ? Icons.graphic_eq_rounded : Icons.drag_handle_rounded,
                            size: 18,
                            color: isCurrent ? const Color(0xFF5BA4FF) : Colors.white38,
                          ),
                        ),
                        title: Text(
                          item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
                            color: isCurrent ? const Color(0xFF5BA4FF) : Colors.white,
                          ),
                        ),
                        subtitle: Text(
                          [
                            item.artist,
                            item.album,
                          ].whereType<String>().join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: isCurrent
                                ? Colors.white.withValues(alpha: 0.7)
                                : Colors.white.withValues(alpha: 0.45),
                          ),
                        ),
                        onTap: () async {
                          HapticFeedback.lightImpact();
                          await widget.service.playAt(index);
                          if (context.mounted) {
                            Navigator.of(context).pop();
                          }
                        },
                      ),
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
    return Container(
      color: Colors.red.withValues(alpha: .7),
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 20),
      child: const Icon(Icons.delete, color: Colors.white),
    );
  }
}
