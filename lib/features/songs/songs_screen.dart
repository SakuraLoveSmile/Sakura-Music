import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:subsonic_api/subsonic_api.dart';

import '../../audio/audio_player_provider.dart';
import '../../audio/playable_item_builder.dart';
import '../../core/providers.dart';
import '../../data/download_manager.dart';
import '../../l10n/l10n.dart';
import '../shared/media_widgets.dart';

enum SongSortOption { recent, title, artist, album, duration, format }

String _songSortOptionLabel(BuildContext context, SongSortOption option) {
  return switch (option) {
    SongSortOption.recent => context.l10n.sortRecent,
    SongSortOption.title => context.l10n.sortTitle,
    SongSortOption.artist => context.l10n.sortArtist,
    SongSortOption.album => context.l10n.sortAlbum,
    SongSortOption.duration => context.l10n.sortDuration,
    SongSortOption.format => context.l10n.sortFormat,
  };
}

class SongsScreen extends ConsumerStatefulWidget {
  const SongsScreen({super.key});

  @override
  ConsumerState<SongsScreen> createState() => _SongsScreenState();
}

class _SongsScreenState extends ConsumerState<SongsScreen> {
  SongSortOption _sortOption = SongSortOption.recent;

  List<Song> _sortSongs(List<Song> songs) {
    final list = [...songs];
    switch (_sortOption) {
      case SongSortOption.recent:
        // default server order
        break;
      case SongSortOption.title:
        list.sort(
          (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
        );
        break;
      case SongSortOption.artist:
        list.sort(
          (a, b) => (a.artist ?? '').toLowerCase().compareTo(
            (b.artist ?? '').toLowerCase(),
          ),
        );
        break;
      case SongSortOption.album:
        list.sort(
          (a, b) => (a.album ?? '').toLowerCase().compareTo(
            (b.album ?? '').toLowerCase(),
          ),
        );
        break;
      case SongSortOption.duration:
        list.sort((a, b) => (b.duration ?? 0).compareTo(a.duration ?? 0));
        break;
      case SongSortOption.format:
        list.sort((a, b) => (b.bitRate ?? 0).compareTo(a.bitRate ?? 0));
        break;
    }
    return list;
  }

  Future<void> _playAll(
    List<Song> songs,
    SubsonicClient client, {
    bool shuffle = false,
  }) async {
    if (songs.isEmpty) return;
    final toPlay = [...songs];
    if (shuffle) {
      toPlay.shuffle(Random());
    }
    final items = await playableItemsForSongsWithLocalFiles(
      client,
      ref.read(downloadManagerProvider),
      toPlay,
    );
    final service = ref.read(audioPlayerProvider);
    await service.setQueue(items, startIndex: 0);
    await service.play();
  }

  @override
  Widget build(BuildContext context) {
    final client = ref.watch(activeSubsonicClientProvider);
    if (client == null) {
      return const SafeArea(child: NoServerView());
    }

    final songsAsync = ref.watch(songsListProvider);
    final starredIds = ref.watch(starredIdsProvider);
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
                ref.invalidate(songsListProvider);
              },
              child: CustomScrollView(
                slivers: <Widget>[
                  // Header Bar
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          // Top Row: Title + Server indicator
                          Row(
                            children: <Widget>[
                              Text(
                                context.l10n.navSongs,
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  letterSpacing: 0.3,
                                ),
                              ),
                              const Spacer(),
                              IconButton(
                                tooltip: context.l10n.refreshSongs,
                                onPressed: () =>
                                    ref.invalidate(songsListProvider),
                                icon: const Icon(
                                  Icons.refresh_rounded,
                                  size: 20,
                                  color: Colors.white70,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Control Buttons Toolbar
                          songsAsync.maybeWhen(
                            data: (songs) {
                              final sortedSongs = _sortSongs(songs);
                              return SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                clipBehavior: Clip.none,
                                physics: const BouncingScrollPhysics(),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: <Widget>[
                                    // Sort Dropdown Button
                                    Container(
                                      height: 36,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF22242D),
                                        borderRadius: BorderRadius.circular(18),
                                        border: Border.all(
                                          color: Colors.white.withValues(
                                            alpha: 0.1,
                                          ),
                                        ),
                                      ),
                                      child: PopupMenuButton<SongSortOption>(
                                        tooltip: context.l10n.sortBy,
                                        offset: const Offset(0, 40),
                                        color: const Color(0xFF22252E),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        onSelected: (option) => setState(
                                          () => _sortOption = option,
                                        ),
                                        itemBuilder: (context) => SongSortOption
                                            .values
                                            .map(
                                              (opt) =>
                                                  PopupMenuItem<SongSortOption>(
                                                    value: opt,
                                                    child: Row(
                                                      children: <Widget>[
                                                        Text(
                                                          _songSortOptionLabel(
                                                            context,
                                                            opt,
                                                          ),
                                                          style: TextStyle(
                                                            color:
                                                                _sortOption ==
                                                                    opt
                                                                ? const Color(
                                                                    0xFF1E7BF6,
                                                                  )
                                                                : Colors.white,
                                                            fontWeight:
                                                                _sortOption ==
                                                                    opt
                                                                ? FontWeight
                                                                      .bold
                                                                : FontWeight
                                                                      .normal,
                                                            fontSize: 13,
                                                          ),
                                                        ),
                                                        const Spacer(),
                                                        if (_sortOption == opt)
                                                          const Icon(
                                                            Icons.check,
                                                            size: 16,
                                                            color: Color(
                                                              0xFF1E7BF6,
                                                            ),
                                                          ),
                                                      ],
                                                    ),
                                                  ),
                                            )
                                            .toList(),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: <Widget>[
                                            const Icon(
                                              Icons.swap_vert_rounded,
                                              size: 16,
                                              color: Colors.white70,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              _songSortOptionLabel(
                                                context,
                                                _sortOption,
                                              ),
                                              style: const TextStyle(
                                                fontSize: 12.5,
                                                color: Colors.white,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 5,
                                                    vertical: 1,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: Colors.white.withValues(
                                                  alpha: 0.08,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: Text(
                                                context.l10n.loadedSongsCount(
                                                  songs.length,
                                                ),
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.white
                                                      .withValues(alpha: 0.6),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),

                                    // Blue Sequential Play Capsule Button
                                    FilledButton.icon(
                                      onPressed: () => _playAll(
                                        sortedSongs,
                                        client,
                                        shuffle: false,
                                      ),
                                      style: FilledButton.styleFrom(
                                        backgroundColor: const Color(
                                          0xFF1E7BF6,
                                        ),
                                        foregroundColor: Colors.white,
                                        elevation: 0,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 14,
                                          vertical: 0,
                                        ),
                                        minimumSize: const Size(0, 36),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            18,
                                          ),
                                        ),
                                      ),
                                      icon: const Icon(
                                        Icons.play_arrow_rounded,
                                        size: 18,
                                      ),
                                      label: Text(
                                        context.l10n.playInOrder,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),

                                    // Dark Shuffle Play Capsule Button
                                    OutlinedButton.icon(
                                      onPressed: () => _playAll(
                                        sortedSongs,
                                        client,
                                        shuffle: true,
                                      ),
                                      style: OutlinedButton.styleFrom(
                                        backgroundColor: const Color(
                                          0xFF22242D,
                                        ),
                                        foregroundColor: Colors.white,
                                        side: BorderSide(
                                          color: Colors.white.withValues(
                                            alpha: 0.1,
                                          ),
                                        ),
                                        elevation: 0,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 14,
                                          vertical: 0,
                                        ),
                                        minimumSize: const Size(0, 36),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            18,
                                          ),
                                        ),
                                      ),
                                      icon: const Icon(
                                        Icons.shuffle_rounded,
                                        size: 16,
                                        color: Colors.white70,
                                      ),
                                      label: Text(
                                        context.l10n.shufflePlay,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                            orElse: () => const SizedBox.shrink(),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Songs List
                  songsAsync.when(
                    loading: () => const SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF1E7BF6),
                        ),
                      ),
                    ),
                    error: (error, stack) => SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
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
                              context.l10n.songsLoadFailed(error.toString()),
                              style: const TextStyle(color: Colors.white70),
                            ),
                            const SizedBox(height: 14),
                            FilledButton(
                              onPressed: () =>
                                  ref.invalidate(songsListProvider),
                              child: Text(context.l10n.retry),
                            ),
                          ],
                        ),
                      ),
                    ),
                    data: (songs) {
                      if (songs.isEmpty) {
                        return SliverFillRemaining(
                          hasScrollBody: false,
                          child: Center(
                            child: Text(
                              context.l10n.emptyLibrarySongs,
                              style: TextStyle(color: Colors.white54),
                            ),
                          ),
                        );
                      }

                      final sorted = _sortSongs(songs);

                      return SliverPadding(
                        padding: const EdgeInsets.fromLTRB(10, 2, 10, 32),
                        sliver: SliverList.builder(
                          itemCount: sorted.length,
                          itemBuilder: (context, index) {
                            final song = sorted[index];
                            final isCurrentPlaying = currentSongId == song.id;
                            final isFavorite = starredIds.songs.contains(
                              song.id,
                            );

                            return SongListTile(
                              index: index + 1,
                              song: song,
                              client: client,
                              isPlaying: isCurrentPlaying,
                              isFavorite: isFavorite,
                              onFavorite: () => ref
                                  .read(starredProvider.notifier)
                                  .toggleSong(song),
                              onDownload: () async {
                                final manager = ref.read(
                                  downloadManagerProvider,
                                );
                                if (manager != null) {
                                  await manager.downloadSong(song);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          context.l10n.addedToDownloads(
                                            song.title,
                                          ),
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
                              onTap: () async {
                                final items =
                                    await playableItemsForSongsWithLocalFiles(
                                      client,
                                      ref.read(downloadManagerProvider),
                                      sorted,
                                    );
                                final service = ref.read(audioPlayerProvider);
                                await service.setQueue(
                                  items,
                                  startIndex: index,
                                );
                                await service.play();
                              },
                            );
                          },
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
