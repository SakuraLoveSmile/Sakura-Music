import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:palette_generator/palette_generator.dart';

class ArtworkPalette {
  const ArtworkPalette({required this.vibrant, required this.muted});

  final Color vibrant;
  final Color muted;
}

final artworkPaletteProvider = FutureProvider.family<ArtworkPalette, String>((
  ref,
  artworkUrl,
) async {
  final generator = await PaletteGenerator.fromImageProvider(
    ResizeImage.resizeIfNeeded(96, 96, CachedNetworkImageProvider(artworkUrl)),
    maximumColorCount: 16,
  );
  return ArtworkPalette(
    vibrant: generator.vibrantColor?.color ?? const Color(0xffe78baa),
    muted: generator.mutedColor?.color ?? const Color(0xff5d4150),
  );
});
