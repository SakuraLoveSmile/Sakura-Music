import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../audio/audio_player_service.dart';
import '../../../l10n/l10n.dart';
import 'lyrics_parser.dart';
import 'lyrics_service.dart';
import 'lyrics_share_dialog.dart';

class LyricsView extends ConsumerStatefulWidget {
  const LyricsView({
    required this.item,
    required this.position,
    required this.onSeek,
    this.textAlign = TextAlign.center,
    this.oled = false,
    super.key,
  });

  final PlayableItem item;
  final Duration position;
  final ValueChanged<Duration> onSeek;
  final TextAlign textAlign;
  final bool oled;

  @override
  ConsumerState<LyricsView> createState() => _LyricsViewState();
}

class _LyricsViewState extends ConsumerState<LyricsView> {
  final _scrollController = ScrollController();
  int _lastIndex = -1;
  List<GlobalKey> _lineKeys = <GlobalKey>[];
  bool _isUserScrolling = false;
  Timer? _userScrollTimer;
  int _closestCenterIndex = -1;

  @override
  void dispose() {
    _userScrollTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant LyricsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.id == widget.item.id) {
      return;
    }
    _lastIndex = -1;
    _isUserScrolling = false;
    _userScrollTimer?.cancel();
    _lineKeys = <GlobalKey>[];
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
  }

  void _onUserScroll(List<ParsedLyricsLine> lines) {
    _userScrollTimer?.cancel();
    _updateClosestLine(lines);
    if (!_isUserScrolling) {
      setState(() => _isUserScrolling = true);
    }
    _userScrollTimer = Timer(const Duration(milliseconds: 3200), () {
      if (mounted) {
        setState(() => _isUserScrolling = false);
      }
    });
  }

  void _updateClosestLine(List<ParsedLyricsLine> lines) {
    if (!mounted || _lineKeys.isEmpty) return;
    final viewportCenter = MediaQuery.sizeOf(context).height * 0.45;
    double minDistance = double.infinity;
    int closest = -1;

    for (int i = 0; i < _lineKeys.length; i++) {
      final keyContext = _lineKeys[i].currentContext;
      if (keyContext != null) {
        final box = keyContext.findRenderObject() as RenderBox?;
        if (box != null && box.hasSize) {
          final position = box.localToGlobal(Offset.zero);
          final lineCenter = position.dy + (box.size.height / 2);
          final distance = (lineCenter - viewportCenter).abs();
          if (distance < minDistance) {
            minDistance = distance;
            closest = i;
          }
        }
      }
    }

    if (closest != -1 && closest != _closestCenterIndex) {
      setState(() => _closestCenterIndex = closest);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lyrics = ref.watch(
      lyricsProvider(
        LyricsQuery(
          id: widget.item.id,
          artist: widget.item.artist,
          title: widget.item.title,
        ),
      ),
    );

    return lyrics.when(
      loading: () => Center(
        child: SizedBox.square(
          dimension: 28,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            color: widget.oled ? Colors.white : const Color(0xFF1E7BF6),
          ),
        ),
      ),
      error: (error, stackTrace) => _NoLyrics(oled: widget.oled),
      data: (lines) {
        if (lines == null || lines.isEmpty) {
          return _NoLyrics(oled: widget.oled);
        }
        final activeIndex = _activeIndex(lines, widget.position.inMilliseconds);
        if (_lineKeys.length != lines.length) {
          _lineKeys = List<GlobalKey>.generate(
            lines.length,
            (_) => GlobalKey(),
          );
        }

        // Auto-scroll when not manually dragging
        if (!_isUserScrolling && activeIndex != _lastIndex) {
          final firstPosition = _lastIndex == -1;
          _lastIndex = activeIndex;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted || activeIndex < 0) {
              return;
            }
            final keyContext = _lineKeys[activeIndex].currentContext;
            if (keyContext == null) {
              return;
            }
            Scrollable.ensureVisible(
              keyContext,
              alignment: 0.5,
              duration: firstPosition
                  ? Duration.zero
                  : const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
            );
          });
        }

        return Stack(
          alignment: Alignment.center,
          children: <Widget>[
            ShaderMask(
              shaderCallback: (rect) => const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[
                  Colors.transparent,
                  Colors.white,
                  Colors.white,
                  Colors.transparent,
                ],
                stops: <double>[0.0, 0.08, 0.92, 1.0],
              ).createShader(rect),
              blendMode: BlendMode.dstIn,
              child: NotificationListener<ScrollNotification>(
                onNotification: (notification) {
                  if (notification is ScrollUpdateNotification ||
                      notification is UserScrollNotification) {
                    _onUserScroll(lines);
                  }
                  return false;
                },
                child: SingleChildScrollView(
                  controller: _scrollController,
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.symmetric(
                    vertical: widget.oled ? 180 : 140,
                    horizontal: 24,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      for (int i = 0; i < lines.length; i++)
                        InkWell(
                          key: _lineKeys[i],
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => _seekToLine(lines[i]),
                          onLongPress: () => showLyricsShareDialog(
                            context,
                            item: widget.item,
                            lines: lines,
                            initialIndex: i,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: 8,
                              horizontal: 12,
                            ),
                            child: AnimatedDefaultTextStyle(
                              duration: const Duration(milliseconds: 220),
                              curve: Curves.easeOut,
                              style: _lineTextStyle(
                                i == activeIndex,
                                i < activeIndex,
                              ),
                              child: Text(
                                lines[i].text,
                                textAlign: widget.textAlign,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),

            // Drag-to-Seek Floating Center Alignment Play Indicator
            if (_isUserScrolling &&
                _closestCenterIndex >= 0 &&
                _closestCenterIndex < lines.length)
              Positioned(
                right: 16,
                child: AnimatedOpacity(
                  opacity: _isUserScrolling ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () {
                        HapticFeedback.mediumImpact();
                        _seekToLine(lines[_closestCenterIndex]);
                        setState(() => _isUserScrolling = false);
                        _userScrollTimer?.cancel();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E7BF6),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: const <BoxShadow>[
                            BoxShadow(
                              color: Colors.black45,
                              blurRadius: 10,
                              offset: Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Text(
                              _formatMs(lines[_closestCenterIndex].timeMs),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.play_arrow_rounded,
                              size: 16,
                              color: Colors.white,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  void _seekToLine(ParsedLyricsLine line) {
    widget.onSeek(Duration(milliseconds: line.timeMs));
  }

  static String _formatMs(int ms) {
    final totalSecs = (ms / 1000).round();
    final mins = totalSecs ~/ 60;
    final secs = totalSecs % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  TextStyle _lineTextStyle(bool active, bool passed) {
    final color = widget.oled
        ? (active
              ? Colors.white
              : passed
              ? Colors.white.withValues(alpha: 0.28)
              : Colors.white.withValues(alpha: 0.45))
        : (active
              ? Colors.white
              : passed
              ? Colors.white.withValues(alpha: 0.35)
              : Colors.white.withValues(alpha: 0.5));
    return TextStyle(
      color: color,
      fontWeight: active
          ? (widget.oled ? FontWeight.w900 : FontWeight.w800)
          : FontWeight.w500,
      fontSize: active ? (widget.oled ? 28 : 22) : 17,
      height: 1.45,
      letterSpacing: active ? 0.2 : 0.0,
    );
  }

  int _activeIndex(List<ParsedLyricsLine> lines, int positionMs) {
    var active = -1;
    var low = 0;
    var high = lines.length - 1;
    while (low <= high) {
      final middle = low + ((high - low) >> 1);
      if (lines[middle].timeMs <= positionMs) {
        active = middle;
        low = middle + 1;
      } else {
        high = middle - 1;
      }
    }
    return active;
  }
}

class CompactLyricsPreview extends ConsumerWidget {
  const CompactLyricsPreview({
    required this.item,
    required this.position,
    required this.onTap,
    super.key,
  });

  final PlayableItem item;
  final Duration position;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lyrics = ref.watch(
      lyricsProvider(
        LyricsQuery(id: item.id, artist: item.artist, title: item.title),
      ),
    );

    return lyrics.when(
      loading: () => const SizedBox.shrink(),
      error: (error, stack) => const SizedBox.shrink(),
      data: (lines) {
        if (lines == null || lines.isEmpty) {
          return const SizedBox.shrink();
        }
        final posMs = position.inMilliseconds;
        var active = 0;
        for (var i = 0; i < lines.length; i++) {
          if (lines[i].timeMs <= posMs) {
            active = i;
          } else {
            break;
          }
        }
        final currentText = lines[active].text;
        final nextText = active + 1 < lines.length
            ? lines[active + 1].text
            : '';

        return Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    currentText,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (nextText.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      nextText,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.4),
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _NoLyrics extends StatelessWidget {
  const _NoLyrics({this.oled = false});

  final bool oled;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: oled
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.white.withValues(alpha: 0.04),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.lyrics_outlined,
              size: 40,
              color: oled
                  ? Colors.white.withValues(alpha: 0.4)
                  : Colors.white38,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            context.l10n.noLyrics,
            style: TextStyle(
              color: oled
                  ? Colors.white.withValues(alpha: 0.5)
                  : Colors.white54,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
