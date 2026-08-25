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

enum ArtistAlbumSort { yearDesc, yearAsc, nameAsc }

class ArtistDetailsScreen extends ConsumerStatefulWidget {
  const ArtistDetailsScreen({required this.artistId, super.key});

  final String artistId;

  @override
  ConsumerState<ArtistDetailsScreen> createState() =>
      _ArtistDetailsScreenState();
}

class _ArtistDetailsScreenState extends ConsumerState<ArtistDetailsScreen> {
  ArtistAlbumSort _albumSort = ArtistAlbumSort.yearDesc;
  bool _showAllPopularSongs = false;
  bool _isBioExpanded = false;

  String _sanitizeBiography(String raw) {
    var text = raw;
    text = text.replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n');
    text = text.replaceAll(RegExp(r'</p>', caseSensitive: false), '\n\n');
    text = text.replaceAll(RegExp(r'<p>', caseSensitive: false), '');
    text = text.replaceAll(
      RegExp(r'<a\s+[^>]*>(.*?)</a>', caseSensitive: false),
      r'$1',
    );
    text = text.replaceAll(RegExp(r'<[^>]+>'), '');
    text = text
        .replaceAll('&quot;', '"')
        .replaceAll('&apos;', "'")
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&nbsp;', ' ');
    text = text.replaceAll(RegExp(r'\n{3,}'), '\n\n');
    return text.trim();
  }

  List<Album> _sortAlbums(List<Album> albums) {
    final sorted = [...albums];
    switch (_albumSort) {
      case ArtistAlbumSort.yearDesc:
        sorted.sort((a, b) {
          final yearA = a.year ?? 0;
          final yearB = b.year ?? 0;
          if (yearA != yearB) return yearB.compareTo(yearA);
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        });
        break;
      case ArtistAlbumSort.yearAsc:
        sorted.sort((a, b) {
          final yearA = a.year ?? 9999;
          final yearB = b.year ?? 9999;
          if (yearA != yearB) return yearA.compareTo(yearB);
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        });
        break;
      case ArtistAlbumSort.nameAsc:
        sorted.sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );
        break;
    }
    return sorted;
  }

  @override
  Widget build(BuildContext context) {
    final artistAsync = ref.watch(artistDetailsProvider(widget.artistId));
    final infoAsync = ref.watch(artistInfoProvider(widget.artistId));
    final client = ref.watch(activeSubsonicClientProvider);
    final starredIds = ref.watch(starredIdsProvider);

    if (client == null) {
      return const NoServerView();
    }

    return Scaffold(
      backgroundColor: const Color(0xFF131418),
      body: artistAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: Color(0xFF1E7BF6)),
        ),
        error: (error, stackTrace) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Icon(
                  Icons.error_outline_rounded,
                  size: 48,
                  color: Colors.white38,
                ),
                const SizedBox(height: 12),
                Text(
                  context.l10n.artistsLoadFailed(error.toString()),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () => ref.invalidate(
                    artistDetailsProvider(widget.artistId),
                  ),
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: Text(context.l10n.refresh),
                ),
              ],
            ),
          ),
        ),
        data: (artist) {
          final details = infoAsync.value;
          final allSongs = artist.albums
              .expand((album) => album.songs)
              .toList(growable: false);

          final displaySongs = _showAllPopularSongs
              ? allSongs.take(20).toList(growable: false)
              : allSongs.take(5).toList(growable: false);

          final sortedAlbums = _sortAlbums(artist.albums);

          final imageUrl = details?.coverArt != null &&
                  details!.coverArt!.isNotEmpty
              ? client.coverArtUrl(details.coverArt!, size: 640)
              : (resolveArtistImageUrl(
                      artist: artist,
                      client: client,
                      size: 640,
                    ) ??
                  details?.largeImageUrl ??
                  details?.mediumImageUrl);

          final palette = imageUrl == null
              ? null
              : ref.watch(artworkPaletteProvider(imageUrl)).value;

          final isStarred = starredIds.artists.contains(artist.id);
          final rawBio = details?.biography ?? '';
          final cleanBio = rawBio.isNotEmpty ? _sanitizeBiography(rawBio) : '';
          final similarArtists = details?.similarArtists ?? const <Artist>[];

          return CustomScrollView(
            slivers: <Widget>[
              // App Bar
              SliverAppBar(
                backgroundColor: const Color(0xFF131418),
                pinned: true,
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
                      context.go('/artists');
                    }
                  },
                ),
                title: Text(
                  artist.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                actions: <Widget>[
                  StarButton(
                    isStarred: isStarred,
                    size: 20,
                    onPressed: () =>
                        ref.read(starredProvider.notifier).toggleArtist(artist),
                  ),
                  IconButton(
                    tooltip: context.l10n.refresh,
                    icon: const Icon(
                      Icons.refresh_rounded,
                      color: Colors.white70,
                    ),
                    onPressed: () {
                      ref.invalidate(artistDetailsProvider(widget.artistId));
                      ref.invalidate(artistInfoProvider(widget.artistId));
                    },
                  ),
                ],
              ),

              // Hero Header Section
              SliverToBoxAdapter(
                child: _ModernArtistHeader(
                  artist: artist,
                  client: client,
                  imageUrl: imageUrl,
                  palette: palette,
                  totalSongsCount: allSongs.length,
                  isFavorite: isStarred,
                  onFavorite: () =>
                      ref.read(starredProvider.notifier).toggleArtist(artist),
                  onPlayAll: allSongs.isEmpty
                      ? null
                      : () => _playArtistSongs(context, ref, allSongs, 0),
                  onShuffleAll: allSongs.isEmpty
                      ? null
                      : () => _playArtistSongs(
                            context,
                            ref,
                            allSongs,
                            0,
                            shuffle: true,
                          ),
                ),
              ),

              // About / Biography Card
              if (cleanBio.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1B1C23),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.06),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              const Icon(
                                Icons.info_outline_rounded,
                                size: 18,
                                color: Color(0xFF5BA4FF),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                context.l10n.artistBio,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            cleanBio,
                            maxLines: _isBioExpanded ? null : 3,
                            overflow: _isBioExpanded
                                ? TextOverflow.visible
                                : TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.white.withValues(alpha: 0.72),
                              height: 1.45,
                            ),
                          ),
                          if (cleanBio.length > 120) ...[
                            const SizedBox(height: 4),
                            Align(
                              alignment: Alignment.centerRight,
                              child: GestureDetector(
                                onTap: () => setState(
                                  () => _isBioExpanded = !_isBioExpanded,
                                ),
                                child: Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 4),
                                  child: Text(
                                    _isBioExpanded
                                        ? context.l10n.showLess
                                        : context.l10n.showMore,
                                    style: const TextStyle(
                                      color: Color(0xFF5BA4FF),
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),

              // Popular Songs Section
              if (displaySongs.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 12, 18, 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        Text(
                          context.l10n.popularSongs,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        if (allSongs.length > 5)
                          TextButton(
                            onPressed: () => setState(
                              () =>
                                  _showAllPopularSongs = !_showAllPopularSongs,
                            ),
                            child: Text(
                              _showAllPopularSongs
                                  ? context.l10n.showLess
                                  : context.l10n.showMore,
                              style: const TextStyle(
                                color: Color(0xFF5BA4FF),
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(10, 0, 10, 16),
                  sliver: SliverList.builder(
                    itemCount: displaySongs.length,
                    itemBuilder: (context, index) {
                      final song = displaySongs[index];
                      final isSongStarred =
                          starredIds.songs.contains(song.id);
                      return SongListTile(
                        index: index + 1,
                        song: song,
                        client: client,
                        onTap: () => _playArtistSongs(
                          context,
                          ref,
                          displaySongs,
                          index,
                        ),
                        isFavorite: isSongStarred,
                        onFavorite: () async {
                          try {
                            await ref
                                .read(starredProvider.notifier)
                                .toggleSong(song);
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
                        onMore: () {
                          showSongActionBottomSheet(
                            context: context,
                            ref: ref,
                            song: song,
                            client: client,
                          );
                        },
                      );
                    },
                  ),
                ),
              ],

              // Albums / Discography Section
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
                  child: Row(
                    children: <Widget>[
                      Text(
                        context.l10n.navAlbums,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E7BF6).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color:
                                const Color(0xFF1E7BF6).withValues(alpha: 0.3),
                            width: 0.8,
                          ),
                        ),
                        child: Text(
                          '${sortedAlbums.length}',
                          style: const TextStyle(
                            color: Color(0xFF5BA4FF),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const Spacer(),
                      PopupMenuButton<ArtistAlbumSort>(
                        tooltip: context.l10n.sortBy,
                        icon: const Icon(
                          Icons.sort_rounded,
                          size: 20,
                          color: Colors.white70,
                        ),
                        color: const Color(0xFF22242D),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        initialValue: _albumSort,
                        onSelected: (option) =>
                            setState(() => _albumSort = option),
                        itemBuilder: (context) => <PopupMenuEntry<ArtistAlbumSort>>[
                          PopupMenuItem(
                            value: ArtistAlbumSort.yearDesc,
                            child: Text(
                              context.l10n.sortYearDesc,
                              style: TextStyle(
                                color: _albumSort == ArtistAlbumSort.yearDesc
                                    ? const Color(0xFF5BA4FF)
                                    : Colors.white,
                              ),
                            ),
                          ),
                          PopupMenuItem(
                            value: ArtistAlbumSort.yearAsc,
                            child: Text(
                              context.l10n.sortYearAsc,
                              style: TextStyle(
                                color: _albumSort == ArtistAlbumSort.yearAsc
                                    ? const Color(0xFF5BA4FF)
                                    : Colors.white,
                              ),
                            ),
                          ),
                          PopupMenuItem(
                            value: ArtistAlbumSort.nameAsc,
                            child: Text(
                              context.l10n.sortNameAsc,
                              style: TextStyle(
                                color: _albumSort == ArtistAlbumSort.nameAsc
                                    ? const Color(0xFF5BA4FF)
                                    : Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Albums Grid
              if (sortedAlbums.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Center(
                      child: Text(
                        context.l10n.emptyAlbums,
                        style: const TextStyle(color: Colors.white54),
                      ),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  sliver: SliverLayoutBuilder(
                    builder: (context, constraints) {
                      final columns = (constraints.crossAxisExtent / 160)
                          .floor()
                          .clamp(2, 6)
                          .toInt();
                      return SliverGrid.builder(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: columns,
                          crossAxisSpacing: 14,
                          mainAxisSpacing: 18,
                          childAspectRatio: 0.70,
                        ),
                        itemCount: sortedAlbums.length,
                        itemBuilder: (context, index) {
                          final album = sortedAlbums[index];
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
                                    SnackBar(
                                      content: Text(
                                        context.l10n.starFailed(
                                          error.toString(),
                                        ),
                                      ),
                                    ),
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

              // Similar Artists Section
              if (similarArtists.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
                    child: Text(
                      context.l10n.similarArtists,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 160,
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      scrollDirection: Axis.horizontal,
                      itemCount: similarArtists.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final similar = similarArtists[index];
                        return SizedBox(
                          width: 105,
                          child: ArtistCard(
                            artist: similar,
                            client: client,
                            showSubtitle: false,
                            onTap: () => context.push(
                              '/artists/${Uri.encodeComponent(similar.id)}',
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],

              const SliverToBoxAdapter(child: SizedBox(height: 36)),
            ],
          );
        },
      ),
    );
  }
}

class _ModernArtistHeader extends StatelessWidget {
  const _ModernArtistHeader({
    required this.artist,
    required this.imageUrl,
    required this.palette,
    required this.totalSongsCount,
    required this.isFavorite,
    required this.onFavorite,
    required this.onPlayAll,
    required this.onShuffleAll,
    this.client,
  });

  final Artist artist;
  final SubsonicClient? client;
  final String? imageUrl;
  final ArtworkPalette? palette;
  final int totalSongsCount;
  final bool isFavorite;
  final Future<void> Function() onFavorite;
  final VoidCallback? onPlayAll;
  final VoidCallback? onShuffleAll;

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= 600;
    final accentColor = palette?.vibrant ?? const Color(0xFF1E7BF6);

    return Container(
      margin: EdgeInsets.fromLTRB(isWide ? 16 : 10, 4, isWide ? 16 : 10, 12),
      padding: EdgeInsets.all(isWide ? 24 : 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1B1C23),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: accentColor.withValues(alpha: 0.15),
          width: 1.0,
        ),
        gradient: LinearGradient(
          colors: <Color>[
            accentColor.withValues(alpha: 0.28),
            const Color(0xFF1B1C23).withValues(alpha: 0.85),
            const Color(0xFF1B1C23),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: accentColor.withValues(alpha: 0.12),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: isWide
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                // Large Avatar
                ArtistAvatar(
                  artist: artist,
                  client: client,
                  imageUrl: imageUrl,
                  radius: 65,
                  showBorder: true,
                  borderColor: accentColor.withValues(alpha: 0.4),
                  borderWidth: 2,
                ),
                const SizedBox(width: 24),
                // Info & Actions
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        artist.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        <String>[
                          if (artist.albumCount != null &&
                              artist.albumCount! > 0)
                            context.l10n.artistAlbumCount(artist.albumCount!)
                          else if (artist.albums.isNotEmpty)
                            context.l10n.artistAlbumCount(artist.albums.length),
                          if (totalSongsCount > 0)
                            context.l10n.artistSongCount(totalSongsCount),
                        ].join(' · '),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 13.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 18),
                      _ActionButtons(
                        onPlayAll: onPlayAll,
                        onShuffleAll: onShuffleAll,
                        isFavorite: isFavorite,
                        onFavorite: onFavorite,
                        isWide: true,
                      ),
                    ],
                  ),
                ),
              ],
            )
          : Column(
              children: <Widget>[
                // Circular Avatar Centered
                ArtistAvatar(
                  artist: artist,
                  client: client,
                  imageUrl: imageUrl,
                  radius: 54,
                  showBorder: true,
                  borderColor: accentColor.withValues(alpha: 0.4),
                  borderWidth: 2,
                ),
                const SizedBox(height: 14),
                // Artist Name
                Text(
                  artist.name,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 4),
                // Metadata Subtitle
                Text(
                  <String>[
                    if (artist.albumCount != null && artist.albumCount! > 0)
                      context.l10n.artistAlbumCount(artist.albumCount!)
                    else if (artist.albums.isNotEmpty)
                      context.l10n.artistAlbumCount(artist.albums.length),
                    if (totalSongsCount > 0)
                      context.l10n.artistSongCount(totalSongsCount),
                  ].join(' · '),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 16),
                // Action Buttons
                _ActionButtons(
                  onPlayAll: onPlayAll,
                  onShuffleAll: onShuffleAll,
                  isFavorite: isFavorite,
                  onFavorite: onFavorite,
                  isWide: false,
                ),
              ],
            ),
    );
  }
}

class _ActionButtons extends StatelessWidget {
  const _ActionButtons({
    required this.onPlayAll,
    required this.onShuffleAll,
    required this.isFavorite,
    required this.onFavorite,
    required this.isWide,
  });

  final VoidCallback? onPlayAll;
  final VoidCallback? onShuffleAll;
  final bool isFavorite;
  final Future<void> Function() onFavorite;
  final bool isWide;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment:
          isWide ? MainAxisAlignment.start : MainAxisAlignment.center,
      children: <Widget>[
        Expanded(
          flex: isWide ? 0 : 1,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF1E7BF6),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
              ),
              elevation: 4,
            ),
            onPressed: onPlayAll,
            icon: const Icon(Icons.play_arrow_rounded, size: 20),
            label: Text(
              context.l10n.playAll,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
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
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
              ),
            ),
            onPressed: onShuffleAll,
            icon: const Icon(Icons.shuffle_rounded, size: 18),
            label: Text(
              context.l10n.shufflePlay,
              style: const TextStyle(fontSize: 13.5),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF2A2C37).withValues(alpha: 0.8),
            shape: BoxShape.circle,
          ),
          child: StarButton(
            isStarred: isFavorite,
            size: 20,
            onPressed: onFavorite,
          ),
        ),
      ],
    );
  }
}

Future<void> _playArtistSongs(
  BuildContext context,
  WidgetRef ref,
  List<Song> songs,
  int index, {
  bool shuffle = false,
}) async {
  final client = ref.read(activeSubsonicClientProvider);
  if (client == null || songs.isEmpty) {
    return;
  }
  final items = await playableItemsForSongsWithLocalFiles(
    client,
    ref.read(downloadManagerProvider),
    songs,
  );
  if (shuffle) {
    items.shuffle();
  }
  try {
    final service = ref.read(audioPlayerProvider);
    await service.setQueue(items, startIndex: shuffle ? 0 : index);
    await service.play();
    if (context.mounted) {
      context.push('/player');
    }
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.playbackFailed(error.toString())),
        ),
      );
    }
  }
}

