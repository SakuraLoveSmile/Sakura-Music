import 'dart:ui';

import 'package:flutter/material.dart';

/// Flutter interpretation of Glasmio's layered material. This samples the
/// actual backdrop; it does not implement Glasmio's native refraction shader.
class GlassSurface extends StatelessWidget {
  const GlassSurface({
    required this.child,
    this.borderRadius = const BorderRadius.all(Radius.circular(26)),
    this.padding = EdgeInsets.zero,
    this.clear = false,
    this.blur = true,
    this.tint,
    super.key,
  });

  final Widget child;
  final BorderRadius borderRadius;
  final EdgeInsetsGeometry padding;
  final bool clear;

  /// Sample the backdrop only when there is detail behind this surface.
  /// Chrome over the app canvas already has a smooth background and can keep
  /// its translucent face and rim without a separate offscreen blur pass.
  final bool blur;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final opaque = MediaQuery.highContrastOf(context);
    final android = Theme.of(context).platform == TargetPlatform.android;
    final face =
        tint ?? (dark ? const Color(0xFF1C1C1E) : const Color(0xFFF8F8FA));
    final shape = RoundedSuperellipseBorder(borderRadius: borderRadius);
    final content = DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            face.withValues(alpha: opaque ? 1 : (clear ? 0.30 : 0.65)),
            face.withValues(alpha: opaque ? 1 : (clear ? 0.14 : 0.48)),
          ],
        ),
      ),
      child: CustomPaint(
        foregroundPainter: _GlassRim(shape: shape, dark: dark),
        child: Material(
          type: MaterialType.transparency,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
    return DecoratedBox(
      decoration: ShapeDecoration(
        shape: shape,
        shadows: [
          BoxShadow(
            color: Colors.black.withValues(alpha: dark ? 0.23 : 0.08),
            blurRadius: 28,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRSuperellipse(
        borderRadius: borderRadius,
        child: opaque || !blur
            ? content
            : BackdropFilter(
                filter: ImageFilter.blur(
                  sigmaX: android ? 8 : (clear ? 12 : 24),
                  sigmaY: android ? 8 : (clear ? 12 : 24),
                ),
                child: content,
              ),
      ),
    );
  }
}

class _GlassRim extends CustomPainter {
  const _GlassRim({required this.shape, required this.dark});

  final RoundedSuperellipseBorder shape;
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(0.6);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: dark
            ? const [Color(0x3DFFFFFF), Color(0x08FFFFFF), Color(0x1AFFFFFF)]
            : const [Color(0xEEFFFFFF), Color(0x18FFFFFF), Color(0x88FFFFFF)],
        stops: const [0, 0.55, 1],
      ).createShader(rect);
    canvas.drawPath(shape.getOuterPath(rect), paint);
  }

  @override
  bool shouldRepaint(_GlassRim oldDelegate) =>
      shape != oldDelegate.shape || dark != oldDelegate.dark;
}

/// A labelled, keyboard-accessible glass control with a 44-point touch target.
class GlassIconButton extends StatelessWidget {
  const GlassIconButton({
    required this.icon,
    required this.tooltip,
    this.onPressed,
    this.selected = false,
    this.size = 44,
    this.color,
    super.key,
  });

  final Widget icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool selected;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final dimension = size < 44 ? 44.0 : size;
    return GlassSurface(
      blur: false,
      clear: !selected,
      tint: selected ? Color.lerp(const Color(0xFF1C1C1E), primary, 0.3) : null,
      borderRadius: BorderRadius.circular(dimension / 2),
      child: SizedBox.square(
        dimension: dimension,
        child: IconButton(
          tooltip: tooltip,
          onPressed: onPressed,
          isSelected: selected,
          style: IconButton.styleFrom(
            foregroundColor: color ?? (selected ? primary : null),
            padding: EdgeInsets.zero,
            shape: const CircleBorder(),
          ),
          icon: icon,
        ),
      ),
    );
  }
}

/// A restrained ambient canvas behind the app's translucent chrome.
class GlassBackdrop extends StatelessWidget {
  const GlassBackdrop({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final accent = Theme.of(context).colorScheme.primary;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF08090D) : const Color(0xFFF2F2F7),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0.95, -0.95),
            radius: 1.25,
            colors: [
              accent.withValues(alpha: dark ? 0.13 : 0.09),
              accent.withValues(alpha: 0),
            ],
          ),
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(-1, 0.8),
              radius: 1.2,
              colors: [
                const Color(0xFF906AC4).withValues(alpha: dark ? 0.10 : 0.06),
                const Color(0x00906AC4),
              ],
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Place above scrolling content and below sharp foreground controls.
/// Android uses one light, clipped blur with the header's gradient tint rather
/// than many offscreen filter passes. Other platforms retain the banded
/// approximation; neither path implements the upstream per-pixel shader.
class ProgressiveGlassBlur extends StatelessWidget {
  const ProgressiveGlassBlur({
    this.height = 96,
    this.bottom = false,
    super.key,
  });

  final double height;
  final bool bottom;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.highContrastOf(context)) return const SizedBox.shrink();
    if (Theme.of(context).platform == TargetPlatform.android) {
      return IgnorePointer(
        child: SizedBox(
          height: height,
          child: ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: const SizedBox.expand(),
            ),
          ),
        ),
      );
    }
    const bandCount = 24;
    return IgnorePointer(
      child: SizedBox(
        height: height,
        child: Stack(
          // The final band is unfiltered. Small steps and a quadratic falloff
          // avoid the visible seams of a few bands ending at a nonzero sigma.
          children: List<Widget>.generate(bandCount - 1, (i) {
            final falloff = 1 - i / (bandCount - 1);
            final sigma = 18 * falloff * falloff;
            return Positioned(
              left: 0,
              right: 0,
              top: bottom ? null : height * i / bandCount,
              bottom: bottom ? height * i / bandCount : null,
              height: height / bandCount,
              child: ClipRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
                  child: const SizedBox.expand(),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}
