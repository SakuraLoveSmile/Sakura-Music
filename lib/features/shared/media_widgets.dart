import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import 'package:go_router/go_router.dart';
import 'package:subsonic_api/subsonic_api.dart';

String formatSongDuration(int? seconds) {
  if (seconds == null || seconds <= 0) {
    return '--:--';
  }
  final mins = seconds ~/ 60;
  final secs = seconds % 60;
  if (mins >= 60) {
    final hours = mins ~/ 60;
    final remMins = mins % 60;
    return '$hours:${remMins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }
  return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
}

class AudioQualityBadge extends StatelessWidget {
  const AudioQualityBadge({
    this.suffix,
    this.bitRate,
    super.key,
  });

  final String? suffix;
  final int? bitRate;

  @override
  Widget build(BuildContext context) {
    if (suffix == null && bitRate == null) {
      return const SizedBox.shrink();
    }

    final ext = (suffix ?? '').trim().toLowerCase();
    String text;
    if (ext.isNotEmpty && bitRate != null && bitRate! > 0) {
      text = '$ext ${bitRate}K';
    } else if (ext.isNotEmpty) {
      text = ext;
    } else if (bitRate != null && bitRate! > 0) {
      text = '${bitRate}K';
    } else {
      return const SizedBox.shrink();
    }

    final isLossless = ext == 'flac' || ext == 'wav' || ext == 'dsd' || ext == 'alac' || ext == 'ape' || (bitRate != null && bitRate! >= 1000);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4.5, vertical: 1.0),
      decoration: BoxDecoration(
        color: isLossless
            ? const Color(0xFF1E7BF6).withValues(alpha: 0.14)
            : Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: isLossless
              ? const Color(0xFF1E7BF6).withValues(alpha: 0.4)
              : Colors.white.withValues(alpha: 0.16),
          width: 0.8,
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
          color: isLossless
              ? const Color(0xFF5BA4FF)
              : Colors.white.withValues(alpha: 0.65),
          height: 1.1,
        ),
      ),
    );
  }
}

class StarButton extends StatefulWidget {
  const StarButton({
    required this.isStarred,
    required this.onPressed,
    this.filled = false,
    this.size = 20,
    super.key,
  });

  final bool isStarred;
  final Future<void> Function() onPressed;
  final bool filled;
  final double size;

  @override
  State<StarButton> createState() => _StarButtonState();
}

class _StarButtonState extends State<StarButton> {
  bool _busy = false;

  Future<void> _toggle() async {
    if (_busy) {
      return;
    }
    setState(() => _busy = true);
    try {
      await widget.onPressed();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(context.l10n.starFailed(error.toString())),
            ),
          );
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final label = widget.isStarred
        ? context.l10n.unfavorite
        : context.l10n.favorite;
    final icon = _busy
        ? SizedBox.square(
            dimension: widget.size * 0.8,
            child: const CircularProgressIndicator(strokeWidth: 2),
          )
        : Icon(
            widget.isStarred ? Icons.favorite_rounded : Icons.favorite_border_rounded,
            size: widget.size,
            color: widget.isStarred ? const Color(0xFFFF453A) : Colors.white70,
          );
    return IconButton(
      tooltip: _busy ? context.l10n.updatingFavorite : label,
      padding: EdgeInsets.zero,
      constraints: BoxConstraints.tightFor(width: widget.size + 14, height: widget.size + 14),
      onPressed: _busy ? null : _toggle,
      style: widget.filled
          ? IconButton.styleFrom(
              backgroundColor: Colors.black.withValues(alpha: 0.5),
              shape: const CircleBorder(),
            )
          : null,
      icon: icon,
    );
  }
}

class AlbumCard extends StatelessWidget {
  const AlbumCard({
    required this.album,
    required this.client,
    required this.onTap,
    this.onFavorite,
    this.isFavorite = false,
    super.key,
  });

  final Album album;
  final SubsonicClient client;
  final VoidCallback onTap;
  final Future<void> Function()? onFavorite;
  final bool isFavorite;

  @override
  Widget build(BuildContext context) {
    final imageUrl = album.coverArt == null
        ? null
        : client.coverArtUrl(album.coverArt!, size: 360);
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          AspectRatio(
            aspectRatio: 1.0,
            child: Stack(
              children: <Widget>[
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: imageUrl == null
                        ? Container(
                            color: const Color(0xFF22242D),
                            child: const Icon(
                              Icons.album_rounded,
                              size: 48,
                              color: Colors.white24,
                            ),
                          )
                        : CachedNetworkImage(
                            imageUrl: imageUrl,
                            cacheKey: 'cover_${album.coverArt}_360',
                            memCacheWidth: 360,
                            memCacheHeight: 360,
                            fit: BoxFit.cover,
                            fadeInDuration: Duration.zero,
                            fadeOutDuration: Duration.zero,
                            placeholder: (context, url) => Container(
                              color: const Color(0xFF22242D),
                            ),
                            errorWidget: (context, url, error) => Container(
                              color: const Color(0xFF22242D),
                              child: const Icon(
                                Icons.album_rounded,
                                size: 48,
                                color: Colors.white24,
                              ),
                            ),
                          ),
                  ),
                ),
                if (onFavorite != null)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.45),
                        shape: BoxShape.circle,
                      ),
                      child: StarButton(
                        isStarred: isFavorite,
                        onPressed: onFavorite!,
                        size: 17,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            album.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13.5,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            album.artist ?? context.l10n.unknownArtist,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 12,
            ),
          ),
          if (album.year != null && album.year! > 0) ...[
            const SizedBox(height: 1),
            Text(
              '${album.year}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.35),
                fontSize: 11,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class SongGridTile extends StatelessWidget {
  const SongGridTile({
    required this.song,
    required this.onTap,
    this.client,
    this.onFavorite,
    this.onMore,
    this.isFavorite = false,
    this.isPlaying = false,
    super.key,
  });

  final Song song;
  final SubsonicClient? client;
  final VoidCallback onTap;
  final Future<void> Function()? onFavorite;
  final VoidCallback? onMore;
  final bool isFavorite;
  final bool isPlaying;

  @override
  Widget build(BuildContext context) {
    final imageUrl = client == null || song.coverArt == null
        ? null
        : client!.coverArtUrl(song.coverArt!, size: 120);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: isPlaying
                ? const Color(0xFF1E7BF6).withValues(alpha: 0.12)
                : Colors.transparent,
          ),
          child: Row(
            children: <Widget>[
              // Cover Thumbnail
              SizedBox.square(
                dimension: 44,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: imageUrl == null
                      ? Container(
                          color: const Color(0xFF22242D),
                          child: const Icon(
                            Icons.music_note_rounded,
                            color: Colors.white30,
                            size: 22,
                          ),
                        )
                      : CachedNetworkImage(
                          imageUrl: imageUrl,
                          cacheKey: 'cover_${song.coverArt}_120',
                          fit: BoxFit.cover,
                          errorWidget: (context, url, error) => Container(
                            color: const Color(0xFF22242D),
                            child: const Icon(
                              Icons.music_note_rounded,
                              color: Colors.white30,
                              size: 22,
                            ),
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 10),

              // Title, Badge, and Artist/Album
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        if (isPlaying) ...[
                          Container(
                            width: 6,
                            height: 6,
                            margin: const EdgeInsets.only(right: 6),
                            decoration: const BoxDecoration(
                              color: Color(0xFF34C759),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                        Expanded(
                          child: Text(
                            song.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              color: isPlaying
                                  ? const Color(0xFF5BA4FF)
                                  : Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: <Widget>[
                        if (song.suffix != null || song.bitRate != null) ...[
                          AudioQualityBadge(
                            suffix: song.suffix,
                            bitRate: song.bitRate,
                          ),
                          const SizedBox(width: 6),
                        ],
                        Expanded(
                          child: Text(
                            [song.artist, song.album]
                                .whereType<String>()
                                .where((s) => s.isNotEmpty)
                                .join(' · '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11.5,
                              color: Colors.white.withValues(alpha: 0.55),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Duration
              if (song.duration != null && song.duration! > 0)
                Padding(
                  padding: const EdgeInsets.only(left: 6, right: 4),
                  child: Text(
                    formatSongDuration(song.duration),
                    style: TextStyle(
                      fontSize: 11.5,
                      color: Colors.white.withValues(alpha: 0.38),
                    ),
                  ),
                ),

              // Favorite Heart
              if (onFavorite != null)
                StarButton(
                  isStarred: isFavorite,
                  onPressed: onFavorite!,
                  size: 16,
                ),

              // More Options
              if (onMore != null)
                IconButton(
                  tooltip: context.l10n.more,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints.tightFor(width: 28, height: 28),
                  icon: Icon(
                    Icons.more_horiz_rounded,
                    size: 18,
                    color: Colors.white.withValues(alpha: 0.5),
                  ),
                  onPressed: onMore,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class SongListTile extends StatelessWidget {
  const SongListTile({
    required this.song,
    required this.onTap,
    this.client,
    this.onFavorite,
    this.onDownload,
    this.onMore,
    this.isFavorite = false,
    this.isPlaying = false,
    this.index,
    super.key,
  });

  final Song song;
  final SubsonicClient? client;
  final VoidCallback onTap;
  final Future<void> Function()? onFavorite;
  final VoidCallback? onDownload;
  final VoidCallback? onMore;
  final bool isFavorite;
  final bool isPlaying;
  final int? index;

  @override
  Widget build(BuildContext context) {
    final imageUrl = client == null || song.coverArt == null
        ? null
        : client!.coverArtUrl(song.coverArt!, size: 96);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: isPlaying
                ? const Color(0xFF1E7BF6).withValues(alpha: 0.12)
                : Colors.transparent,
          ),
          child: Row(
            children: <Widget>[
              if (index != null)
                SizedBox(
                  width: 28,
                  child: Text(
                    '$index',
                    style: TextStyle(
                      fontSize: 13,
                      color: isPlaying
                          ? const Color(0xFF34C759)
                          : Colors.white.withValues(alpha: 0.35),
                      fontWeight:
                          isPlaying ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
              SizedBox.square(
                dimension: 44,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: imageUrl == null
                      ? Container(
                          color: const Color(0xFF22242D),
                          child: const Icon(
                            Icons.music_note_rounded,
                            color: Colors.white30,
                            size: 22,
                          ),
                        )
                      : CachedNetworkImage(
                          imageUrl: imageUrl,
                          cacheKey: 'cover_${song.coverArt}_96',
                          fit: BoxFit.cover,
                          errorWidget: (context, url, error) => Container(
                            color: const Color(0xFF22242D),
                            child: const Icon(
                              Icons.music_note_rounded,
                              color: Colors.white30,
                              size: 22,
                            ),
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        if (isPlaying) ...[
                          Container(
                            width: 7,
                            height: 7,
                            margin: const EdgeInsets.only(right: 6),
                            decoration: const BoxDecoration(
                              color: Color(0xFF34C759),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                        Expanded(
                          child: Text(
                            song.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: isPlaying
                                  ? const Color(0xFF5BA4FF)
                                  : Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: <Widget>[
                        if (song.suffix != null || song.bitRate != null) ...[
                          AudioQualityBadge(
                            suffix: song.suffix,
                            bitRate: song.bitRate,
                          ),
                          const SizedBox(width: 6),
                        ],
                        Expanded(
                          child: Text(
                            [song.artist, song.album]
                                .whereType<String>()
                                .where((s) => s.isNotEmpty)
                                .join(' · '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withValues(alpha: 0.55),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (song.duration != null && song.duration! > 0)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Text(
                    formatSongDuration(song.duration),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.4),
                    ),
                  ),
                ),
              if (onDownload != null)
                IconButton(
                  tooltip: context.l10n.download,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints.tightFor(width: 32, height: 32),
                  onPressed: onDownload,
                  icon: Icon(
                    Icons.download_outlined,
                    size: 18,
                    color: Colors.white.withValues(alpha: 0.6),
                  ),
                ),
              if (onFavorite != null)
                StarButton(
                  isStarred: isFavorite,
                  onPressed: onFavorite!,
                  size: 18,
                ),
              if (onMore != null)
                IconButton(
                  tooltip: context.l10n.more,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints.tightFor(width: 32, height: 32),
                  icon: Icon(
                    Icons.more_horiz_rounded,
                    size: 18,
                    color: Colors.white.withValues(alpha: 0.5),
                  ),
                  onPressed: onMore,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class ArtistListTile extends StatelessWidget {
  const ArtistListTile({
    required this.artist,
    required this.onTap,
    this.onFavorite,
    this.isFavorite = false,
    super.key,
  });

  final Artist artist;
  final VoidCallback onTap;
  final Future<void> Function()? onFavorite;
  final bool isFavorite;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: const Color(0xFF242630),
        child: Text(
          artist.name.isEmpty ? '?' : artist.name.substring(0, 1).toUpperCase(),
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
      ),
      title: Text(artist.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      subtitle: artist.albumCount == null
          ? null
          : Text(
              context.l10n.artistAlbumCount(artist.albumCount!),
              style: TextStyle(color: Colors.white.withValues(alpha: 0.55)),
            ),
      trailing: onFavorite == null
          ? null
          : StarButton(isStarred: isFavorite, onPressed: onFavorite!),
      onTap: onTap,
    );
  }
}

class NoServerView extends StatelessWidget {
  const NoServerView({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.cloud_off, size: 64, color: Colors.white.withValues(alpha: 0.4)),
            const SizedBox(height: 14),
            Text(
              context.l10n.noServerMessage,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () => context.go('/welcome'),
              icon: const Icon(Icons.dns_outlined, size: 18),
              label: Text(context.l10n.goToServerPicker),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF1E7BF6),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

