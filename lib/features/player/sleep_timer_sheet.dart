import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../audio/sleep_timer_controller.dart';
import '../../l10n/l10n.dart';

/// Sleep timer bottom sheet shared by the full player screen and the mini
/// player bar. Both entry points drive the same [SleepTimerController], so
/// there is exactly one timer per playback service.
void showSleepTimerSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: const Color(0xFF1B1D26),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetContext) => Consumer(
      builder: (context, ref, _) {
        final timer = ref.watch(sleepTimerControllerProvider);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            child: ListenableBuilder(
              listenable: timer,
              builder: (context, _) => Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      const Icon(
                        Icons.timer_outlined,
                        color: Color(0xFF1E7BF6),
                        size: 22,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        sheetContext.l10n.sleepTimerTitle,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const Spacer(),
                      if (timer.isActive) _activeBadge(timer),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: <int>[15, 30, 45, 60, 90].map((minutes) {
                      final isActive =
                          timer.phase == SleepTimerPhase.countdown &&
                          (timer.remaining.inMinutes == minutes ||
                              (timer.remaining.inMinutes == 0 &&
                                  minutes == 15));
                      return InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () {
                          timer.start(Duration(minutes: minutes));
                          Navigator.of(sheetContext).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                context.l10n.sleepTimerSet(minutes),
                              ),
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: isActive
                                ? const Color(0xFF1E7BF6)
                                : const Color(0xFF242733),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isActive
                                  ? const Color(0xFF1E7BF6)
                                  : Colors.white.withValues(alpha: 0.08),
                            ),
                          ),
                          child: Text(
                            sheetContext.l10n.minutesLabel(minutes),
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: isActive
                                  ? FontWeight.bold
                                  : FontWeight.w600,
                              fontSize: 13.5,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      Icons.music_off_outlined,
                      color: timer.isEndOfTrack
                          ? const Color(0xFF1E7BF6)
                          : Colors.white70,
                    ),
                    title: Text(
                      sheetContext.l10n.endOfSong,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                    ),
                    trailing: timer.isEndOfTrack
                        ? const Icon(
                            Icons.check_rounded,
                            color: Color(0xFF1E7BF6),
                            size: 20,
                          )
                        : null,
                    onTap: () {
                      timer.startEndOfTrack();
                      Navigator.of(sheetContext).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(context.l10n.endOfSong)),
                      );
                    },
                  ),
                  const Divider(color: Colors.white12, height: 1),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(
                      Icons.close_rounded,
                      color: Colors.redAccent,
                    ),
                    title: Text(
                      sheetContext.l10n.cancelSleepTimer,
                      style: const TextStyle(
                        color: Colors.redAccent,
                        fontSize: 14,
                      ),
                    ),
                    onTap: timer.isActive
                        ? () {
                            timer.cancel();
                            Navigator.of(sheetContext).pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(context.l10n.sleepTimerCancelled),
                              ),
                            );
                          }
                        : null,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    ),
  );
}

Widget _activeBadge(SleepTimerController timer) {
  final String label;
  switch (timer.phase) {
    case SleepTimerPhase.countdown:
      final remaining = timer.remaining;
      label = remaining.inMinutes >= 1
          ? '${remaining.inMinutes}m'
          : '${remaining.inSeconds}s';
    case SleepTimerPhase.endOfTrack:
      label = '♫';
    case SleepTimerPhase.fading:
      label = '...';
    case SleepTimerPhase.inactive:
      return const SizedBox.shrink();
  }
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: const Color(0xFF1E7BF6).withValues(alpha: 0.2),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Text(
      label,
      style: const TextStyle(
        color: Color(0xFF5BA4FF),
        fontSize: 12,
        fontWeight: FontWeight.bold,
      ),
    ),
  );
}
