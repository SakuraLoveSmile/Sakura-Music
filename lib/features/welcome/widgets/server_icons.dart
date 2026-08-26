import 'package:flutter/material.dart';

/// Official brand logos for the server-type grid on the add-server screen.
/// Assets are stored in `assets/icons/servers/`.

class _ServerAssetLogo extends StatelessWidget {
  const _ServerAssetLogo({required this.assetPath, this.size = 58});

  final String assetPath;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      assetPath,
      width: size,
      height: size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
      errorBuilder: (context, error, stackTrace) =>
          Icon(Icons.dns, size: size * 0.6, color: Colors.blue),
    );
  }
}

class NavidromeLogo extends StatelessWidget {
  const NavidromeLogo({super.key, this.size = 58});

  final double size;

  @override
  Widget build(BuildContext context) {
    return _ServerAssetLogo(
      assetPath: 'assets/icons/servers/navidrome.png',
      size: size,
    );
  }
}

class SubsonicLogo extends StatelessWidget {
  const SubsonicLogo({super.key, this.size = 58});

  final double size;

  @override
  Widget build(BuildContext context) {
    return _ServerAssetLogo(
      assetPath: 'assets/icons/servers/subsonic.png',
      size: size,
    );
  }
}

class PlexLogo extends StatelessWidget {
  const PlexLogo({super.key, this.size = 58});

  final double size;

  @override
  Widget build(BuildContext context) {
    return _ServerAssetLogo(
      assetPath: 'assets/icons/servers/plex.png',
      size: size,
    );
  }
}

class JellyfinLogo extends StatelessWidget {
  const JellyfinLogo({super.key, this.size = 58});

  final double size;

  @override
  Widget build(BuildContext context) {
    return _ServerAssetLogo(
      assetPath: 'assets/icons/servers/jellyfin.png',
      size: size,
    );
  }
}

class EmbyLogo extends StatelessWidget {
  const EmbyLogo({super.key, this.size = 58});

  final double size;

  @override
  Widget build(BuildContext context) {
    return _ServerAssetLogo(
      assetPath: 'assets/icons/servers/emby.png',
      size: size,
    );
  }
}

class AudioStationLogo extends StatelessWidget {
  const AudioStationLogo({super.key, this.size = 58});

  final double size;

  @override
  Widget build(BuildContext context) {
    return _ServerAssetLogo(
      assetPath: 'assets/icons/servers/audiostation.png',
      size: size,
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
    return switch (id.toLowerCase()) {
      'navidrome' => NavidromeLogo(size: size),
      'subsonic' => SubsonicLogo(size: size),
      'plex' => PlexLogo(size: size),
      'jellyfin' => JellyfinLogo(size: size),
      'emby' => EmbyLogo(size: size),
      'audiostation' ||
      'audio station' ||
      'synology' => AudioStationLogo(size: size),
      _ => Icon(Icons.dns, size: size * 0.6, color: Colors.blue),
    };
  }
}
