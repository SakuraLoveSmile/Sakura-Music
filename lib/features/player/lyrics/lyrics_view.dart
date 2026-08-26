import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../audio/audio_player_service.dart';
import '../../../l10n/l10n.dart';
import 'lyrics_parser.dart';
import 'lyrics_service.dart';

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

  @override
  void dispose() {
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
    _lineKeys = <GlobalKey>[];
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
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
        if (activeIndex != _lastIndex) {
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

        return ShaderMask(
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
                        child: Text(lines[i].text, textAlign: widget.textAlign),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _seekToLine(ParsedLyricsLine line) {
    widget.onSeek(Duration(milliseconds: line.timeMs));
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
