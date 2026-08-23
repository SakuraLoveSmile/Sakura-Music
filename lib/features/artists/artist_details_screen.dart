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
import '../shared/media_widgets.dart';

class ArtistDetailsScreen extends ConsumerWidget {
  const ArtistDetailsScreen({required this.artistId, super.key});

  final String artistId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final artist = ref.watch(artistDetailsProvider(artistId));
    final info = ref.watch(artistInfoProvider(artistId));
    final client = ref.watch(activeSubsonicClientProvider);
    if (client == null) {
      return const NoServerView();
    }
    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: SafeArea(
        child: artist.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => Center(child: Text('加载歌手失败：$error')),
          data: (value) {
            final details = info.value;
            final songs = value.albums
                .expand((album) => album.songs)
                .take(5)
                .toList(growable: false);
            final starredIds = ref.watch(starredIdsProvider);
            final imageUrl = details?.coverArt == null
                ? (details?.largeImageUrl ?? details?.mediumImageUrl)
                : client.coverArtUrl(details!.coverArt!, size: 640);
            final palette = imageUrl == null
                ? null
                : ref.watch(artworkPaletteProvider(imageUrl)).value;
            return CustomScrollView(
              slivers: <Widget>[
                SliverAppBar(
                  title: Text(value.name),
                  pinned: true,
                  leading: IconButton(
                    tooltip: '返回',
                    onPressed: () {
                      if (context.canPop()) {
                        context.pop();
                      } else {
                        context.go('/artists');
                      }
                    },
                    icon: const Icon(Icons.arrow_back),
                  ),
                ),
                SliverToBoxAdapter(
                  child: _ArtistHeader(
                    artist: value,
                    imageUrl: imageUrl,
                    isFavorite: starredIds.artists.contains(value.id),
                    onFavorite: () =>
                        ref.read(starredProvider.notifier).toggleArtist(value),
                    palette: palette,
                    biography: info.when(
                      loading: () => null,
                      error: (error, stackTrace) => null,
                      data: (artistInfo) => artistInfo.biography,
                    ),
                  ),
                ),
                if (songs.isNotEmpty)
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                    sliver: SliverMainAxisGroup(
                      slivers: <Widget>[
                        const SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.fromLTRB(8, 8, 8, 4),
                            child: Text(
                              '热门歌曲',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        SliverList.builder(
                          itemCount: songs.length,
                          itemBuilder: (context, index) {
                            final song = songs[index];
                            return SongListTile(
                              song: song,
                              client: client,
                              onTap: () =>
                                  _playSongs(context, ref, songs, index),
                              isFavorite: starredIds.songs.contains(song.id),
                              onFavorite: () async {
                                try {
                                  await ref
                                      .read(starredProvider.notifier)
                                      .toggleSong(song);
                                } catch (error) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('收藏失败：$error')),
                                    );
                                  }
                                }
                              },
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(20, 18, 20, 12),
                    child: Text(
                      '专辑',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                  sliver: SliverLayoutBuilder(
                    builder: (context, constraints) {
                      final columns = (constraints.crossAxisExtent / 170)
                          .floor()
                          .clamp(2, 8)
                          .toInt();
                      return SliverGrid.builder(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: columns,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 20,
                          childAspectRatio: 0.78,
                        ),
                        itemCount: value.albums.length,
                        itemBuilder: (context, index) {
                          final album = value.albums[index];
                          return AlbumCard(
                            album: album,
                            client: client,
                            onTap: () => context.go('/albums/${album.id}'),
                            isFavorite: starredIds.albums.contains(album.id),
                            onFavorite: () async {
                              try {
                                await ref
                                    .read(starredProvider.notifier)
                                    .toggleAlbum(album);
                              } catch (error) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('收藏失败：$error')),
                                  );
                                }
                              }
                            },
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ArtistHeader extends StatelessWidget {
  const _ArtistHeader({
    required this.artist,
    required this.imageUrl,
    required this.isFavorite,
    required this.onFavorite,
    required this.palette,
    required this.biography,
  });

  final Artist artist;
  final String? imageUrl;
  final bool isFavorite;
  final Future<void> Function() onFavorite;
  final ArtworkPalette? palette;
  final String? biography;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: palette == null
            ? null
            : LinearGradient(
                colors: <Color>[
                  palette!.vibrant.withValues(alpha: .24),
                  palette!.muted.withValues(alpha: .08),
                  Colors.transparent,
                ],
              ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                CircleAvatar(
                  radius: 58,
                  backgroundImage: imageUrl == null
                      ? null
                      : CachedNetworkImageProvider(imageUrl!),
                  child: imageUrl == null
                      ? Text(
                          artist.name.isEmpty
                              ? '?'
                              : artist.name.substring(0, 1).toUpperCase(),
                          style: const TextStyle(fontSize: 36),
                        )
                      : null,
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Text(
                    artist.name,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                ),
                StarButton(
                  isStarred: isFavorite,
                  onPressed: onFavorite,
                  filled: true,
                ),
              ],
            ),
            if (biography != null && biography!.trim().isNotEmpty)
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: const Text('简介'),
                children: <Widget>[
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(biography!),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

Future<void> _playSongs(
  BuildContext context,
  WidgetRef ref,
  List<Song> songs,
  int index,
) async {
  final client = ref.read(activeSubsonicClientProvider);
  if (client == null || songs.isEmpty) {
    return;
  }
  final items = await playableItemsForSongsWithLocalFiles(
    client,
    ref.read(downloadManagerProvider),
    songs,
  );
  try {
    final service = ref.read(audioPlayerProvider);
    await service.setQueue(items, startIndex: index);
    await service.play();
    if (context.mounted) {
      context.push('/player');
    }
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('播放失败：$error')));
    }
  }
}
