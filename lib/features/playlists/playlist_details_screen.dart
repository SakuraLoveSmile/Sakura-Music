import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../audio/audio_player_provider.dart';
import '../../audio/audio_player_service.dart';
import '../../audio/playable_item_builder.dart';
import '../../core/providers.dart';
import '../../data/download_manager.dart';
import '../../l10n/l10n.dart';
import '../shared/media_widgets.dart';

class PlaylistDetailsScreen extends ConsumerWidget {
  const PlaylistDetailsScreen({required this.playlistId, super.key});

  final String playlistId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final client = ref.watch(activeSubsonicClientProvider);
    final playlist = ref.watch(playlistDetailsProvider(playlistId));
    if (client == null) {
      return const NoServerView();
    }
    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: SafeArea(
        child: playlist.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) =>
              Center(
                child: Text(
                  context.l10n.playlistsLoadFailed(error.toString()),
                ),
              ),
          data: (value) {
            final starredIds = ref.watch(starredIdsProvider);
            return CustomScrollView(
              slivers: <Widget>[
                SliverAppBar(
                  title: Text(value.name),
                  pinned: true,
                  leading: IconButton(
                    tooltip: context.l10n.back,
                    onPressed: () {
                      if (context.canPop()) {
                        context.pop();
                      } else {
                        context.go('/playlists');
                      }
                    },
                    icon: const Icon(Icons.arrow_back),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
                    child: Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: <Widget>[
                        FilledButton.icon(
                          onPressed: value.songs.isEmpty
                              ? null
                              : () async {
                                  final items =
                                      await playableItemsForSongsWithLocalFiles(
                                        client,
                                        ref.read(downloadManagerProvider),
                                        value.songs,
                                      );
                                  if (!context.mounted) {
                                    return;
                                  }
                                  await _play(context, ref, items, 0);
                                },
                          icon: const Icon(Icons.play_arrow),
                          label: Text(context.l10n.playAll),
                        ),
                        OutlinedButton.icon(
                          onPressed: value.songs.isEmpty
                              ? null
                              : () async {
                                  final items =
                                      await playableItemsForSongsWithLocalFiles(
                                        client,
                                        ref.read(downloadManagerProvider),
                                        value.songs,
                                      );
                                  await _append(ref, items);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          context.l10n.addedToQueue,
                                        ),
                                      ),
                                    );
                                  }
                                },
                          icon: const Icon(Icons.playlist_add),
                          label: Text(context.l10n.addToQueue),
                        ),
                      ],
                    ),
                  ),
                ),
                if (value.songs.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(child: Text(context.l10n.playlistEmpty)),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 32),
                    sliver: SliverList.builder(
                      itemCount: value.songs.length,
                      itemBuilder: (context, index) {
                        final song = value.songs[index];
                        return SongListTile(
                          index: index + 1,
                          song: song,
                          client: client,
                          onTap: () async {
                            final items =
                                await playableItemsForSongsWithLocalFiles(
                                  client,
                                  ref.read(downloadManagerProvider),
                                  value.songs,
                                );
                            if (!context.mounted) {
                              return;
                            }
                            await _play(context, ref, items, index);
                          },
                          isFavorite: starredIds.songs.contains(song.id),
                          onFavorite: () => ref
                              .read(starredProvider.notifier)
                              .toggleSong(song),
                          onMore: () {
                            showSongActionBottomSheet(
                              context: context,
                              ref: ref,
                              song: song,
                              client: client,
                            );
                          },
                          key: ValueKey(song.id),
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

Future<void> _play(
  BuildContext context,
  WidgetRef ref,
  List<PlayableItem> items,
  int index,
) async {
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
      ).showSnackBar(
        SnackBar(
          content: Text(context.l10n.playbackFailed(error.toString())),
        ),
      );
    }
  }
}

Future<void> _append(WidgetRef ref, List<PlayableItem> items) async {
  final service = ref.read(audioPlayerProvider);
  for (final item in items.reversed) {
    await service.insertNext(item);
  }
}
