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
    super.key,
  });

  final PlayableItem item;
  final Duration position;
  final ValueChanged<Duration> onSeek;
  final TextAlign textAlign;

  @override
  ConsumerState<LyricsView> createState() => _LyricsViewState();
}

class _LyricsViewState extends ConsumerState<LyricsView> {
  final _scrollController = ScrollController();
  int _lastIndex = -1;

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
      loading: () => const Center(
        child: SizedBox.square(
          dimension: 28,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            color: Color(0xFF1E7BF6),
          ),
        ),
      ),
      error: (error, stackTrace) => const _NoLyrics(),
      data: (lines) {
        if (lines == null || lines.isEmpty) {
          return const _NoLyrics();
        }
        final activeIndex = _activeIndex(lines, widget.position.inMilliseconds);
        if (activeIndex != _lastIndex) {
          _lastIndex = activeIndex;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted || !_scrollController.hasClients || activeIndex < 0) {
              return;
            }
            final target = (activeIndex * 60.0 - 130).clamp(
              0.0,
              _scrollController.position.maxScrollExtent,
            );
            _scrollController.animateTo(
              target,
              duration: const Duration(milliseconds: 320),
              curve: Curves.easeInOutCubic,
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
          child: ListView.separated(
            controller: _scrollController,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(vertical: 140, horizontal: 24),
            itemCount: lines.length,
            separatorBuilder: (context, index) => const SizedBox(height: 14),
            itemBuilder: (context, index) {
              final active = index == activeIndex;
              final isPassed = index < activeIndex;
              return InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => _seekToLine(lines[index]),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 12,
                  ),
                  child: AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOut,
                    style: TextStyle(
                      color: active
                          ? Colors.white
                          : isPassed
                              ? Colors.white.withValues(alpha: 0.35)
                              : Colors.white.withValues(alpha: 0.5),
                      fontWeight: active ? FontWeight.w800 : FontWeight.w500,
                      fontSize: active ? 22 : 16.5,
                      height: 1.45,
                      letterSpacing: active ? 0.2 : 0.0,
                    ),
                    child: Text(
                      lines[index].text,
                      textAlign: widget.textAlign,
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  void _seekToLine(ParsedLyricsLine line) {
    widget.onSeek(Duration(milliseconds: line.timeMs));
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
        LyricsQuery(
          id: item.id,
          artist: item.artist,
          title: item.title,
        ),
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
        final nextText = active + 1 < lines.length ? lines[active + 1].text : '';

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
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.08),
                ),
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
  const _NoLyrics();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.lyrics_outlined,
              size: 40,
              color: Colors.white38,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            context.l10n.noLyrics,
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
