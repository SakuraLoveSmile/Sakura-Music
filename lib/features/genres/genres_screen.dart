import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:subsonic_api/subsonic_api.dart';

import '../../audio/audio_player_provider.dart';
import '../../audio/playable_item_builder.dart';
import '../../core/providers.dart';
import '../../data/download_manager.dart';
import '../../l10n/l10n.dart';
import '../shared/media_widgets.dart';

class GenresScreen extends ConsumerWidget {
  const GenresScreen({super.key});

  static const _gradients = <List<Color>>[
    [Color(0xFF2C3E50), Color(0xFF3498DB)],
    [Color(0xFF8E44AD), Color(0xFFC0392B)],
    [Color(0xFF16A085), Color(0xFF27AE60)],
    [Color(0xFFD35400), Color(0xFFF39C12)],
    [Color(0xFF1F1C2C), Color(0xFF928DAB)],
    [Color(0xFF0F2027), Color(0xFF203A43)],
    [Color(0xFF3A1C71), Color(0xFFD76D77)],
    [Color(0xFF4A00E0), Color(0xFF8E2DE2)],
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final client = ref.watch(activeSubsonicClientProvider);
    if (client == null) {
      return const SafeArea(child: NoServerView());
    }

    final genres = ref.watch(genresProvider);

    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async => ref.invalidate(genresProvider),
          child: CustomScrollView(
            slivers: <Widget>[
              SliverAppBar(
                title: Text(
                  context.l10n.navGenres,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
                ),
                floating: true,
                actions: <Widget>[
                  IconButton(
                    tooltip: context.l10n.refresh,
                    onPressed: () => ref.invalidate(genresProvider),
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                ],
              ),
              genres.when(
                loading: () => const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: CircularProgressIndicator(color: Color(0xFF1E7BF6)),
                  ),
                ),
                error: (error, stack) => SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Text(
                      context.l10n.genresLoadFailed(error.toString()),
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ),
                ),
                data: (items) {
                  if (items.isEmpty) {
                    return SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Text(
                          context.l10n.emptyGenres,
                          style: TextStyle(color: Colors.white54),
                        ),
                      ),
                    );
                  }

                  return SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                    sliver: SliverLayoutBuilder(
                      builder: (context, constraints) {
                        final columns = (constraints.crossAxisExtent / 180)
                            .floor()
                            .clamp(2, 6)
                            .toInt();
                        return SliverGrid.builder(
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: columns,
                                crossAxisSpacing: 14,
                                mainAxisSpacing: 14,
                                childAspectRatio: 1.4,
                              ),
                          itemCount: items.length,
                          itemBuilder: (context, index) {
                            final genre = items[index];
                            final gradient =
                                _gradients[index % _gradients.length];

                            return InkWell(
                              borderRadius: BorderRadius.circular(14),
                              onTap: () =>
                                  _openGenreDetail(context, ref, client, genre),
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: gradient,
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(14),
                                  boxShadow: <BoxShadow>[
                                    BoxShadow(
                                      color: gradient.first.withValues(
                                        alpha: 0.3,
                                      ),
                                      blurRadius: 8,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                padding: const EdgeInsets.all(14),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: <Widget>[
                                    Text(
                                      genre.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Row(
                                      children: <Widget>[
                                        if (genre.songCount != null &&
                                            genre.songCount! > 0)
                                          Text(
                                            context.l10n.genreSongCount(
                                              genre.songCount ?? 0,
                                            ),
                                            style: TextStyle(
                                              color: Colors.white.withValues(
                                                alpha: 0.75,
                                              ),
                                              fontSize: 12,
                                            ),
                                          ),
                                        if (genre.albumCount != null &&
                                            genre.albumCount! > 0) ...[
                                          const SizedBox(width: 8),
                                          Text(
                                            context.l10n.genreAlbumCount(
                                              genre.albumCount ?? 0,
                                            ),
                                            style: TextStyle(
                                              color: Colors.white.withValues(
                                                alpha: 0.75,
                                              ),
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
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
  }

  void _openGenreDetail(
    BuildContext context,
    WidgetRef ref,
    SubsonicClient client,
    Genre genre,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF16171D),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return DraggableScrollableSheet(
          initialChildSize: 0.75,
          maxChildSize: 0.95,
          minChildSize: 0.4,
          expand: false,
          builder: (context, scrollController) {
            return Consumer(
              builder: (context, ref, _) {
                final genreSongs = ref.watch(songsByGenreProvider(genre.name));
                final starredIds = ref.watch(starredIdsProvider);

                return Column(
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                      child: Row(
                        children: <Widget>[
                          Text(
                            genre.name,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const Spacer(),
                          genreSongs.maybeWhen(
                            data: (songs) => songs.isEmpty
                                ? const SizedBox.shrink()
                                : FilledButton.icon(
                                    onPressed: () async {
                                      final items =
                                          await playableItemsForSongsWithLocalFiles(
                                            client,
                                            ref.read(downloadManagerProvider),
                                            songs,
                                          );
                                      await ref
                                          .read(audioPlayerProvider)
                                          .setQueue(items, startIndex: 0);
                                      await ref
                                          .read(audioPlayerProvider)
                                          .play();
                                      if (sheetContext.mounted) {
                                        Navigator.of(sheetContext).pop();
                                      }
                                    },
                                    style: FilledButton.styleFrom(
                                      backgroundColor: const Color(0xFF1E7BF6),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 0,
                                      ),
                                      minimumSize: const Size(0, 34),
                                    ),
                                    icon: const Icon(
                                      Icons.play_arrow_rounded,
                                      size: 18,
                                    ),
                                    label: Text(context.l10n.playAll),
                                  ),
                            orElse: () => const SizedBox.shrink(),
                          ),
                        ],
                      ),
                    ),
                    const Divider(color: Colors.white12, height: 1),
                    Expanded(
                      child: genreSongs.when(
                        loading: () => const Center(
                          child: CircularProgressIndicator(
                            color: Color(0xFF1E7BF6),
                          ),
                        ),
                        error: (err, stack) => Center(
                          child: Text(
                            context.l10n.loadFailed(err.toString()),
                            style: const TextStyle(color: Colors.white70),
                          ),
                        ),
                        data: (songs) {
                          if (songs.isEmpty) {
                            return Center(
                              child: Text(
                                context.l10n.genreEmpty,
                                style: TextStyle(color: Colors.white54),
                              ),
                            );
                          }
                          return ListView.builder(
                            controller: scrollController,
                            itemCount: songs.length,
                            itemBuilder: (context, index) {
                              final song = songs[index];
                              final isFav = starredIds.songs.contains(song.id);

                              return SongListTile(
                                index: index + 1,
                                song: song,
                                client: client,
                                isFavorite: isFav,
                                onFavorite: () => ref
                                    .read(starredProvider.notifier)
                                    .toggleSong(song),
                                onTap: () async {
                                  final items =
                                      await playableItemsForSongsWithLocalFiles(
                                        client,
                                        ref.read(downloadManagerProvider),
                                        songs,
                                      );
                                  await ref
                                      .read(audioPlayerProvider)
                                      .setQueue(items, startIndex: index);
                                  await ref.read(audioPlayerProvider).play();
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
            );
          },
        );
      },
    );
  }
}
