import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:subsonic_api/subsonic_api.dart';

import '../../audio/audio_player_provider.dart';
import '../../audio/playable_item_builder.dart';
import '../../core/providers.dart';
import '../../data/download_manager.dart';
import '../shared/media_widgets.dart';

class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final client = ref.watch(activeSubsonicClientProvider);
    if (client == null) {
      return const SafeArea(child: NoServerView());
    }
    final starred = ref.watch(starredProvider);
    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: DefaultTabController(
        length: 3,
        child: SafeArea(
          child: NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) => <Widget>[
              SliverAppBar(
                title: const Text('收藏'),
                floating: true,
                pinned: true,
                bottom: const TabBar(
                  tabs: <Widget>[
                    Tab(text: '歌曲'),
                    Tab(text: '专辑'),
                    Tab(text: '歌手'),
                  ],
                ),
                actions: <Widget>[
                  IconButton(
                    tooltip: '下载',
                    onPressed: () => context.go('/downloads'),
                    icon: const Icon(Icons.download_outlined),
                  ),
                  IconButton(
                    tooltip: '刷新',
                    onPressed: () => ref.invalidate(starredProvider),
                    icon: const Icon(Icons.refresh),
                  ),
                ],
              ),
            ],
            body: starred.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stackTrace) =>
                  Center(child: Text('加载收藏失败：$error')),
              data: (value) => TabBarView(
                children: <Widget>[
                  _FavoriteSongs(songs: value.songs, client: client, ref: ref),
                  _FavoriteAlbums(
                    albums: value.albums,
                    client: client,
                    ref: ref,
                  ),
                  _FavoriteArtists(artists: value.artists, ref: ref),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FavoriteSongs extends StatelessWidget {
  const _FavoriteSongs({
    required this.songs,
    required this.client,
    required this.ref,
  });

  final List<Song> songs;
  final SubsonicClient client;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    if (songs.isEmpty) {
      return const Center(child: Text('还没有收藏歌曲。'));
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 32),
      itemCount: songs.length,
      itemBuilder: (context, index) {
        final song = songs[index];
        return SongListTile(
          song: song,
          client: client,
          isFavorite: true,
          onFavorite: () async {
            try {
              await ref.read(starredProvider.notifier).toggleSong(song);
            } catch (error) {
              if (context.mounted) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text('取消收藏失败：$error')));
              }
            }
          },
          onTap: () async {
            final items = await playableItemsForSongsWithLocalFiles(
              client,
              ref.read(downloadManagerProvider),
              songs,
            );
            final service = ref.read(audioPlayerProvider);
            await service.setQueue(items, startIndex: index);
            await service.play();
            if (context.mounted) {
              context.go('/player');
            }
          },
        );
      },
    );
  }
}

class _FavoriteAlbums extends StatelessWidget {
  const _FavoriteAlbums({
    required this.albums,
    required this.client,
    required this.ref,
  });

  final List<Album> albums;
  final SubsonicClient client;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    if (albums.isEmpty) {
      return const Center(child: Text('还没有收藏专辑。'));
    }
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 180,
        crossAxisSpacing: 16,
        mainAxisSpacing: 20,
        childAspectRatio: 0.78,
      ),
      itemCount: albums.length,
      itemBuilder: (context, index) {
        final album = albums[index];
        return AlbumCard(
          album: album,
          client: client,
          isFavorite: true,
          onFavorite: () async {
            try {
              await ref.read(starredProvider.notifier).toggleAlbum(album);
            } catch (error) {
              if (context.mounted) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text('取消收藏失败：$error')));
              }
            }
          },
          onTap: () => context.go('/albums/${album.id}'),
        );
      },
    );
  }
}

class _FavoriteArtists extends StatelessWidget {
  const _FavoriteArtists({required this.artists, required this.ref});

  final List<Artist> artists;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    if (artists.isEmpty) {
      return const Center(child: Text('还没有收藏歌手。'));
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 32),
      itemCount: artists.length,
      itemBuilder: (context, index) {
        final artist = artists[index];
        return ArtistListTile(
          artist: artist,
          isFavorite: true,
          onFavorite: () async {
            try {
              await ref.read(starredProvider.notifier).toggleArtist(artist);
            } catch (error) {
              if (context.mounted) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text('取消收藏失败：$error')));
              }
            }
          },
          onTap: () => context.go('/artists/${artist.id}'),
        );
      },
    );
  }
}
