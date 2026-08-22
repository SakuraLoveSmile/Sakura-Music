import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
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
                    title: const Text('专辑'),
                    floating: true,
                    actions: <Widget>[
                      IconButton(
                        tooltip: '刷新',
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
                          ? const SliverFillRemaining(
                              hasScrollBody: false,
                              child: Center(child: Text('服务器中还没有专辑。')),
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
                                    const SliverToBoxAdapter(
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
                                    const SliverToBoxAdapter(
                                      child: Padding(
                                        padding: EdgeInsets.only(top: 20),
                                        child: Center(child: Text('已加载全部专辑')),
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
            const Text('请先在服务器页添加一个音乐库。'),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => context.go('/settings'),
              child: const Text('去添加服务器'),
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
            Text('加载专辑失败：$error', textAlign: TextAlign.center),
            const SizedBox(height: 16),
            OutlinedButton(onPressed: onRetry, child: const Text('重试')),
          ],
        ),
      ),
    );
  }
}
