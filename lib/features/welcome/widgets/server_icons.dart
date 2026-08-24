import 'package:flutter/material.dart';

/// Brand logos for the server-type grid on the add-server screen. These are
/// simplified vector redraws of the SwiftUI versions in the Apple target, not
/// official bitmap assets.

class NavidromeLogo extends StatelessWidget {
  const NavidromeLogo({super.key, this.size = 58});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 0.5,
                colors: const <Color>[
                  Color(0xFF0080FF),
                  Color(0xFF0055B3),
                  Color(0xFF002B66),
                ],
              ),
              boxShadow: const <BoxShadow>[
                BoxShadow(
                  color: Color(0x660080FF),
                  blurRadius: 8,
                  offset: Offset(0, 3),
                ),
              ],
            ),
          ),
          Container(
            width: size * 0.9,
            height: size * 0.9,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.black, width: size * 0.08),
            ),
          ),
          Container(
            width: size * 0.65,
            height: size * 0.65,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.35),
                width: 1.5,
              ),
            ),
          ),
          Container(
            width: size * 0.48,
            height: size * 0.48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.2),
                width: 1,
              ),
            ),
          ),
          Container(
            width: size * 0.28,
            height: size * 0.28,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFF12161E),
            ),
          ),
          Container(
            width: size * 0.09,
            height: size * 0.09,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class SubsonicLogo extends StatelessWidget {
  const SubsonicLogo({super.key, this.size = 58});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          SizedBox(
            width: size * 0.78,
            height: size * 0.5,
            child: Stack(
              alignment: Alignment.center,
              children: <Widget>[
                Container(
                  width: size * 0.72,
                  height: size * 0.44,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(size * 0.22),
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: <Color>[Color(0xFFFFB800), Color(0xFFFF8C00)],
                    ),
                  ),
                ),
                Positioned(
                  top: size * 0.02,
                  child: Container(
                    width: size * 0.1,
                    height: size * 0.16,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF8C00),
                      borderRadius: BorderRadius.circular(size * 0.05),
                    ),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    for (var i = 0; i < 3; i++)
                      Container(
                        width: size * 0.11,
                        height: size * 0.11,
                        margin: EdgeInsets.symmetric(horizontal: size * 0.03),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                          border: Border.all(
                            color: const Color(0xFF332200),
                            width: size * 0.025,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          Icon(
            Icons.graphic_eq,
            size: size * 0.35,
            color: Colors.white.withValues(alpha: 0.6),
          ),
        ],
      ),
    );
  }
}

class PlexLogo extends StatelessWidget {
  const PlexLogo({super.key, this.size = 58});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF1A1C22),
              border: Border.all(color: const Color(0xFF2E323D), width: 1.5),
            ),
          ),
          Container(
            width: size * 0.44,
            height: size * 0.54,
            margin: EdgeInsets.only(left: size * 0.04),
            child: CustomPaint(
              painter: _PlexChevronPainter(),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlexChevronPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: const <Color>[Color(0xFFFFC000), Color(0xFFE58900)],
      ).createShader(Offset.zero & size);
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width * 0.52, 0)
      ..lineTo(size.width, size.height * 0.5)
      ..lineTo(size.width * 0.52, size.height)
      ..lineTo(0, size.height)
      ..lineTo(size.width * 0.48, size.height * 0.5)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class JellyfinLogo extends StatelessWidget {
  const JellyfinLogo({super.key, this.size = 58});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: ShaderMask(
        shaderCallback: (rect) => const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[Color(0xFF9B51E0), Color(0xFF00A4DC)],
        ).createShader(rect),
        child: Stack(
          alignment: Alignment.center,
          children: <Widget>[
            Icon(
              Icons.auto_awesome,
              size: size * 0.55,
              color: Colors.white,
            ),
            Transform.rotate(
              angle: 3.14159,
              child: Icon(
                Icons.play_arrow,
                size: size * 0.48,
                color: Colors.white.withValues(alpha: 0.85),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class EmbyLogo extends StatelessWidget {
  const EmbyLogo({super.key, this.size = 58});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          Transform.rotate(
            angle: 0.785398,
            child: Container(
              width: size * 0.72,
              height: size * 0.72,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(size * 0.16),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: <Color>[Color(0xFF52B043), Color(0xFF3E8E33)],
                ),
                boxShadow: const <BoxShadow>[
                  BoxShadow(
                    color: Color(0x6652B043),
                    blurRadius: 8,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
            ),
          ),
          Icon(
            Icons.play_arrow,
            size: size * 0.34,
            color: Colors.white,
          ),
        ],
      ),
    );
  }
}

class AudioStationLogo extends StatelessWidget {
  const AudioStationLogo({super.key, this.size = 58});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Container(
        width: size * 0.9,
        height: size * 0.9,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(size * 0.28),
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[Color(0xFF00C896), Color(0xFF009E73)],
          ),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: Color(0x6600C896),
              blurRadius: 8,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Icon(
          Icons.headphones,
          size: size * 0.48,
          color: Colors.white,
        ),
      ),
    );
  }
}

class AudiobookshelfLogo extends StatelessWidget {
  const AudiobookshelfLogo({super.key, this.size = 58});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Container(
        width: size * 0.95,
        height: size * 0.95,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[Color(0xFFC49A45), Color(0xFF8C6820)],
          ),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.3),
            width: 1.5,
          ),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: Color(0x66C49A45),
              blurRadius: 8,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(
              Icons.headphones,
              size: size * 0.38,
              color: Colors.white,
            ),
            const SizedBox(height: 2),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Container(
                  width: 3,
                  height: size * 0.16,
                  color: Colors.white,
                ),
                const SizedBox(width: 2),
                Container(
                  width: 3,
                  height: size * 0.14,
                  color: Colors.white,
                ),
                const SizedBox(width: 2),
                Container(
                  width: 3,
                  height: size * 0.18,
                  color: Colors.white,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Picks the brand logo for a server-type id used by the add-server grid.
class ServerBrandIcon extends StatelessWidget {
  const ServerBrandIcon({super.key, required this.id, this.size = 58});

  final String id;
  final double size;

  @override
  Widget build(BuildContext context) {
    return switch (id) {
      'navidrome' => NavidromeLogo(size: size),
      'subsonic' => SubsonicLogo(size: size),
      'plex' => PlexLogo(size: size),
      'jellyfin' => JellyfinLogo(size: size),
      'emby' => EmbyLogo(size: size),
      'audiostation' => AudioStationLogo(size: size),
      'audiobookshelf' => AudiobookshelfLogo(size: size),
      _ => Icon(Icons.dns, size: size * 0.6, color: Colors.blue),
    };
  }
}
