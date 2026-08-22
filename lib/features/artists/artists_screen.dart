import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../shared/media_widgets.dart';

class ArtistsScreen extends ConsumerWidget {
  const ArtistsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final artists = ref.watch(artistsProvider);
    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: SafeArea(
        child: CustomScrollView(
          slivers: <Widget>[
            SliverAppBar(
              title: const Text('歌手'),
              floating: true,
              actions: <Widget>[
                IconButton(
                  tooltip: '刷新',
                  onPressed: () => ref.invalidate(artistsProvider),
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            artists.when(
              loading: () => const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, stackTrace) => SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: Text('加载歌手失败：$error')),
              ),
              data: (items) {
                if (items.isEmpty) {
                  return const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(child: Text('服务器中还没有歌手。')),
                  );
                }
                final sorted = [...items]
                  ..sort(
                    (a, b) =>
                        a.name.toLowerCase().compareTo(b.name.toLowerCase()),
                  );
                final starredIds = ref.watch(starredIdsProvider);
                return SliverPadding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 32),
                  sliver: SliverList.builder(
                    itemCount: sorted.length,
                    itemBuilder: (context, index) {
                      final artist = sorted[index];
                      return ArtistListTile(
                        artist: artist,
                        isFavorite: starredIds.artists.contains(artist.id),
                        onFavorite: () async {
                          try {
                            await ref
                                .read(starredProvider.notifier)
                                .toggleArtist(artist);
                          } catch (error) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('收藏失败：$error')),
                              );
                            }
                          }
                        },
                        onTap: () => context.go(
                          '/artists/${Uri.encodeComponent(artist.id)}',
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
