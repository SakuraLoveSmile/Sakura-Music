import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:subsonic_api/subsonic_api.dart';

import '../../../audio/audio_player_service.dart';
import '../../../core/artwork_palette.dart';
import '../../../core/providers.dart';
import '../../../l10n/l10n.dart';
import '../audio_stream_inspector_sheet.dart';
import '../../shared/media_widgets.dart';

class VinylTurntableStage extends StatefulWidget {
  const VinylTurntableStage({
    required this.item,
    required this.service,
    required this.playing,
    required this.palette,
    required this.isStarred,
    this.onTap,
    super.key,
  });

  final PlayableItem item;
  final AudioPlayerService service;
  final bool playing;
  final ArtworkPalette? palette;
  final bool isStarred;
  final VoidCallback? onTap;

  @override
  State<VinylTurntableStage> createState() => _VinylTurntableStageState();
}

class _VinylTurntableStageState extends State<VinylTurntableStage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _rotationController;
  double _swipeDragDx = 0.0;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20), // 33 1/3 RPM feel
    );
    if (widget.playing) {
      _rotationController.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant VinylTurntableStage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.playing != oldWidget.playing) {
      if (widget.playing) {
        _rotationController.repeat();
      } else {
        _rotationController.stop(canceled: false);
      }
    }
  }

  @override
  void dispose() {
    _rotationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableHeight = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : 520.0;
        final discDimension = math.min(
          320.0,
          math.max(160.0, availableHeight * 0.50),
        );
        final glowColor = (widget.palette?.vibrant ?? const Color(0xFF1E7BF6))
            .withValues(alpha: widget.playing ? 0.35 : 0.08);

        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            // Turntable Container with Vinyl Disc and Stylus Arm
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: widget.onTap,
              onHorizontalDragUpdate: (details) {
                setState(() => _swipeDragDx += details.primaryDelta ?? 0);
              },
              onHorizontalDragEnd: (details) {
                final velocity = details.primaryVelocity ?? 0;
                if (_swipeDragDx < -45 || velocity < -250) {
                  HapticFeedback.mediumImpact();
                  widget.service.next();
                } else if (_swipeDragDx > 45 || velocity > 250) {
                  HapticFeedback.mediumImpact();
                  widget.service.previous();
                }
                setState(() => _swipeDragDx = 0.0);
              },
              onHorizontalDragCancel: () {
                setState(() => _swipeDragDx = 0.0);
              },
              child: Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: <Widget>[
                  // Vinyl Base Shadow & Outer Glow
                  Transform.translate(
                    offset: Offset(_swipeDragDx * 0.4, 0),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 320),
                      width: discDimension,
                      height: discDimension,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: <BoxShadow>[
                          BoxShadow(
                            color: glowColor,
                            blurRadius: widget.playing ? 32 : 12,
                            spreadRadius: widget.playing ? -2 : -6,
                            offset: const Offset(0, 8),
                          ),
                          BoxShadow(
                            color: Colors.black.withValues(
                              alpha: widget.playing ? 0.6 : 0.35,
                            ),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      // Rotating Vinyl Record Disc
                      child: RotationTransition(
                        turns: _rotationController,
                        child: CustomPaint(
                          painter: _VinylDiscPainter(),
                          child: Center(
                            // Center Album Artwork Sticker
                            child: SizedBox.square(
                              dimension: discDimension * 0.44,
                              child: Stack(
                                alignment: Alignment.center,
                                children: <Widget>[
                                  ClipOval(
                                    child: widget.item.artworkUrl == null
                                        ? Container(
                                            color: const Color(0xFF22242D),
                                            child: const Icon(
                                              Icons.album_rounded,
                                              size: 40,
                                              color: Colors.white24,
                                            ),
                                          )
                                        : CachedNetworkImage(
                                            imageUrl: widget.item.artworkUrl!,
                                            cacheKey:
                                                widget.item.artworkCacheKey,
                                            fit: BoxFit.cover,
                                            memCacheWidth: 250,
                                            memCacheHeight: 250,
                                          ),
                                  ),
                                  // Center Spindle Hole
                                  Container(
                                    width: 14,
                                    height: 14,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: const Color(0xFF0E0F13),
                                      border: Border.all(
                                        color: Colors.white30,
                                        width: 1.5,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Tonearm / Stylus Arm with smooth animation
                  Positioned(
                    top: -16,
                    right: (discDimension * 0.05) - (_swipeDragDx * 0.2),
                    child: IgnorePointer(
                      child: AnimatedRotation(
                        turns: widget.playing ? 0.0 : -0.065,
                        alignment: const Alignment(0.6, -0.8),
                        duration: const Duration(milliseconds: 450),
                        curve: Curves.easeInOutCubic,
                        child: CustomPaint(
                          size: Size(
                            discDimension * 0.38,
                            discDimension * 0.65,
                          ),
                          painter: _TonearmPainter(),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Track Title & Star Row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: <Widget>[
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
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          [
                                widget.item.artist,
                                widget.item.album,
                              ].whereType<String>().join(' · ').isEmpty
                              ? context.l10n.nowPlaying
                              : [
                                  widget.item.artist,
                                  widget.item.album,
                                ].whereType<String>().join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.6),
                            fontSize: 13,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        const SizedBox(height: 6),
                        // Audio Quality Badge
                        Align(
                          alignment: Alignment.centerLeft,
                          child: AudioStreamQualityBadge(item: widget.item),
                        ),
                      ],
                    ),
                  ),
                  Consumer(
                    builder: (context, ref, _) => StarButton(
                      isStarred: widget.isStarred,
                      size: 22,
                      onPressed: () async {
                        try {
                          await ref
                              .read(starredProvider.notifier)
                              .toggleSong(
                                Song(
                                  id: widget.item.id,
                                  title: widget.item.title,
                                  artist: widget.item.artist,
                                  album: widget.item.album,
                                ),
                              );
                        } catch (err) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  context.l10n.starFailed(err.toString()),
                                ),
                              ),
                            );
                          }
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Custom painter that renders realistic vinyl record grooves and glossy reflections.
class _VinylDiscPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // 1. Vinyl Body base
    final basePaint = Paint()
      ..shader = RadialGradient(
        colors: const <Color>[
          Color(0xFF141519),
          Color(0xFF0D0E12),
          Color(0xFF1A1B22),
          Color(0xFF0B0C0F),
        ],
        stops: const <double>[0.0, 0.45, 0.75, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, basePaint);

    // 2. Micro-grooves
    final groovePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.6
      ..color = Colors.white.withValues(alpha: 0.04);

    for (double r = radius * 0.48; r < radius * 0.96; r += 3.5) {
      canvas.drawCircle(center, r, groovePaint);
    }

    // 3. Subtle metallic highlight sheen (Bowtie reflection)
    final sheenPaint = Paint()
      ..shader = SweepGradient(
        colors: <Color>[
          Colors.white.withValues(alpha: 0.0),
          Colors.white.withValues(alpha: 0.07),
          Colors.white.withValues(alpha: 0.0),
          Colors.white.withValues(alpha: 0.08),
          Colors.white.withValues(alpha: 0.0),
        ],
        stops: const <double>[0.0, 0.25, 0.5, 0.75, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, sheenPaint);

    // 4. Outer rim border
    final rimPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = Colors.white.withValues(alpha: 0.12);
    canvas.drawCircle(center, radius - 0.75, rimPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Custom painter for the mechanical Stylus Tonearm.
class _TonearmPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final pivot = Offset(size.width * 0.8, size.height * 0.12);

    // Pivot Base
    final basePaint = Paint()..color = const Color(0xFF282B36);
    canvas.drawCircle(pivot, 14, basePaint);

    final pivotCap = Paint()..color = const Color(0xFF8E93A6);
    canvas.drawCircle(pivot, 8, pivotCap);

    // Metallic Tonearm Rod
    final armPath = Path()
      ..moveTo(pivot.dx, pivot.dy)
      ..lineTo(size.width * 0.45, size.height * 0.55)
      ..lineTo(size.width * 0.25, size.height * 0.90);

    final armPaint = Paint()
      ..color = const Color(0xFFB5BAC9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(armPath, armPaint);

    // Cartridge / Headshell at the tip
    final headCenter = Offset(size.width * 0.25, size.height * 0.90);
    final headRect = Rect.fromCenter(center: headCenter, width: 10, height: 16);
    final headPaint = Paint()..color = const Color(0xFF1E7BF6);
    canvas.drawRRect(
      RRect.fromRectAndRadius(headRect, const Radius.circular(2)),
      headPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
