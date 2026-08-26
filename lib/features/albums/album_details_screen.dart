import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:subsonic_api/subsonic_api.dart';

import '../../audio/audio_player_provider.dart';
import '../../audio/playable_item_builder.dart';
import '../../core/artwork_palette.dart';
import '../../core/providers.dart';
import '../../data/download_manager.dart';
import '../../l10n/l10n.dart';
import '../shared/media_widgets.dart';

class AlbumDetailsScreen extends ConsumerWidget {
  const AlbumDetailsScreen({required this.albumId, super.key});

  final String albumId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final album = ref.watch(albumDetailsProvider(albumId));
    final client = ref.watch(activeSubsonicClientProvider);
    final starredIds = ref.watch(starredIdsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF131418),
      appBar: AppBar(
        backgroundColor: const Color(0xFF131418),
        elevation: 0,
        leading: IconButton(
          tooltip: context.l10n.back,
          icon: const Icon(
            Icons.chevron_left_rounded,
            size: 28,
            color: Colors.white,
          ),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/albums');
            }
          },
        ),
        title: album.whenOrNull(
          data: (val) => Text(
            val.name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
      body: album.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: Color(0xFF1E7BF6)),
        ),
        error: (error, stackTrace) => _AlbumDetailsError(error: error),
        data: (value) {
          final imageUrl = value.coverArt == null || client == null
              ? null
              : client.coverArtUrl(value.coverArt!, size: 600);
          final palette = imageUrl == null
              ? null
              : ref.watch(artworkPaletteProvider(imageUrl)).value;
          final isStarred = starredIds.albums.contains(value.id);

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: CustomScrollView(
                slivers: <Widget>[
                  // Album Header Banner
                  SliverToBoxAdapter(
                    child: _AlbumHeader(
                      album: value,
                      imageUrl: imageUrl,
                      palette: palette,
                      isFavorite: isStarred,
                      onFavorite: () =>
                          ref.read(starredProvider.notifier).toggleAlbum(value),
                      onPlayAll: () => _playSongs(context, ref, value, 0),
                      onShuffleAll: () =>
                          _playSongs(context, ref, value, 0, shuffle: true),
                    ),
                  ),

                  // Song Listing
                  if (value.songs.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Text(
                          context.l10n.albumEmptyTracks,
                          style: TextStyle(color: Colors.white54),
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(10, 8, 10, 36),
                      sliver: SliverList.builder(
                        itemCount: value.songs.length,
                        itemBuilder: (context, index) {
                          final song = value.songs[index];
                          final isSongStarred = starredIds.songs.contains(
                            song.id,
                          );

                          return SongListTile(
                            index: index + 1,
                            song: song,
                            client: client,
                            isFavorite: isSongStarred,
                            onFavorite: () => ref
                                .read(starredProvider.notifier)
                                .toggleSong(song),
                            onMore: () {
                              if (client == null) {
                                return;
                              }
                              showSongActionBottomSheet(
                                context: context,
                                ref: ref,
                                song: song,
                                client: client,
                              );
                            },
                            onTap: () => _playSongs(context, ref, value, index),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _AlbumHeader extends StatelessWidget {
  const _AlbumHeader({
    required this.album,
    required this.imageUrl,
    required this.palette,
    required this.isFavorite,
    required this.onFavorite,
    required this.onPlayAll,
    required this.onShuffleAll,
  });

  final Album album;
  final String? imageUrl;
  final ArtworkPalette? palette;
  final bool isFavorite;
  final Future<void> Function() onFavorite;
  final VoidCallback onPlayAll;
  final VoidCallback onShuffleAll;

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= 600;

    final coverWidget = SizedBox.square(
      dimension: isWide ? 140 : 105,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: imageUrl == null
            ? Container(
                color: const Color(0xFF22242D),
                child: const Icon(
                  Icons.album_rounded,
                  size: 56,
                  color: Colors.white24,
                ),
              )
            : CachedNetworkImage(
                imageUrl: imageUrl!,
                cacheKey: 'cover_${album.coverArt}_400',
                fit: BoxFit.cover,
                fadeInDuration: Duration.zero,
                fadeOutDuration: Duration.zero,
                errorWidget: (context, url, error) => Container(
                  color: const Color(0xFF22242D),
                  child: const Icon(
                    Icons.album_rounded,
                    size: 56,
                    color: Colors.white24,
                  ),
                ),
              ),
      ),
    );

    final infoWidget = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          album.name,
          style: TextStyle(
            color: Colors.white,
            fontSize: isWide ? 20 : 17,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          album.artist ?? context.l10n.unknownArtist,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.75),
            fontSize: isWide ? 14 : 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          <String>[
            if (album.year != null) '${album.year}',
            if (album.songCount != null)
              context.l10n.songCountLabel(album.songCount!),
            if (album.genre != null) album.genre!,
            if (album.duration != null) formatSongDuration(album.duration),
          ].join(' · '),
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.4),
            fontSize: 12,
          ),
        ),
      ],
    );

    final actionsWidget = Row(
      children: <Widget>[
        Expanded(
          flex: isWide ? 0 : 1,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF1E7BF6),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            onPressed: onPlayAll,
            icon: const Icon(Icons.play_arrow_rounded, size: 20),
            label: Text(
              context.l10n.playAll,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: isWide ? 0 : 1,
          child: FilledButton.tonalIcon(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF2A2C37),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            onPressed: onShuffleAll,
            icon: const Icon(Icons.shuffle_rounded, size: 18),
            label: Text(context.l10n.shufflePlay),
          ),
        ),
        const SizedBox(width: 8),
        StarButton(isStarred: isFavorite, size: 22, onPressed: onFavorite),
      ],
    );

    return Container(
      margin: EdgeInsets.fromLTRB(isWide ? 16 : 10, 8, isWide ? 16 : 10, 10),
      padding: EdgeInsets.all(isWide ? 20 : 14),
      decoration: BoxDecoration(
        color: const Color(0xFF1B1C23),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        gradient: palette == null
            ? null
            : LinearGradient(
                colors: <Color>[
                  palette!.vibrant.withValues(alpha: 0.22),
                  const Color(0xFF1B1C23),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
      ),
      child: isWide
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                coverWidget,
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      infoWidget,
                      const SizedBox(height: 18),
                      actionsWidget,
                    ],
                  ),
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    coverWidget,
                    const SizedBox(width: 14),
                    Expanded(child: infoWidget),
                  ],
                ),
                const SizedBox(height: 14),
                actionsWidget,
              ],
            ),
    );
  }
}

class _AlbumDetailsError extends StatelessWidget {
  const _AlbumDetailsError({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          context.l10n.albumLoadFailed(error.toString()),
          style: const TextStyle(color: Colors.white70),
        ),
      ),
    );
  }
}

Future<void> _playSongs(
  BuildContext context,
  WidgetRef ref,
  Album album,
  int startIndex, {
  bool shuffle = false,
}) async {
  final client = ref.read(activeSubsonicClientProvider);
  if (client == null) return;

  final items = await playableItemsForSongsWithLocalFiles(
    client,
    ref.read(downloadManagerProvider),
    album.songs,
    fallbackAlbum: album.name,
    fallbackCoverArt: album.coverArt,
  );
  try {
    final service = ref.read(audioPlayerProvider);
    if (shuffle) {
      final list = [...items]..shuffle();
      await service.setQueue(list, startIndex: 0);
    } else {
      await service.setQueue(items, startIndex: startIndex);
    }
    await service.play();
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.playbackFailed(error.toString()))),
      );
    }
  }
}
