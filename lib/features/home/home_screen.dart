import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:subsonic_api/subsonic_api.dart';

import '../../audio/audio_player_provider.dart';
import '../../audio/playable_item_builder.dart';
import '../../core/providers.dart';
import '../../data/download_manager.dart';
import '../../data/server_repository.dart';
import '../webdav/webdav_browse_screen.dart';
import '../../l10n/l10n.dart';
import '../shared/media_widgets.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final server = ref.watch(activeServerProvider);
    if (server == null) {
      return const SafeArea(child: NoServerView());
    }
    // WebDAV sources have no Subsonic-style home: route to the file browser.
    if (server.type == 'webdav') {
      return const SafeArea(child: WebDavBrowseScreen());
    }
    final client = ref.watch(activeSubsonicClientProvider)!;
    final starred = ref.watch(starredIdsProvider);
    final playerService = ref.watch(audioPlayerProvider);

    return StreamBuilder<String?>(
      stream: playerService.snapshot
          .map((state) => state.currentItem?.id)
          .distinct(),
      initialData: playerService.currentSnapshot?.currentItem?.id,
      builder: (context, snapshot) {
        final currentSongId = snapshot.data;

        return Material(
          color: Theme.of(context).colorScheme.surface,
          child: SafeArea(
            child: RefreshIndicator(
              onRefresh: () async {
                // Recent plays and top-played are live Drift streams that
                // refresh automatically; the daily mix is intentionally
                // cached per day, so only album lists are refreshed here.
                ref
                  ..invalidate(newestAlbumsProvider)
                  ..invalidate(frequentAlbumsProvider)
                  ..invalidate(randomAlbumsProvider);
              },
              child: CustomScrollView(
                slivers: <Widget>[
                  // Top Big Recommendation Banner
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
                      child: _DailyRecommendationBanner(client: client),
                    ),
                  ),

                  // 最近新增 (Horizontal scroll)
                  SliverToBoxAdapter(
                    child: _HorizontalAlbumSection(
                      title: context.l10n.recentlyAdded,
                      provider: newestAlbumsProvider,
                      client: client,
                      starred: starred,
                      onViewMore: () => context.go('/albums'),
                    ),
                  ),

                  // 最近播放 & 最常播放 (Two-column song grids)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
                      child: _TwoColumnSongsSection(
                        client: client,
                        starred: starred,
                        currentSongId: currentSongId,
                      ),
                    ),
                  ),

                  // 随机专辑 (Horizontal scroll)
                  SliverToBoxAdapter(
                    child: _HorizontalAlbumSection(
                      title: context.l10n.randomAlbums,
                      provider: randomAlbumsProvider,
                      client: client,
                      starred: starred,
                      onRefresh: () => ref.invalidate(randomAlbumsProvider),
                    ),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 36)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _DailyRecommendationBanner extends ConsumerWidget {
  const _DailyRecommendationBanner({required this.client});

  final SubsonicClient client;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dailySongs = ref.watch(dailyRecommendSongsProvider);

    return Container(
      height: 200,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          colors: <Color>[
            Color(0xFF1E3A5F),
            Color(0xFF192238),
            Color(0xFF14151B),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: const Color(0xFF1E7BF6).withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: <Widget>[
          // Decorative background ambient circles
          Positioned(
            right: -40,
            top: -40,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF1E7BF6).withValues(alpha: 0.18),
              ),
            ),
          ),
          Positioned(
            left: 200,
            bottom: -50,
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF6C5CE7).withValues(alpha: 0.12),
              ),
            ),
          ),

          // Main Banner Content
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: <Widget>[
                // Left Text Column
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      // Tag
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E7BF6),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: <BoxShadow>[
                            BoxShadow(
                              color: const Color(
                                0xFF1E7BF6,
                              ).withValues(alpha: 0.4),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Text(
                          context.l10n.dailyRecommend,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),

                      // Featured Title
                      dailySongs.maybeWhen(
                        data: (songs) {
                          final firstTitle = songs.isNotEmpty
                              ? songs.first.title
                              : context.l10n.dailyMixTitle;
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                firstTitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  letterSpacing: 0.4,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                songs.isNotEmpty && songs.first.artist != null
                                    ? songs.first.artist!
                                    : context.l10n.dailyMixSubtitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.white.withValues(alpha: 0.7),
                                ),
                              ),
                            ],
                          );
                        },
                        orElse: () => Text(
                          context.l10n.dailyMixTitle,
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                      ),

                      // Bottom Info link
                      InkWell(
                        onTap: () => context.go('/songs'),
                        borderRadius: BorderRadius.circular(6),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              dailySongs.maybeWhen(
                                data: (songs) => Text(
                                  context.l10n.songCountText(songs.length),
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    color: Colors.white.withValues(alpha: 0.6),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                orElse: () => const SizedBox.shrink(),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                context.l10n.viewAll,
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  color: Color(0xFF5BA4FF),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Right Big Play Button
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(36),
                    onTap: () async {
                      final songs = dailySongs.value;
                      if (songs == null || songs.isEmpty) return;
                      final items = await playableItemsForSongsWithLocalFiles(
                        client,
                        ref.read(downloadManagerProvider),
                        songs,
                      );
                      final service = ref.read(audioPlayerProvider);
                      await service.setQueue(items, startIndex: 0);
                      await service.play();
                    },
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF1E7BF6),
                        boxShadow: <BoxShadow>[
                          BoxShadow(
                            color: const Color(
                              0xFF1E7BF6,
                            ).withValues(alpha: 0.5),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.play_arrow_rounded,
                        size: 38,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HorizontalAlbumSection extends ConsumerWidget {
  const _HorizontalAlbumSection({
    required this.title,
    required this.provider,
    required this.client,
    required this.starred,
    this.onViewMore,
    this.onRefresh,
  });

  final String title;
  final FutureProvider<List<Album>> provider;
  final SubsonicClient client;
  final ({Set<String> songs, Set<String> albums, Set<String> artists}) starred;
  final VoidCallback? onViewMore;
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(provider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 0, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Header Row
          Padding(
            padding: const EdgeInsets.only(right: 20),
            child: Row(
              children: <Widget>[
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const Spacer(),
                if (onViewMore != null)
                  InkWell(
                    onTap: onViewMore,
                    borderRadius: BorderRadius.circular(4),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 4,
                      ),
                      child: Row(
                        children: <Widget>[
                          Text(
                            context.l10n.more,
                            style: TextStyle(
                              fontSize: 12.5,
                              color: Colors.white.withValues(alpha: 0.55),
                            ),
                          ),
                          Icon(
                            Icons.chevron_right_rounded,
                            size: 16,
                            color: Colors.white.withValues(alpha: 0.55),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (onRefresh != null)
                  TextButton.icon(
                    onPressed: onRefresh,
                    icon: const Icon(Icons.refresh_rounded, size: 16),
                    label: Text(
                      context.l10n.refreshBatch,
                      style: const TextStyle(fontSize: 12.5),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Horizontal List
          SizedBox(
            height: 228,
            child: value.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: Color(0xFF1E7BF6)),
              ),
              error: (error, stack) => Row(
                children: <Widget>[
                  const Icon(Icons.error_outline, color: Colors.white54),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      context.l10n.loadFailed(error.toString()),
                      style: const TextStyle(color: Colors.white54),
                    ),
                  ),
                ],
              ),
              data: (albums) => albums.isEmpty
                  ? Center(
                      child: Text(
                        context.l10n.noContentYet,
                        style: TextStyle(color: Colors.white38),
                      ),
                    )
                  : ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.only(right: 20),
                      itemCount: albums.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(width: 14),
                      itemBuilder: (context, index) {
                        final album = albums[index];
                        final isFavorite = starred.albums.contains(album.id);

                        return SizedBox(
                          width: 146,
                          child: AlbumCard(
                            album: album,
                            client: client,
                            isFavorite: isFavorite,
                            onFavorite: () => ref
                                .read(starredProvider.notifier)
                                .toggleAlbum(album),
                            onTap: () => context.go('/albums/${album.id}'),
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TwoColumnSongsSection extends ConsumerWidget {
  const _TwoColumnSongsSection({
    required this.client,
    required this.starred,
    required this.currentSongId,
  });

  final SubsonicClient client;
  final ({Set<String> songs, Set<String> albums, Set<String> artists}) starred;
  final String? currentSongId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recentPlays = ref.watch(recentPlaysProvider);
    final frequentSongs = ref.watch(frequentSongsProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 760;

        final recentColumn = _buildSongColumn(
          context: context,
          ref: ref,
          title: context.l10n.recentlyPlayed,
          songsAsync: recentPlays.whenData((plays) {
            return plays
                .map(
                  (play) => Song(
                    id: play.songId,
                    title: play.title ?? play.songId,
                    artist: play.artist,
                    album: play.album,
                    albumId: play.albumId,
                    artistId: play.artistId,
                  ),
                )
                .toList();
          }),
          onMore: () => context.go('/songs'),
        );

        final frequentColumn = _buildSongColumn(
          context: context,
          ref: ref,
          title: context.l10n.frequentlyPlayed,
          songsAsync: frequentSongs,
          onMore: () => context.go('/songs'),
        );

        if (isWide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(child: recentColumn),
              const SizedBox(width: 20),
              Expanded(child: frequentColumn),
            ],
          );
        }

        return Column(
          children: <Widget>[
            recentColumn,
            const SizedBox(height: 20),
            frequentColumn,
          ],
        );
      },
    );
  }

  Widget _buildSongColumn({
    required BuildContext context,
    required WidgetRef ref,
    required String title,
    required AsyncValue<List<Song>> songsAsync,
    required VoidCallback onMore,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF191A20),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Header
          Row(
            children: <Widget>[
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const Spacer(),
              InkWell(
                onTap: onMore,
                borderRadius: BorderRadius.circular(4),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 2,
                  ),
                  child: Row(
                    children: <Widget>[
                      Text(
                        context.l10n.more,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.5),
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 15,
                        color: Colors.white.withValues(alpha: 0.5),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Content
          songsAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                child: SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFF1E7BF6),
                  ),
                ),
              ),
            ),
            error: (err, _) => Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                context.l10n.noData,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.4),
                  fontSize: 12,
                ),
              ),
            ),
            data: (songs) {
              if (songs.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text(
                      context.l10n.noSongHistory,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.35),
                        fontSize: 13,
                      ),
                    ),
                  ),
                );
              }

              final displayList = songs.take(5).toList();

              return Column(
                children: displayList.map((song) {
                  final isPlaying = currentSongId == song.id;
                  final isFav = starred.songs.contains(song.id);

                  return SongGridTile(
                    song: song,
                    client: client,
                    isPlaying: isPlaying,
                    isFavorite: isFav,
                    onFavorite: () =>
                        ref.read(starredProvider.notifier).toggleSong(song),
                    onMore: () {
                      _showSongMoreSheet(context, ref, song, client);
                    },
                    onTap: () async {
                      final items = await playableItemsForSongsWithLocalFiles(
                        client,
                        ref.read(downloadManagerProvider),
                        songs,
                      );
                      final service = ref.read(audioPlayerProvider);
                      final idx = songs.indexOf(song);
                      await service.setQueue(
                        items,
                        startIndex: idx >= 0 ? idx : 0,
                      );
                      await service.play();
                    },
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  void _showSongMoreSheet(
    BuildContext context,
    WidgetRef ref,
    Song song,
    SubsonicClient client,
  ) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1E2028),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Text(
                  song.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.white,
                  ),
                ),
              ),
              const Divider(color: Colors.white12),
              ListTile(
                leading: const Icon(
                  Icons.playlist_play_rounded,
                  color: Colors.white70,
                ),
                title: Text(
                  context.l10n.playNext,
                  style: const TextStyle(color: Colors.white),
                ),
                onTap: () async {
                  Navigator.of(sheetContext).pop();
                  final item = await playableItemForSongWithLocalFile(
                    client,
                    ref.read(downloadManagerProvider),
                    song,
                  );
                  await ref.read(audioPlayerProvider).insertNext(item);
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
                    style: const TextStyle(color: Colors.white),
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
                    style: const TextStyle(color: Colors.white),
                  ),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    context.go('/artists/${song.artistId}');
                  },
                ),
            ],
          ),
        );
      },
    );
  }
}
