import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../l10n/l10n.dart';
import '../shared/media_widgets.dart';

class AlbumsScreen extends ConsumerWidget {
  const AlbumsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final client = ref.watch(activeSubsonicClientProvider);
    final albums = ref.watch(albumsPagerProvider);
    final starredIds = ref.watch(starredIdsProvider);
    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: NotificationListener<ScrollNotification>(
              onNotification: (notification) {
                if (notification.metrics.pixels >
                    notification.metrics.maxScrollExtent - 400) {
                  unawaited(ref.read(albumsPagerProvider.notifier).loadMore());
                }
                return false;
              },
              child: CustomScrollView(
                slivers: <Widget>[
                  SliverAppBar(
                    title: Text(context.l10n.navAlbums),
                    floating: true,
                    actions: <Widget>[
                      IconButton(
                        tooltip: context.l10n.refresh,
                        onPressed: client == null
                            ? null
                            : () => ref.invalidate(albumsPagerProvider),
                        icon: const Icon(Icons.refresh),
                      ),
                    ],
                  ),
                  if (client == null)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: _NoServerAlbums(),
                    )
                  else
                    albums.when(
                      loading: () => const SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(child: CircularProgressIndicator()),
                      ),
                      error: (error, stackTrace) => SliverFillRemaining(
                        hasScrollBody: false,
                        child: _AlbumsError(
                          error: error,
                          onRetry: () => ref.invalidate(albumsPagerProvider),
                        ),
                      ),
                      data: (page) => page.items.isEmpty
                          ? SliverFillRemaining(
                              hasScrollBody: false,
                              child: Center(
                                child: Text(context.l10n.emptyAlbums),
                              ),
                            )
                          : SliverPadding(
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                              sliver: SliverMainAxisGroup(
                                slivers: <Widget>[
                                  SliverLayoutBuilder(
                                    builder: (context, constraints) {
                                      final columns =
                                          (constraints.crossAxisExtent / 170)
                                              .floor()
                                              .clamp(2, 8)
                                              .toInt();
                                      return SliverGrid.builder(
                                        gridDelegate:
                                            SliverGridDelegateWithFixedCrossAxisCount(
                                              crossAxisCount: columns,
                                              crossAxisSpacing: 16,
                                              mainAxisSpacing: 20,
                                              childAspectRatio: 0.72,
                                            ),
                                        itemCount: page.items.length,
                                        itemBuilder: (context, index) => AlbumCard(
                                          album: page.items[index],
                                          client: client,
                                          isFavorite: starredIds.albums
                                              .contains(page.items[index].id),
                                          onFavorite: () => ref
                                              .read(starredProvider.notifier)
                                              .toggleAlbum(page.items[index]),
                                          onTap: () => context.go(
                                            '/albums/${Uri.encodeComponent(page.items[index].id)}',
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                  if (page.isLoadingMore)
                                    SliverToBoxAdapter(
                                      child: Padding(
                                        padding: EdgeInsets.only(top: 20),
                                        child: Center(
                                          child: SizedBox.square(
                                            dimension: 22,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  if (!page.hasMore)
                                    SliverToBoxAdapter(
                                      child: Padding(
                                        padding: EdgeInsets.only(top: 20),
                                        child: Center(
                                          child: Text(
                                            context.l10n.allAlbumsLoaded,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NoServerAlbums extends StatelessWidget {
  const _NoServerAlbums();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.cloud_off, size: 64),
            const SizedBox(height: 12),
            Text(context.l10n.addLibraryFirst),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => context.go('/settings'),
              child: Text(context.l10n.goAddServer),
            ),
          ],
        ),
      ),
    );
  }
}

class _AlbumsError extends StatelessWidget {
  const _AlbumsError({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.error_outline, size: 56),
            const SizedBox(height: 12),
            Text(
              context.l10n.albumsLoadFailed(error.toString()),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            OutlinedButton(onPressed: onRetry, child: Text(context.l10n.retry)),
          ],
        ),
      ),
    );
  }
}
