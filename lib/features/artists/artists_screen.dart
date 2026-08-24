import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../l10n/l10n.dart';
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
              title: Text(context.l10n.navArtists),
              floating: true,
              actions: <Widget>[
                IconButton(
                  tooltip: context.l10n.refresh,
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
                child: Center(
                  child: Text(
                    context.l10n.artistsLoadFailed(error.toString()),
                  ),
                ),
              ),
              data: (items) {
                if (items.isEmpty) {
                  return SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(child: Text(context.l10n.emptyArtists)),
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
