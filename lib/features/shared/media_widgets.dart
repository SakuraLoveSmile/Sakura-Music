import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:subsonic_api/subsonic_api.dart';

import '../../audio/audio_player_provider.dart';
import '../../audio/playable_item_builder.dart';
import '../../core/providers.dart';
import '../../data/download_manager.dart';
import '../../l10n/l10n.dart';

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
  const AudioQualityBadge({this.suffix, this.bitRate, super.key});

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

    final isLossless =
        ext == 'flac' ||
        ext == 'wav' ||
        ext == 'dsd' ||
        ext == 'alac' ||
        ext == 'ape' ||
        (bitRate != null && bitRate! >= 1000);

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
            SnackBar(content: Text(context.l10n.starFailed(error.toString()))),
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
            widget.isStarred
                ? Icons.favorite_rounded
                : Icons.favorite_border_rounded,
            size: widget.size,
            color: widget.isStarred ? const Color(0xFFFF453A) : Colors.white70,
          );
    return IconButton(
      tooltip: _busy ? context.l10n.updatingFavorite : label,
      padding: EdgeInsets.zero,
      constraints: BoxConstraints.tightFor(
        width: widget.size + 14,
        height: widget.size + 14,
      ),
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
                            placeholder: (context, url) =>
                                Container(color: const Color(0xFF22242D)),
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

/// Helper to resolve the best cover-art ID for a song, prioritizing explicit
/// [Song.coverArt], and falling back to [Song.albumId] and [Song.id].
String? resolveSongCoverArtId(Song song) {
  if (song.coverArt != null && song.coverArt!.trim().isNotEmpty) {
    return song.coverArt!.trim();
  }
  if (song.albumId != null && song.albumId!.trim().isNotEmpty) {
    return song.albumId!.trim();
  }
  if (song.id.trim().isNotEmpty) {
    return song.id.trim();
  }
  return null;
}

/// Helper to resolve the best image URL for a song from SubsonicClient
String? resolveSongCoverUrl({
  required Song song,
  SubsonicClient? client,
  int size = 120,
}) {
  if (client == null) {
    return null;
  }
  final coverId = resolveSongCoverArtId(song);
  if (coverId == null) {
    return null;
  }
  return client.coverArtUrl(coverId, size: size);
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
    final isWide = MediaQuery.sizeOf(context).width >= 600;
    final coverId = resolveSongCoverArtId(song);
    final imageUrl = client == null || coverId == null
        ? null
        : client!.coverArtUrl(coverId, size: 120);

    final metadataParts = <String>[
      if (song.artist != null && song.artist!.trim().isNotEmpty) song.artist!,
      if (song.album != null && song.album!.trim().isNotEmpty) song.album!,
      if (!isWide && song.duration != null && song.duration! > 0)
        formatSongDuration(song.duration),
    ];
    final subtitleText = metadataParts.join(' · ');

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
                          cacheKey: coverId == null
                              ? null
                              : 'cover_${coverId}_120',
                          fit: BoxFit.cover,
                          fadeInDuration: Duration.zero,
                          fadeOutDuration: Duration.zero,
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
                        if (subtitleText.isNotEmpty)
                          Expanded(
                            child: Text(
                              subtitleText,
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

              if (isWide) ...[
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
                    constraints: const BoxConstraints.tightFor(
                      width: 28,
                      height: 28,
                    ),
                    icon: Icon(
                      Icons.more_horiz_rounded,
                      size: 18,
                      color: Colors.white.withValues(alpha: 0.5),
                    ),
                    onPressed: onMore,
                  ),
              ] else ...[
                if (onMore != null)
                  IconButton(
                    tooltip: context.l10n.more,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints.tightFor(
                      width: 28,
                      height: 28,
                    ),
                    icon: Icon(
                      Icons.more_horiz_rounded,
                      size: 18,
                      color: Colors.white.withValues(alpha: 0.5),
                    ),
                    onPressed: onMore,
                  )
                else if (onFavorite != null)
                  StarButton(
                    isStarred: isFavorite,
                    onPressed: onFavorite!,
                    size: 16,
                  ),
              ],
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
    final isWide = MediaQuery.sizeOf(context).width >= 600;
    final coverId = resolveSongCoverArtId(song);
    final imageUrl = client == null || coverId == null
        ? null
        : client!.coverArtUrl(coverId, size: 96);

    final metadataParts = <String>[
      if (song.artist != null && song.artist!.trim().isNotEmpty) song.artist!,
      if (song.album != null && song.album!.trim().isNotEmpty) song.album!,
      if (!isWide && song.duration != null && song.duration! > 0)
        formatSongDuration(song.duration),
    ];
    final subtitleText = metadataParts.join(' · ');

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: isWide ? 10 : 6,
            vertical: 7,
          ),
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
                  width: isWide ? 28 : 22,
                  child: Text(
                    '$index',
                    style: TextStyle(
                      fontSize: isWide ? 13 : 12,
                      color: isPlaying
                          ? const Color(0xFF34C759)
                          : Colors.white.withValues(alpha: 0.35),
                      fontWeight: isPlaying
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                ),
              SizedBox.square(
                dimension: isWide ? 44 : 42,
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
                          cacheKey: coverId == null
                              ? null
                              : 'cover_${coverId}_96',
                          fit: BoxFit.cover,
                          fadeInDuration: Duration.zero,
                          fadeOutDuration: Duration.zero,
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
              SizedBox(width: isWide ? 12 : 10),
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
                              fontSize: isWide ? 14 : 13.5,
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
                        if (subtitleText.isNotEmpty)
                          Expanded(
                            child: Text(
                              subtitleText,
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
              if (isWide) ...[
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
                    constraints: const BoxConstraints.tightFor(
                      width: 32,
                      height: 32,
                    ),
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
                    constraints: const BoxConstraints.tightFor(
                      width: 32,
                      height: 32,
                    ),
                    icon: Icon(
                      Icons.more_horiz_rounded,
                      size: 18,
                      color: Colors.white.withValues(alpha: 0.5),
                    ),
                    onPressed: onMore,
                  ),
              ] else ...[
                if (onMore != null)
                  IconButton(
                    tooltip: context.l10n.more,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints.tightFor(
                      width: 32,
                      height: 32,
                    ),
                    icon: Icon(
                      Icons.more_horiz_rounded,
                      size: 19,
                      color: Colors.white.withValues(alpha: 0.5),
                    ),
                    onPressed: onMore,
                  )
                else if (onFavorite != null)
                  StarButton(
                    isStarred: isFavorite,
                    onPressed: onFavorite!,
                    size: 18,
                  )
                else if (onDownload != null)
                  IconButton(
                    tooltip: context.l10n.download,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints.tightFor(
                      width: 32,
                      height: 32,
                    ),
                    onPressed: onDownload,
                    icon: Icon(
                      Icons.download_outlined,
                      size: 18,
                      color: Colors.white.withValues(alpha: 0.6),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

void showSongActionBottomSheet({
  required BuildContext context,
  required WidgetRef ref,
  required Song song,
  required SubsonicClient client,
}) {
  final coverId = resolveSongCoverArtId(song);
  final coverUrl = coverId == null
      ? null
      : client.coverArtUrl(coverId, size: 160);

  showModalBottomSheet<void>(
    context: context,
    backgroundColor: const Color(0xFF1E2028),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (sheetContext) {
      return Consumer(
        builder: (context, ref, _) {
          final liveStarred = ref.watch(starredIdsProvider);
          final liveIsFavorite = liveStarred.songs.contains(song.id);

          return SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(top: 8, bottom: 4),
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
                  child: Row(
                    children: <Widget>[
                      SizedBox.square(
                        dimension: 46,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: coverUrl == null
                              ? Container(
                                  color: const Color(0xFF2B2D38),
                                  child: const Icon(
                                    Icons.music_note_rounded,
                                    color: Colors.white30,
                                    size: 24,
                                  ),
                                )
                              : CachedNetworkImage(
                                  imageUrl: coverUrl,
                                  cacheKey: coverId == null
                                      ? null
                                      : 'cover_${coverId}_160',
                                  fit: BoxFit.cover,
                                  errorWidget: (context, url, error) =>
                                      Container(
                                        color: const Color(0xFF2B2D38),
                                        child: const Icon(
                                          Icons.music_note_rounded,
                                          color: Colors.white30,
                                          size: 24,
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
                            Text(
                              song.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              [song.artist, song.album]
                                  .whereType<String>()
                                  .where((s) => s.isNotEmpty)
                                  .join(' · '),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.6),
                                fontSize: 12.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(color: Colors.white12, height: 1),
                ListTile(
                  leading: const Icon(
                    Icons.playlist_play_rounded,
                    color: Colors.white70,
                  ),
                  title: Text(
                    context.l10n.playNext,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                  onTap: () async {
                    Navigator.of(sheetContext).pop();
                    final item = await playableItemForSongWithLocalFile(
                      client,
                      ref.read(downloadManagerProvider),
                      song,
                    );
                    await ref.read(audioPlayerProvider).insertNext(item);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            context.l10n.addedToPlayNext(song.title),
                          ),
                        ),
                      );
                    }
                  },
                ),
                ListTile(
                  leading: Icon(
                    liveIsFavorite
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    color: liveIsFavorite
                        ? const Color(0xFFFF453A)
                        : Colors.white70,
                  ),
                  title: Text(
                    liveIsFavorite
                        ? context.l10n.unfavorite
                        : context.l10n.favorite,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                  onTap: () async {
                    Navigator.of(sheetContext).pop();
                    try {
                      await ref.read(starredProvider.notifier).toggleSong(song);
                    } catch (error) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              context.l10n.starFailed(error.toString()),
                            ),
                          ),
                        );
                      }
                    }
                  },
                ),
                ListTile(
                  leading: const Icon(
                    Icons.download_outlined,
                    color: Colors.white70,
                  ),
                  title: Text(
                    context.l10n.downloadSong,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                  onTap: () async {
                    Navigator.of(sheetContext).pop();
                    final manager = ref.read(downloadManagerProvider);
                    if (manager != null) {
                      await manager.downloadSong(song);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              context.l10n.addedToDownloads(song.title),
                            ),
                          ),
                        );
                      }
                    }
                  },
                ),
                if (song.albumId != null)
                  ListTile(
                    leading: const Icon(
                      Icons.album_outlined,
                      color: Colors.white70,
                    ),
                    title: Text(
                      context.l10n.viewAlbum,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                    ),
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      context.go('/albums/${song.albumId}');
                    },
                  ),
                if (song.artistId != null)
                  ListTile(
                    leading: const Icon(
                      Icons.person_outline_rounded,
                      color: Colors.white70,
                    ),
                    title: Text(
                      context.l10n.viewArtist,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                    ),
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      context.go('/artists/${song.artistId}');
                    },
                  ),
                const SizedBox(height: 8),
              ],
            ),
          );
        },
      );
    },
  );
}

/// Helper to resolve the best image URL for an artist from SubsonicClient
String? resolveArtistImageUrl({
  required Artist artist,
  SubsonicClient? client,
  int size = 300,
}) {
  // 1. If artist has explicit coverArt (e.g. 'ar-...' or album ID) from server
  if (artist.coverArt != null && artist.coverArt!.trim().isNotEmpty) {
    if (client != null) {
      return client.coverArtUrl(artist.coverArt!.trim(), size: size);
    }
  }

  // 2. If artistImageUrl is present from server
  if (artist.artistImageUrl != null &&
      artist.artistImageUrl!.trim().isNotEmpty) {
    final url = artist.artistImageUrl!.trim();
    if (url.startsWith('http://') || url.startsWith('https://')) {
      return url;
    }
    if (client != null) {
      return client.coverArtUrl(url, size: size);
    }
  }

  // 3. Fallback to Navidrome / OpenSubsonic canonical artist cover ID: 'ar-<artist_id>'
  if (client != null && artist.id.isNotEmpty) {
    final coverId = artist.id.startsWith('ar-') ? artist.id : 'ar-${artist.id}';
    return client.coverArtUrl(coverId, size: size);
  }

  return null;
}

/// Generates a consistent, attractive gradient for an artist placeholder based on their name hash
LinearGradient artistPlaceholderGradient(String name) {
  final hash = name.codeUnits.fold(0, (acc, c) => (acc * 31 + c) & 0xFFFFFF);
  const palettes = <List<Color>>[
    [Color(0xFF1E3A5F), Color(0xFF3498DB)],
    [Color(0xFF1E3C72), Color(0xFF2A5298)],
    [Color(0xFF2C3E50), Color(0xFF4CA1AF)],
    [Color(0xFF3B1E54), Color(0xFF9B59B6)],
    [Color(0xFF0F2027), Color(0xFF203A43)],
    [Color(0xFF2C3E50), Color(0xFFE74C3C)],
    [Color(0xFF134E5E), Color(0xFF71B280)],
    [Color(0xFF4B1248), Color(0xFFF0C27B)],
    [Color(0xFF283048), Color(0xFF859398)],
    [Color(0xFF16222A), Color(0xFF3A6073)],
    [Color(0xFF1D2671), Color(0xFFC33764)],
    [Color(0xFF4A00E0), Color(0xFF8E2DE2)],
  ];
  final colors = palettes[hash % palettes.length];
  return LinearGradient(
    colors: colors,
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

class ArtistAvatar extends StatelessWidget {
  const ArtistAvatar({
    required this.artist,
    this.client,
    this.imageUrl,
    this.radius = 28,
    this.showBorder = true,
    this.borderColor,
    this.borderWidth = 1.2,
    super.key,
  });

  final Artist artist;
  final SubsonicClient? client;
  final String? imageUrl;
  final double radius;
  final bool showBorder;
  final Color? borderColor;
  final double borderWidth;

  @override
  Widget build(BuildContext context) {
    final effectiveImageUrl =
        imageUrl ??
        resolveArtistImageUrl(
          artist: artist,
          client: client,
          size: (radius * 3).toInt().clamp(120, 600),
        );

    final initial = artist.name.trim().isEmpty
        ? '?'
        : artist.name.trim().characters.first.toUpperCase();

    Widget placeholder = Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: artistPlaceholderGradient(artist.name),
      ),
      child: Center(
        child: Text(
          initial,
          style: TextStyle(
            color: Colors.white,
            fontSize: radius * 0.72,
            fontWeight: FontWeight.bold,
            letterSpacing: -0.5,
          ),
        ),
      ),
    );

    Widget imageContent = effectiveImageUrl == null
        ? placeholder
        : CachedNetworkImage(
            imageUrl: effectiveImageUrl,
            fit: BoxFit.cover,
            fadeInDuration: const Duration(milliseconds: 150),
            fadeOutDuration: Duration.zero,
            placeholder: (context, url) => placeholder,
            errorWidget: (context, url, error) => placeholder,
          );

    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: showBorder
            ? Border.all(
                color: borderColor ?? Colors.white.withValues(alpha: 0.12),
                width: borderWidth,
              )
            : null,
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipOval(child: imageContent),
    );
  }
}

class ArtistCard extends StatelessWidget {
  const ArtistCard({
    required this.artist,
    required this.onTap,
    this.client,
    this.imageUrl,
    this.onFavorite,
    this.isFavorite = false,
    this.showSubtitle = true,
    super.key,
  });

  final Artist artist;
  final VoidCallback onTap;
  final SubsonicClient? client;
  final String? imageUrl;
  final Future<void> Function()? onFavorite;
  final bool isFavorite;
  final bool showSubtitle;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              LayoutBuilder(
                builder: (context, constraints) {
                  final avatarSize = (constraints.maxWidth * 0.74).clamp(
                    56.0,
                    140.0,
                  );
                  return Stack(
                    alignment: Alignment.center,
                    children: <Widget>[
                      ArtistAvatar(
                        artist: artist,
                        client: client,
                        imageUrl: imageUrl,
                        radius: avatarSize / 2,
                      ),
                      if (onFavorite != null)
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            decoration: BoxDecoration(
                              color: const Color(
                                0xFF1E2028,
                              ).withValues(alpha: 0.9),
                              shape: BoxShape.circle,
                              boxShadow: <BoxShadow>[
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.4),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: StarButton(
                              isStarred: isFavorite,
                              onPressed: onFavorite!,
                              size: 15,
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 10),
              Text(
                artist.name.isEmpty ? context.l10n.unknownArtist : artist.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.2,
                ),
              ),
              if (showSubtitle &&
                  artist.albumCount != null &&
                  artist.albumCount! > 0) ...[
                const SizedBox(height: 3),
                Text(
                  context.l10n.artistAlbumCount(artist.albumCount!),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 11.5,
                  ),
                ),
              ],
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
    this.client,
    this.imageUrl,
    this.onFavorite,
    this.isFavorite = false,
    super.key,
  });

  final Artist artist;
  final VoidCallback onTap;
  final SubsonicClient? client;
  final String? imageUrl;
  final Future<void> Function()? onFavorite;
  final bool isFavorite;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            children: <Widget>[
              ArtistAvatar(
                artist: artist,
                client: client,
                imageUrl: imageUrl,
                radius: 25,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      artist.name.isEmpty
                          ? context.l10n.unknownArtist
                          : artist.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.2,
                      ),
                    ),
                    if (artist.albumCount != null &&
                        artist.albumCount! > 0) ...[
                      const SizedBox(height: 3),
                      Row(
                        children: <Widget>[
                          Icon(
                            Icons.album_outlined,
                            size: 13,
                            color: Colors.white.withValues(alpha: 0.45),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            context.l10n.artistAlbumCount(artist.albumCount!),
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.55),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              if (onFavorite != null)
                StarButton(
                  isStarred: isFavorite,
                  onPressed: onFavorite!,
                  size: 18,
                ),
              const SizedBox(width: 2),
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: Colors.white.withValues(alpha: 0.25),
              ),
            ],
          ),
        ),
      ),
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
            Icon(
              Icons.cloud_off,
              size: 64,
              color: Colors.white.withValues(alpha: 0.4),
            ),
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
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

/// Shown when a server row exists but its secure credential could not be
/// resolved (e.g. secure storage read failed). Mirrors [NoServerView] so a
/// missing credential renders as a readable state instead of crashing the
/// widget tree with a null assertion.
class ServerCredentialUnavailableView extends StatelessWidget {
  const ServerCredentialUnavailableView({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.key_off,
              size: 64,
              color: Colors.white.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 14),
            Text(
              context.l10n.serverCredentialUnavailableTitle,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              context.l10n.serverCredentialUnavailableMessage,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () => context.go('/welcome'),
              icon: const Icon(Icons.dns_outlined, size: 18),
              label: Text(context.l10n.goToServerPicker),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF1E7BF6),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
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
