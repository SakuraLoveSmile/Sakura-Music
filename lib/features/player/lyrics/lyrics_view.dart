import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../audio/audio_player_service.dart';
import 'lyrics_parser.dart';
import 'lyrics_service.dart';

class LyricsView extends ConsumerStatefulWidget {
  const LyricsView({
    required this.item,
    required this.position,
    required this.onSeek,
    super.key,
  });

  final PlayableItem item;
  final Duration position;
  final ValueChanged<Duration> onSeek;

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
      loading: () => const Center(child: CircularProgressIndicator()),
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
            final target = (activeIndex * 56.0 - 120).clamp(
              0.0,
              _scrollController.position.maxScrollExtent,
            );
            _scrollController.animateTo(
              target,
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOut,
            );
          });
        }
        return ListView.separated(
          controller: _scrollController,
          padding: const EdgeInsets.symmetric(vertical: 120, horizontal: 20),
          itemCount: lines.length,
          separatorBuilder: (context, index) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final active = index == activeIndex;
            return AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 180),
              style: Theme.of(context).textTheme.titleMedium!.copyWith(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: active ? 1 : .46),
                fontWeight: active ? FontWeight.w700 : FontWeight.w400,
                fontSize: active ? 20 : 16,
                height: 1.45,
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => _seekToLine(lines[index]),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(lines[index].text, textAlign: TextAlign.center),
                ),
              ),
            );
          },
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

class _NoLyrics extends StatelessWidget {
  const _NoLyrics();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            Icons.lyrics_outlined,
            size: 56,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 12),
          const Text('这首歌还没有可用歌词'),
        ],
      ),
    );
  }
}
