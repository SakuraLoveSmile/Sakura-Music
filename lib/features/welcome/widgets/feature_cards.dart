import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';

/// App Logo component matching the glowing squircle in the screenshot
class WelcomeAppLogo extends StatelessWidget {
  const WelcomeAppLogo({this.size = 88, super.key});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.26),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[Color(0xFF0A84FF), Color(0xFF0055B3)],
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: const Color(0xFF0A84FF).withValues(alpha: 0.35),
            blurRadius: 28,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Center(
        child: CustomPaint(
          size: Size(size * 0.58, size * 0.58),
          painter: _LogoPainter(),
        ),
      ),
    );
  }
}

class _LogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final notePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    // Draw music note
    final noteHeadCenter = Offset(size.width * 0.42, size.height * 0.46);
    final noteHeadRadius = size.width * 0.15;
    canvas.save();
    canvas.translate(noteHeadCenter.dx, noteHeadCenter.dy);
    canvas.rotate(-math.pi / 8);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset.zero,
        width: noteHeadRadius * 2.2,
        height: noteHeadRadius * 1.6,
      ),
      notePaint,
    );
    canvas.restore();

    // Stem
    final stemPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = size.width * 0.11
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final stemX = size.width * 0.55;
    canvas.drawLine(
      Offset(stemX, size.height * 0.44),
      Offset(stemX, size.height * 0.12),
      stemPaint,
    );

    // Flag
    final flagPath = Path()
      ..moveTo(stemX, size.height * 0.12)
      ..cubicTo(
        size.width * 0.75,
        size.height * 0.14,
        size.width * 0.85,
        size.height * 0.30,
        size.width * 0.72,
        size.height * 0.42,
      )
      ..cubicTo(
        size.width * 0.78,
        size.height * 0.28,
        size.width * 0.70,
        size.height * 0.20,
        stemX,
        size.height * 0.22,
      )
      ..close();
    canvas.drawPath(flagPath, notePaint);

    // Waves underneath
    final wavePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.95)
      ..strokeWidth = size.width * 0.08
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final wavePath = Path();
    wavePath.moveTo(size.width * 0.15, size.height * 0.78);
    wavePath.quadraticBezierTo(
      size.width * 0.28,
      size.height * 0.70,
      size.width * 0.38,
      size.height * 0.78,
    );
    wavePath.quadraticBezierTo(
      size.width * 0.50,
      size.height * 0.86,
      size.width * 0.62,
      size.height * 0.78,
    );
    wavePath.quadraticBezierTo(
      size.width * 0.74,
      size.height * 0.70,
      size.width * 0.85,
      size.height * 0.78,
    );
    canvas.drawPath(wavePath, wavePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Top-left card: 多源支持 (Multi-source support)
class MultiSourceCard extends StatelessWidget {
  const MultiSourceCard({super.key});

  @override
  Widget build(BuildContext context) {
    return _FeatureCardContainer(
      borderColor: const Color(0xFF1E3A5F),
      watermark: Positioned(
        right: -10,
        top: -12,
        child: Opacity(
          opacity: 0.08,
          child: Icon(
            Icons.dns_rounded,
            size: 130,
            color: const Color(0xFF388AF6).withValues(alpha: 0.8),
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _IconBadge(
            icon: Icons.dns_rounded,
            color: const Color(0xFF0A84FF),
            backgroundColor: const Color(0xFF0A84FF).withValues(alpha: 0.16),
          ),
          const SizedBox(height: 18),
          Text(
            context.l10n.featureMultiSource,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            context.l10n.featureMultiSourceDesc,
            style: TextStyle(
              fontSize: 13,
              color: Colors.white.withValues(alpha: 0.6),
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

/// Top-middle card: 无损播放 (Lossless Playback)
class LosslessCard extends StatelessWidget {
  const LosslessCard({super.key});

  @override
  Widget build(BuildContext context) {
    return _FeatureCardContainer(
      borderColor: const Color(0xFF193345),
      watermark: Positioned(
        right: -25,
        top: 0,
        child: Opacity(
          opacity: 0.09,
          child: Icon(
            Icons.show_chart_rounded,
            size: 135,
            color: const Color(0xFF00C7BE).withValues(alpha: 0.8),
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _IconBadge(
            icon: Icons.show_chart_rounded,
            color: const Color(0xFF30D158),
            backgroundColor: const Color(0xFF30D158).withValues(alpha: 0.16),
          ),
          const SizedBox(height: 18),
          Text(
            context.l10n.featureLossless,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            context.l10n.featureLosslessDesc,
            style: TextStyle(
              fontSize: 13,
              color: Colors.white.withValues(alpha: 0.6),
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

/// Top-right card: 原生体验 (Native Experience)
class NativeExperienceCard extends StatelessWidget {
  const NativeExperienceCard({super.key});

  @override
  Widget build(BuildContext context) {
    return _FeatureCardContainer(
      borderColor: const Color(0xFF382A1B),
      watermark: Positioned(
        right: -15,
        top: -10,
        child: Opacity(
          opacity: 0.08,
          child: Icon(
            Icons.flutter_dash,
            size: 125,
            color: const Color(0xFFFF9F0A).withValues(alpha: 0.8),
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _IconBadge(
            icon: Icons.flutter_dash,
            color: const Color(0xFFFF9F0A),
            backgroundColor: const Color(0xFFFF9F0A).withValues(alpha: 0.16),
          ),
          const SizedBox(height: 18),
          Text(
            context.l10n.featureNative,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            context.l10n.featureNativeDesc,
            style: TextStyle(
              fontSize: 13,
              color: Colors.white.withValues(alpha: 0.6),
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

/// Bottom full-width banner: 全平台支持 (All-platform support) + 新增服务器 button
class CrossPlatformBannerCard extends StatelessWidget {
  const CrossPlatformBannerCard({required this.onAddServer, super.key});

  final VoidCallback onAddServer;

  @override
  Widget build(BuildContext context) {
    return _FeatureCardContainer(
      borderColor: const Color(0xFF1B3D2B),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      watermark: Positioned(
        right: 180,
        top: -20,
        child: Opacity(
          opacity: 0.07,
          child: Icon(
            Icons.apple,
            size: 150,
            color: const Color(0xFF30D158).withValues(alpha: 0.8),
          ),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 520;
          if (isNarrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _IconBadge(
                  icon: Icons.apple,
                  color: const Color(0xFF30D158),
                  backgroundColor: const Color(
                    0xFF30D158,
                  ).withValues(alpha: 0.16),
                ),
                const SizedBox(height: 14),
                Text(
                  context.l10n.featureCrossPlatform,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  context.l10n.featureCrossPlatformDesc,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: _AddServerButton(onPressed: onAddServer),
                ),
              ],
            );
          }

          return Row(
            children: <Widget>[
              _IconBadge(
                icon: Icons.apple,
                color: const Color(0xFF30D158),
                backgroundColor: const Color(
                  0xFF30D158,
                ).withValues(alpha: 0.16),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      context.l10n.featureCrossPlatform,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      context.l10n.featureCrossPlatformDesc,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              _AddServerButton(onPressed: onAddServer),
            ],
          );
        },
      ),
    );
  }
}

class _AddServerButton extends StatelessWidget {
  const _AddServerButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: const Color(0xFF0A84FF).withValues(alpha: 0.45),
            blurRadius: 18,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: const Color(0xFF0A84FF),
        borderRadius: BorderRadius.circular(28),
        child: InkWell(
          borderRadius: BorderRadius.circular(28),
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 13),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Icon(Icons.add_circle, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text(
                  context.l10n.addServer,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _IconBadge extends StatelessWidget {
  const _IconBadge({
    required this.icon,
    required this.color,
    required this.backgroundColor,
  });

  final IconData icon;
  final Color color;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Center(child: Icon(icon, color: color, size: 22)),
    );
  }
}

class _FeatureCardContainer extends StatelessWidget {
  const _FeatureCardContainer({
    required this.child,
    required this.borderColor,
    this.watermark,
    this.padding = const EdgeInsets.all(22),
  });

  final Widget child;
  final Color borderColor;
  final Widget? watermark;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF181A20).withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: borderColor.withValues(alpha: 0.75),
            width: 1.2,
          ),
        ),
        child: Stack(
          children: <Widget>[
            ?watermark,
            Padding(padding: padding, child: child),
          ],
        ),
      ),
    );
  }
}
