import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import '../../../audio/audio_player_service.dart';
import '../../../l10n/l10n.dart';
import 'lyrics_parser.dart';

enum LyricsCardTheme {
  gradient,
  frosted,
  oled,
}

Future<void> showLyricsShareDialog(
  BuildContext context, {
  required PlayableItem item,
  required List<ParsedLyricsLine> lines,
  int initialIndex = 0,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xFF15171F),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => LyricsShareDialog(
      item: item,
      lines: lines,
      initialIndex: initialIndex,
    ),
  );
}

class LyricsShareDialog extends StatefulWidget {
  const LyricsShareDialog({
    required this.item,
    required this.lines,
    this.initialIndex = 0,
    super.key,
  });

  final PlayableItem item;
  final List<ParsedLyricsLine> lines;
  final int initialIndex;

  @override
  State<LyricsShareDialog> createState() => _LyricsShareDialogState();
}

class _LyricsShareDialogState extends State<LyricsShareDialog> {
  final GlobalKey _cardKey = GlobalKey();
  late final Set<int> _selectedIndices;
  LyricsCardTheme _theme = LyricsCardTheme.gradient;

  @override
  void initState() {
    super.initState();
    _selectedIndices = <int>{widget.initialIndex.clamp(0, widget.lines.length - 1)};
  }

  void _toggleLine(int index) {
    setState(() {
      if (_selectedIndices.contains(index)) {
        if (_selectedIndices.length > 1) {
          _selectedIndices.remove(index);
        }
      } else {
        if (_selectedIndices.length < 5) {
          _selectedIndices.add(index);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.l10n.maxSelectedLines),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    });
  }

  String _formatSelectedLyrics() {
    final sorted = _selectedIndices.toList()..sort();
    final buffer = StringBuffer();
    buffer.writeln('🎵 ${widget.item.title} - ${widget.item.artist ?? context.l10n.unknownArtist}');
    buffer.writeln('━━━━━━━━━━━━━━━');
    for (final i in sorted) {
      buffer.writeln(widget.lines[i].text);
    }
    buffer.writeln('━━━━━━━━━━━━━━━');
    buffer.writeln('🌸 SakuraMusic');
    return buffer.toString();
  }

  Future<void> _copyText() async {
    final text = _formatSelectedLyrics();
    await Clipboard.setData(ClipboardData(text: text));
    HapticFeedback.lightImpact();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.lyricsCopied),
          duration: const Duration(seconds: 2),
        ),
      );
      Navigator.of(context).pop();
    }
  }

  Future<void> _saveOrShareImage() async {
    try {
      final boundary = _cardKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData != null && mounted) {
        HapticFeedback.mediumImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.imageSaved),
            duration: const Duration(seconds: 2),
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (_) {
      // Fallback
    }
  }

  @override
  Widget build(BuildContext context) {
    final sortedIndices = _selectedIndices.toList()..sort();

    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.88,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // Drag handle & Header
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 12),

            Row(
              children: <Widget>[
                const Icon(Icons.palette_outlined, color: Color(0xFF5BA4FF), size: 20),
                const SizedBox(width: 8),
                Text(
                  context.l10n.lyricsCard,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white60, size: 20),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints.tightFor(width: 32, height: 32),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Style Selector Chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: <Widget>[
                  _buildThemeChip(
                    theme: LyricsCardTheme.gradient,
                    label: context.l10n.themeGradient,
                    icon: Icons.auto_awesome_rounded,
                  ),
                  const SizedBox(width: 8),
                  _buildThemeChip(
                    theme: LyricsCardTheme.frosted,
                    label: context.l10n.themeFrosted,
                    icon: Icons.blur_on_rounded,
                  ),
                  const SizedBox(width: 8),
                  _buildThemeChip(
                    theme: LyricsCardTheme.oled,
                    label: context.l10n.themeOled,
                    icon: Icons.contrast_rounded,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Card Live Preview (Wrapped in RepaintBoundary)
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  child: RepaintBoundary(
                    key: _cardKey,
                    child: _buildCardPreview(sortedIndices),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Line selector strip (Tap to add/remove lines)
            SizedBox(
              height: 38,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: widget.lines.length,
                separatorBuilder: (context, index) => const SizedBox(width: 6),
                itemBuilder: (context, index) {
                  final isSelected = _selectedIndices.contains(index);
                  return FilterChip(
                    label: Text(
                      'L${index + 1}',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected ? Colors.white : Colors.white60,
                      ),
                    ),
                    selected: isSelected,
                    selectedColor: const Color(0xFF1E7BF6),
                    backgroundColor: Colors.white.withValues(alpha: 0.06),
                    onSelected: (_) => _toggleLine(index),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    visualDensity: VisualDensity.compact,
                  );
                },
              ),
            ),
            const SizedBox(height: 14),

            // Action Buttons
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _copyText,
                    icon: const Icon(Icons.copy_rounded, size: 17),
                    label: Text(context.l10n.copyLyricsText),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _saveOrShareImage,
                    icon: const Icon(Icons.share_rounded, size: 17),
                    label: Text(context.l10n.saveImage),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E7BF6),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeChip({
    required LyricsCardTheme theme,
    required String label,
    required IconData icon,
  }) {
    final isSelected = _theme == theme;
    return ChoiceChip(
      avatar: Icon(
        icon,
        size: 14,
        color: isSelected ? Colors.white : Colors.white70,
      ),
      label: Text(label),
      selected: isSelected,
      onSelected: (val) {
        if (val) setState(() => _theme = theme);
      },
      selectedColor: const Color(0xFF1E7BF6),
      backgroundColor: Colors.white.withValues(alpha: 0.06),
      labelStyle: TextStyle(
        fontSize: 12,
        color: isSelected ? Colors.white : Colors.white70,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }

  Widget _buildCardPreview(List<int> sortedIndices) {
    final BoxDecoration decoration;
    switch (_theme) {
      case LyricsCardTheme.gradient:
        decoration = BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[Color(0xFF1E2A4A), Color(0xFF151926), Color(0xFF221626)],
          ),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: Colors.black45,
              blurRadius: 18,
              offset: Offset(0, 6),
            ),
          ],
        );
      case LyricsCardTheme.frosted:
        decoration = BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: const Color(0xFF222634).withValues(alpha: 0.88),
          border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: Colors.black38,
              blurRadius: 16,
              offset: Offset(0, 6),
            ),
          ],
        );
      case LyricsCardTheme.oled:
        decoration = BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: Colors.black,
          border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: Colors.black87,
              blurRadius: 20,
              offset: Offset(0, 6),
            ),
          ],
        );
    }

    return Container(
      width: 320,
      padding: const EdgeInsets.all(22),
      decoration: decoration,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Header: Artwork + Track metadata
          Row(
            children: <Widget>[
              SizedBox.square(
                dimension: 44,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: widget.item.artworkUrl == null
                      ? Container(
                          color: const Color(0xFF2E3240),
                          child: const Icon(Icons.album_rounded, size: 24, color: Colors.white30),
                        )
                      : CachedNetworkImage(
                          imageUrl: widget.item.artworkUrl!,
                          cacheKey: widget.item.artworkCacheKey,
                          fit: BoxFit.cover,
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      widget.item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.item.artist ?? context.l10n.unknownArtist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Quote Icon
          Icon(
            Icons.format_quote_rounded,
            size: 28,
            color: const Color(0xFF5BA4FF).withValues(alpha: 0.7),
          ),
          const SizedBox(height: 4),

          // Lyric Lines
          for (final i in sortedIndices)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                widget.lines[i].text,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15.5,
                  fontWeight: FontWeight.w600,
                  height: 1.45,
                  letterSpacing: 0.1,
                  shadows: _theme == LyricsCardTheme.oled
                      ? null
                      : <Shadow>[
                          Shadow(
                            color: Colors.black.withValues(alpha: 0.5),
                            blurRadius: 4,
                          ),
                        ],
                ),
              ),
            ),
          const SizedBox(height: 16),

          // Divider & Watermark Footer
          Divider(color: Colors.white.withValues(alpha: 0.1), height: 1),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              const Text(
                '🌸 SakuraMusic',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.white54,
                  letterSpacing: 0.3,
                ),
              ),
              const Spacer(),
              Text(
                widget.item.album ?? '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.white.withValues(alpha: 0.35),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
