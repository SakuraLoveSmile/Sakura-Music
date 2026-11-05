import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:subsonic_api/subsonic_api.dart';

import '../../audio/audio_player_provider.dart';
import '../../audio/playable_item_builder.dart';
import '../../core/providers.dart';
import '../../core/widgets/glass.dart';
import '../../data/db/app_database.dart';
import '../../data/download_manager.dart';
import '../../data/server_repository.dart';
import '../../l10n/l10n.dart';
import '../shared/media_widgets.dart';
import '../webdav/webdav_browse_screen.dart';

const _homeTitleStyle = TextStyle(
  fontSize: 32,
  fontWeight: FontWeight.w800,
  color: Colors.white,
  letterSpacing: -1,
  height: 1.2,
);

/// Formats audio specification details (Hi-Res / Lossless / Bitrate / Format / Duration).
String formatAudioSpecs(Song song) {
  final parts = <String>[];
  final ext = song.suffix?.toUpperCase();
  final isHiRes =
      (song.bitRate != null && song.bitRate! > 900) ||
      ext == 'FLAC' ||
      ext == 'WAV' ||
      ext == 'DSD' ||
      ext == 'ALAC';

  if (isHiRes) {
    parts.add('Hi-Res');
  } else if (song.bitRate != null && song.bitRate! >= 320) {
    parts.add('Lossless');
  }

  if (song.bitRate != null && song.bitRate! > 0) {
    parts.add('${song.bitRate}kbps');
  }
  if (ext != null && ext.isNotEmpty) {
    parts.add(ext);
  }
  if (song.duration != null && song.duration! > 0) {
    parts.add(formatSongDuration(song.duration));
  }
  return parts.join(' • ');
}

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final server = ref.watch(activeServerProvider);
    if (server == null) {
      return const SafeArea(child: NoServerView());
    }
    // WebDAV sources route to the WebDAV file browser.
    if (server.type == 'webdav') {
      return const SafeArea(child: WebDavBrowseScreen());
    }

    final client = ref.watch(activeSubsonicClientProvider);
    // A missing credential (secure storage read failure, upgrade edge case)
    // must degrade to a readable state, never crash the whole widget tree.
    if (client == null) {
      return const SafeArea(child: ServerCredentialUnavailableView());
    }
    final starred = ref.watch(starredIdsProvider);
    final playerService = ref.watch(audioPlayerProvider);

    return StreamBuilder<String?>(
      stream: playerService.snapshot
          .map((state) => state.currentItem?.id)
          .distinct(),
      initialData: playerService.currentSnapshot?.currentItem?.id,
      builder: (context, snapshot) {
        final currentSongId = snapshot.data;

        return GlassBackdrop(
          child: Material(
            color: Colors.transparent,
            child: SafeArea(
              child: RefreshIndicator(
                color: Theme.of(context).colorScheme.primary,
                onRefresh: () async {
                  ref
                    ..invalidate(dailyRecommendSongsProvider)
                    ..invalidate(randomSongsProvider)
                    ..invalidate(newestAlbumsProvider)
                    ..invalidate(playlistsProvider)
                    ..invalidate(libraryStatsProvider);
                },
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  slivers: <Widget>[
                    // 1. Top Header Bar
                    SliverLayoutBuilder(
                      builder: (context, constraints) {
                        final title = TextPainter(
                          text: const TextSpan(
                            text: 'SakuraMusic',
                            style: _homeTitleStyle,
                          ),
                          textScaler: MediaQuery.textScalerOf(context),
                          textDirection: Directionality.of(context),
                        )..layout();
                        // The action group is 148 wide and 52 high. Match the
                        // Wrap below so large text and phone widths get two rows.
                        final stacked =
                            title.width + 12 + 148 >
                            constraints.crossAxisExtent - 40;
                        final height = stacked
                            ? title.height + 90
                            : title.height.clamp(52.0, double.infinity) + 26;
                        title.dispose();
                        return SliverAppBar(
                          pinned: true,
                          primary: false,
                          automaticallyImplyLeading: false,
                          toolbarHeight: height,
                          titleSpacing: 20,
                          backgroundColor: Colors.transparent,
                          surfaceTintColor: Colors.transparent,
                          scrolledUnderElevation: 0,
                          flexibleSpace: Stack(
                            fit: StackFit.expand,
                            children: [
                              ProgressiveGlassBlur(height: height),
                              DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: MediaQuery.highContrastOf(context)
                                        ? const [
                                            Color(0xFF08090D),
                                            Color(0xFF08090D),
                                          ]
                                        : const [
                                            Color(0xB308090D),
                                            Color(0x0008090D),
                                          ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          title: SizedBox(
                            width: double.infinity,
                            child: _TopHeaderBar(server: server),
                          ),
                        );
                      },
                    ),

                    // 2. 5-Button Category Navigation
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(16, 4, 16, 16),
                        child: _CategoryNavBar(),
                      ),
                    ),

                    // 3. Featured / Daily Recommendation Card
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                        child: _FeaturedHeroCard(client: client),
                      ),
                    ),

                    // 4. 随机歌曲 (Random Songs with Audio Specs)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 20),
                        child: _RandomSongsSection(
                          client: client,
                          starred: starred,
                          currentSongId: currentSongId,
                        ),
                      ),
                    ),

                    // 5. 最近播放的歌曲 (Recently Played Songs - Horizontal Cards)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 20),
                        child: _RecentlyPlayedSongsSection(
                          client: client,
                          starred: starred,
                          currentSongId: currentSongId,
                        ),
                      ),
                    ),

                    // 6. 最近添加的歌曲 (Recently Added Songs - Horizontal Cards)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 20),
                        child: _RecentlyAddedSongsSection(
                          client: client,
                          starred: starred,
                          currentSongId: currentSongId,
                        ),
                      ),
                    ),

                    // 7. 最近更新的歌单 (Recently Updated Playlists)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 20),
                        child: _RecentlyUpdatedPlaylistsSection(client: client),
                      ),
                    ),

                    // 8. 媒体库统计面板 (Library Statistics 2x3 Grid)
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(16, 4, 16, 32),
                        child: _LibraryStatsGrid(),
                      ),
                    ),

                    const SliverToBoxAdapter(child: SizedBox(height: 36)),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// 1. Top Header with title and quick actions.
class _TopHeaderBar extends ConsumerWidget {
  const _TopHeaderBar({required this.server});

  final Server server;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final serversAsync = ref.watch(serversProvider);
    final primary = Theme.of(context).colorScheme.primary;

    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 12,
      runSpacing: 12,
      children: <Widget>[
        const Text('SakuraMusic', style: _homeTitleStyle),
        // Actions Container
        GlassSurface(
          blur: false,
          clear: true,
          padding: const EdgeInsets.all(4),
          borderRadius: BorderRadius.circular(30),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              // Search
              _HeaderIconButton(
                icon: Icons.search_rounded,
                tooltip: context.l10n.search,
                onTap: () => context.go('/search'),
              ),
              const SizedBox(width: 4),
              // Settings
              _HeaderIconButton(
                icon: Icons.settings_outlined,
                tooltip: context.l10n.settings,
                onTap: () => context.go('/settings'),
              ),
              const SizedBox(width: 4),
              // Server Switcher Disc
              PopupMenuButton<dynamic>(
                tooltip: context.l10n.switchLibrary,
                offset: const Offset(0, 44),
                color: const Color(0xFF22252E),
                elevation: 10,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                onSelected: (value) {
                  if (value is Server) {
                    ref.read(selectedServerIdProvider.notifier).state =
                        value.id;
                  } else if (value == 'manage_servers') {
                    context.go('/welcome');
                  }
                },
                itemBuilder: (context) {
                  final servers = serversAsync.value ?? <Server>[];
                  return <PopupMenuEntry<dynamic>>[
                    PopupMenuItem<dynamic>(
                      enabled: false,
                      child: Row(
                        children: <Widget>[
                          Icon(Icons.album_rounded, size: 16, color: primary),
                          const SizedBox(width: 8),
                          Text(
                            context.l10n.connectedLibraries,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const PopupMenuDivider(height: 1),
                    ...servers.map((s) {
                      final isCurrent = server.id == s.id;
                      return PopupMenuItem<dynamic>(
                        value: s,
                        child: Row(
                          children: <Widget>[
                            Icon(
                              isCurrent
                                  ? Icons.check_circle_rounded
                                  : Icons.circle_outlined,
                              size: 16,
                              color: isCurrent ? primary : Colors.white38,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                s.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: isCurrent ? primary : Colors.white,
                                  fontWeight: isCurrent
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                    const PopupMenuDivider(height: 1),
                    PopupMenuItem<dynamic>(
                      value: 'manage_servers',
                      child: Row(
                        children: <Widget>[
                          const Icon(
                            Icons.tune_rounded,
                            size: 16,
                            color: Colors.white70,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            context.l10n.serverManagement,
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ];
                },
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: primary.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: primary.withValues(alpha: 0.6),
                      width: 1.2,
                    ),
                  ),
                  child: Icon(Icons.album_rounded, size: 18, color: primary),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 44,
      child: IconButton(
        icon: Icon(icon, size: 21),
        tooltip: tooltip,
        onPressed: onTap,
      ),
    );
  }
}

/// 2. Five Quick Categories Navigation Bar (艺术家, 专辑, 歌曲, 歌单, 喜爱).
class _CategoryNavBar extends StatelessWidget {
  const _CategoryNavBar();

  @override
  Widget build(BuildContext context) {
    final items = <({String label, IconData icon, String route})>[
      (
        label: context.l10n.navArtists,
        icon: Icons.mic_external_on_rounded,
        route: '/artists',
      ),
      (
        label: context.l10n.navAlbums,
        icon: Icons.album_rounded,
        route: '/albums',
      ),
      (
        label: context.l10n.navSongs,
        icon: Icons.music_note_rounded,
        route: '/songs',
      ),
      (
        label: context.l10n.playlistsLabel,
        icon: Icons.queue_music_rounded,
        route: '/playlists',
      ),
      (
        label: context.l10n.myFavorites,
        icon: Icons.favorite_rounded,
        route: '/favorites',
      ),
    ];

    return GlassSurface(
      blur: false,
      clear: true,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: items.map((item) {
          return Expanded(
            child: InkWell(
              onTap: () => context.go(item.route),
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.06),
                        ),
                      ),
                      child: Icon(
                        item.icon,
                        color: item.route == '/favorites'
                            ? const Color(0xFFFF5252)
                            : Colors.white,
                        size: 21,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      item.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFFD6D9E2),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

/// 3. Featured / Daily Recommendation Card.
class _FeaturedHeroCard extends ConsumerWidget {
  const _FeaturedHeroCard({required this.client});

  final SubsonicClient client;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dailySongs = ref.watch(dailyRecommendSongsProvider);
    final primary = Theme.of(context).colorScheme.primary;

    return dailySongs.when(
      loading: () =>
          const GlassSurface(blur: false, child: SizedBox(height: 116)),
      error: (_, _) => const SizedBox.shrink(),
      data: (songs) {
        if (songs.isEmpty) return const SizedBox.shrink();
        final featuredSong = songs.first;
        final coverUrl = resolveSongCoverUrl(
          song: featuredSong,
          client: client,
          size: 240,
        );
        final coverId = resolveSongCoverArtId(featuredSong);

        Widget artwork() => coverUrl == null
            ? ColoredBox(
                color: primary.withValues(alpha: 0.14),
                child: const Icon(
                  Icons.music_note_rounded,
                  color: Colors.white38,
                  size: 30,
                ),
              )
            : CachedNetworkImage(
                imageUrl: coverUrl,
                cacheKey: coverId == null ? null : 'cover_${coverId}_240',
                fit: BoxFit.cover,
                errorWidget: (_, _, _) => ColoredBox(
                  color: primary.withValues(alpha: 0.14),
                  child: const Icon(
                    Icons.music_note_rounded,
                    color: Colors.white38,
                    size: 30,
                  ),
                ),
              );

        return LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 600;
            final radius = BorderRadius.circular(26);
            return ClipRSuperellipse(
              borderRadius: radius,
              child: Stack(
                children: <Widget>[
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: <Color>[
                            primary.withValues(alpha: 0.24),
                            const Color(0xFF29232E),
                          ],
                        ),
                      ),
                      child: coverUrl == null
                          ? null
                          : Opacity(opacity: 0.36, child: artwork()),
                    ),
                  ),
                  GlassSurface(
                    clear: true,
                    borderRadius: radius,
                    child: InkWell(
                      customBorder: RoundedSuperellipseBorder(
                        borderRadius: radius,
                      ),
                      onTap: () async {
                        final items = await playableItemsForSongsWithLocalFiles(
                          client,
                          ref.read(downloadManagerProvider),
                          songs,
                        );
                        final service = ref.read(audioPlayerProvider);
                        await service.setQueue(items, startIndex: 0);
                        await service.play();
                      },
                      child: Padding(
                        padding: EdgeInsets.all(wide ? 24 : 16),
                        child: Row(
                          children: <Widget>[
                            ClipRSuperellipse(
                              borderRadius: BorderRadius.circular(16),
                              child: SizedBox.square(
                                dimension: wide ? 96 : 64,
                                child: artwork(),
                              ),
                            ),
                            SizedBox(width: wide ? 22 : 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  Text(
                                    context.l10n.dailyRecommend,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white.withValues(
                                        alpha: 0.7,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 7),
                                  Text(
                                    featuredSong.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: wide ? 26 : 19,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: -0.4,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    [featuredSong.artist, featuredSong.album]
                                        .whereType<String>()
                                        .where((s) => s.isNotEmpty)
                                        .join(' · '),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.white.withValues(
                                        alpha: 0.65,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            // Refresh remains separate from the card's play
                            // action, including keyboard and semantics focus.
                            Material(
                              key: const Key('daily-recommend-shuffle-button'),
                              color: Colors.transparent,
                              child: InkWell(
                                customBorder: const CircleBorder(),
                                onTap: () => ref
                                    .read(dailyRecommendSongsProvider.notifier)
                                    .shuffle(),
                                child: Tooltip(
                                  message: context.l10n.refreshBatch,
                                  child: Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(
                                        alpha: 0.12,
                                      ),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white.withValues(
                                          alpha: 0.22,
                                        ),
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.refresh_rounded,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

/// 4. 随机歌曲 Section (Random Songs with Audio Specs & Favorite Heart).
class _RandomSongsSection extends ConsumerWidget {
  const _RandomSongsSection({
    required this.client,
    required this.starred,
    required this.currentSongId,
  });

  final SubsonicClient client;
  final ({Set<String> songs, Set<String> albums, Set<String> artists}) starred;
  final String? currentSongId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final songsAsync = ref.watch(randomSongsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        // Header Row
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  context.l10n.randomSongs,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.4,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              IconButton(
                icon: const Icon(
                  Icons.refresh_rounded,
                  size: 19,
                  color: Colors.white60,
                ),
                tooltip: context.l10n.refreshBatch,
                onPressed: () => ref.invalidate(randomSongsProvider),
              ),
              _PlayAllCircleButton(
                onTap: () async {
                  final songs = songsAsync.value;
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
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // Songs List
        songsAsync.when(
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(),
            ),
          ),
          error: (err, _) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              context.l10n.loadFailed(err.toString()),
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ),
          data: (songs) {
            if (songs.isEmpty) {
              return const SizedBox.shrink();
            }
            final displayList = songs.take(4).toList();

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: displayList.map((song) {
                  final isPlaying = currentSongId == song.id;
                  final isFav = starred.songs.contains(song.id);
                  final coverUrl = resolveSongCoverUrl(
                    song: song,
                    client: client,
                    size: 120,
                  );
                  final coverId = resolveSongCoverArtId(song);
                  final specs = formatAudioSpecs(song);

                  return Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () async {
                        final items = await playableItemsForSongsWithLocalFiles(
                          client,
                          ref.read(downloadManagerProvider),
                          songs,
                        );
                        final idx = songs.indexOf(song);
                        final service = ref.read(audioPlayerProvider);
                        await service.setQueue(
                          items,
                          startIndex: idx >= 0 ? idx : 0,
                        );
                        await service.play();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          color: isPlaying
                              ? Theme.of(
                                  context,
                                ).colorScheme.primary.withValues(alpha: 0.12)
                              : Colors.transparent,
                        ),
                        child: Row(
                          children: <Widget>[
                            // Cover Thumbnail
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: SizedBox.square(
                                dimension: 48,
                                child: coverUrl == null
                                    ? Container(
                                        color: const Color(0xFF22242D),
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
                                            : 'cover_${coverId}_120',
                                        fit: BoxFit.cover,
                                        errorWidget: (_, _, _) => Container(
                                          color: const Color(0xFF22242D),
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
                            // Metadata
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  Text(
                                    song.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.w600,
                                      color: isPlaying
                                          ? Theme.of(
                                              context,
                                            ).colorScheme.primary
                                          : Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    song.artist ?? context.l10n.unknownArtist,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.white.withValues(
                                        alpha: 0.6,
                                      ),
                                    ),
                                  ),
                                  if (specs.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      specs,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.white.withValues(
                                          alpha: 0.38,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Star Favorite
                            IconButton(
                              icon: Icon(
                                isFav
                                    ? Icons.favorite_rounded
                                    : Icons.favorite_border_rounded,
                                size: 20,
                                color: isFav
                                    ? const Color(0xFFFF5252)
                                    : Colors.white38,
                              ),
                              onPressed: () => ref
                                  .read(starredProvider.notifier)
                                  .toggleSong(song),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            );
          },
        ),
      ],
    );
  }
}

/// 5. 最近播放的歌曲 (Recently Played Songs - Horizontal Cards).
class _RecentlyPlayedSongsSection extends ConsumerWidget {
  const _RecentlyPlayedSongsSection({
    required this.client,
    required this.starred,
    required this.currentSongId,
  });

  final SubsonicClient client;
  final ({Set<String> songs, Set<String> albums, Set<String> artists}) starred;
  final String? currentSongId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recentPlaysAsync = ref.watch(recentPlaysProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        // Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  context.l10n.recentlyPlayedSongs,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.4,
                    color: Colors.white,
                  ),
                ),
              ),
              _PlayAllCircleButton(
                onTap: () async {
                  final plays = recentPlaysAsync.value;
                  if (plays == null || plays.isEmpty) return;
                  final songs = plays.map(songFromRecentPlay).toList();
                  final items = await playableItemsForSongsWithLocalFiles(
                    client,
                    ref.read(downloadManagerProvider),
                    songs,
                  );
                  final service = ref.read(audioPlayerProvider);
                  await service.setQueue(items, startIndex: 0);
                  await service.play();
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // Horizontal List
        SizedBox(
          height: 195,
          child: recentPlaysAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Center(
              child: Text(
                context.l10n.loadFailed(err.toString()),
                style: const TextStyle(color: Colors.white54),
              ),
            ),
            data: (plays) {
              if (plays.isEmpty) {
                return Center(
                  child: Text(
                    context.l10n.noSongHistory,
                    style: const TextStyle(color: Colors.white38),
                  ),
                );
              }

              final songs = plays.take(15).map(songFromRecentPlay).toList();

              return ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: songs.length,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final song = songs[index];
                  final isPlaying = currentSongId == song.id;

                  return _SquareSongCard(
                    song: song,
                    client: client,
                    isPlaying: isPlaying,
                    onTap: () async {
                      final items = await playableItemsForSongsWithLocalFiles(
                        client,
                        ref.read(downloadManagerProvider),
                        songs,
                      );
                      final service = ref.read(audioPlayerProvider);
                      await service.setQueue(items, startIndex: index);
                      await service.play();
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

/// 6. 最近添加的歌曲 / 专辑 (Recently Added Songs - Horizontal Cards).
class _RecentlyAddedSongsSection extends ConsumerWidget {
  const _RecentlyAddedSongsSection({
    required this.client,
    required this.starred,
    required this.currentSongId,
  });

  final SubsonicClient client;
  final ({Set<String> songs, Set<String> albums, Set<String> artists}) starred;
  final String? currentSongId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final albumsAsync = ref.watch(newestAlbumsProvider);
    const cardWidth = 136.0;
    // AlbumCard includes title, artist and an optional year below its square
    // cover. Reserve all three lines, including accessibility text scaling.
    final metadataHeight = 80 * MediaQuery.textScalerOf(context).scale(1);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        // Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  context.l10n.recentlyAddedSongs,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.4,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              IconButton(
                icon: const Icon(
                  Icons.refresh_rounded,
                  size: 19,
                  color: Colors.white60,
                ),
                onPressed: () => ref.invalidate(newestAlbumsProvider),
              ),
              _PlayAllCircleButton(
                tooltip: context.l10n.navAlbums,
                onTap: () => context.go('/albums'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // Horizontal List
        SizedBox(
          height: cardWidth + metadataHeight,
          child: albumsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Center(
              child: Text(
                context.l10n.loadFailed(err.toString()),
                style: const TextStyle(color: Colors.white54),
              ),
            ),
            data: (albums) {
              if (albums.isEmpty) {
                return Center(
                  child: Text(
                    context.l10n.noContentYet,
                    style: const TextStyle(color: Colors.white38),
                  ),
                );
              }

              return ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: albums.length,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final album = albums[index];
                  final isFav = starred.albums.contains(album.id);

                  return SizedBox(
                    width: cardWidth,
                    child: AlbumCard(
                      album: album,
                      client: client,
                      isFavorite: isFav,
                      onFavorite: () =>
                          ref.read(starredProvider.notifier).toggleAlbum(album),
                      onTap: () => context.go('/albums/${album.id}'),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

/// 7. 最近更新的歌单 (Recently Updated Playlists).
class _RecentlyUpdatedPlaylistsSection extends ConsumerWidget {
  const _RecentlyUpdatedPlaylistsSection({required this.client});

  final SubsonicClient client;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playlistsAsync = ref.watch(playlistsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        // Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  context.l10n.recentlyUpdatedPlaylists,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.4,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              IconButton(
                icon: const Icon(
                  Icons.refresh_rounded,
                  size: 19,
                  color: Colors.white60,
                ),
                onPressed: () => ref.invalidate(playlistsProvider),
              ),
              InkWell(
                onTap: () => context.go('/playlists'),
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
            ],
          ),
        ),
        const SizedBox(height: 10),

        // Horizontal List
        SizedBox(
          height: 195,
          child: playlistsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Center(
              child: Text(
                context.l10n.playlistsLoadFailed(err.toString()),
                style: const TextStyle(color: Colors.white54),
              ),
            ),
            data: (playlists) {
              if (playlists.isEmpty) {
                return Center(
                  child: Text(
                    context.l10n.noContentYet,
                    style: const TextStyle(color: Colors.white38),
                  ),
                );
              }

              return ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: playlists.length,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final pl = playlists[index];
                  final coverUrl = pl.coverArt == null
                      ? null
                      : client.coverArtUrl(pl.coverArt!, size: 300);

                  return InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => context.go('/playlists/${pl.id}'),
                    child: SizedBox(
                      width: 136,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          AspectRatio(
                            aspectRatio: 1.0,
                            child: ClipRSuperellipse(
                              borderRadius: BorderRadius.circular(16),
                              child: coverUrl == null
                                  ? Container(
                                      decoration: const BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: <Color>[
                                            Color(0xFF2C2D3A),
                                            Color(0xFF1E2028),
                                          ],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                      ),
                                      child: const Icon(
                                        Icons.queue_music_rounded,
                                        size: 40,
                                        color: Colors.white30,
                                      ),
                                    )
                                  : CachedNetworkImage(
                                      imageUrl: coverUrl,
                                      cacheKey: 'cover_${pl.coverArt}_300',
                                      fit: BoxFit.cover,
                                      errorWidget: (_, _, _) => Container(
                                        color: const Color(0xFF22242D),
                                        child: const Icon(
                                          Icons.queue_music_rounded,
                                          size: 40,
                                          color: Colors.white30,
                                        ),
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            pl.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            context.l10n.songCountText(pl.songCount ?? 0),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11.5,
                              color: Colors.white.withValues(alpha: 0.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

/// 8. 媒体库统计面板 (Library Statistics 2x3 Grid).
class _LibraryStatsGrid extends ConsumerWidget {
  const _LibraryStatsGrid();

  String _formatBytes(int? bytes) {
    if (bytes == null || bytes <= 0) return '—';
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    var i = 0;
    double size = bytes.toDouble();
    while (size >= 1024 && i < suffixes.length - 1) {
      size /= 1024;
      i++;
    }
    return '${size.toStringAsFixed(1)}${suffixes[i]}';
  }

  String _formatHours(int? totalSeconds) {
    if (totalSeconds == null) return '—';
    final hours = totalSeconds ~/ 3600;
    return '${hours}h';
  }

  String _formatNumber(int? number) {
    if (number == null) return '—';
    final str = number.toString();
    final buffer = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) {
        buffer.write(',');
      }
      buffer.write(str[i]);
    }
    return buffer.toString();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(libraryStatsProvider);

    return statsAsync.maybeWhen(
      data: (stats) {
        final cards = <({String value, String label, String route})>[
          (
            value: _formatNumber(stats.songCount),
            label: context.l10n.navSongs,
            route: '/songs',
          ),
          (
            value: _formatNumber(stats.albumCount),
            label: context.l10n.navAlbums,
            route: '/albums',
          ),
          (
            value: _formatNumber(stats.artistCount),
            label: context.l10n.navArtists,
            route: '/artists',
          ),
          (
            value: _formatNumber(stats.folderCount),
            label: context.l10n.foldersCount,
            route: '/home',
          ),
          (
            value: _formatBytes(stats.totalSizeBytes),
            label: context.l10n.totalSize,
            route: '/home',
          ),
          (
            value: _formatHours(stats.totalDurationSeconds),
            label: context.l10n.totalDuration,
            route: '/home',
          ),
        ];

        return Column(
          children: <Widget>[
            // 2x3 Grid
            GlassSurface(
              blur: false,
              clear: true,
              padding: const EdgeInsets.all(10),
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: cards.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  mainAxisExtent:
                      78 * MediaQuery.textScalerOf(context).scale(1),
                ),
                itemBuilder: (context, index) {
                  final card = cards[index];
                  return InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => context.go(card.route),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.025),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.06),
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 8,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          Text(
                            card.value,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            card.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11.5,
                              color: Colors.white.withValues(alpha: 0.5),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 14),
            // Bottom Info Row
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Icon(
                  Icons.desktop_windows_outlined,
                  size: 14,
                  color: Colors.white.withValues(alpha: 0.4),
                ),
                const SizedBox(width: 4),
                Text(
                  context.l10n.resolution,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: Colors.white.withValues(alpha: 0.4),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Text(
                    '|',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.2),
                    ),
                  ),
                ),
                Icon(
                  Icons.tune_rounded,
                  size: 14,
                  color: Colors.white.withValues(alpha: 0.4),
                ),
                const SizedBox(width: 4),
                InkWell(
                  onTap: () => context.go('/settings'),
                  child: Text(
                    context.l10n.customize,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: Colors.white.withValues(alpha: 0.4),
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }
}

/// Circular Play All Button.
class _PlayAllCircleButton extends StatelessWidget {
  const _PlayAllCircleButton({required this.onTap, this.tooltip});

  final VoidCallback onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    return GlassIconButton(
      icon: const Icon(Icons.play_arrow_rounded, size: 23),
      tooltip: tooltip ?? context.l10n.playAll,
      onPressed: onTap,
    );
  }
}

/// Square song card for horizontal lists.
class _SquareSongCard extends StatelessWidget {
  const _SquareSongCard({
    required this.song,
    required this.client,
    required this.onTap,
    this.isPlaying = false,
  });

  final Song song;
  final SubsonicClient client;
  final VoidCallback onTap;
  final bool isPlaying;

  @override
  Widget build(BuildContext context) {
    final coverUrl = resolveSongCoverUrl(song: song, client: client, size: 280);
    final coverId = resolveSongCoverArtId(song);

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: SizedBox(
        width: 136,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            AspectRatio(
              aspectRatio: 1.0,
              child: ClipRSuperellipse(
                borderRadius: BorderRadius.circular(16),
                child: coverUrl == null
                    ? Container(
                        color: const Color(0xFF22242D),
                        child: const Icon(
                          Icons.music_note_rounded,
                          size: 38,
                          color: Colors.white24,
                        ),
                      )
                    : CachedNetworkImage(
                        imageUrl: coverUrl,
                        cacheKey: coverId == null
                            ? null
                            : 'cover_${coverId}_280',
                        fit: BoxFit.cover,
                        errorWidget: (_, _, _) => Container(
                          color: const Color(0xFF22242D),
                          child: const Icon(
                            Icons.music_note_rounded,
                            size: 38,
                            color: Colors.white24,
                          ),
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              song.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isPlaying
                    ? Theme.of(context).colorScheme.primary
                    : Colors.white,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              song.artist ?? context.l10n.unknownArtist,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11.5,
                color: Colors.white.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
