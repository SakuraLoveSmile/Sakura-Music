import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../shared/media_widgets.dart';

class PlaylistsScreen extends ConsumerWidget {
  const PlaylistsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final client = ref.watch(activeSubsonicClientProvider);
    final playlists = ref.watch(playlistsProvider);
    if (client == null) {
      return const SafeArea(child: NoServerView());
    }
    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: SafeArea(
        child: CustomScrollView(
          slivers: <Widget>[
            SliverAppBar(
              title: const Text('歌单'),
              floating: true,
              actions: <Widget>[
                IconButton(
                  tooltip: '刷新',
                  onPressed: () => ref.invalidate(playlistsProvider),
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            playlists.when(
              loading: () => const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, stackTrace) => SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: Text('加载歌单失败：$error')),
              ),
              data: (items) => items.isEmpty
                  ? const SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(child: Text('还没有歌单。')),
                    )
                  : SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                      sliver: SliverLayoutBuilder(
                        builder: (context, constraints) {
                          final columns = (constraints.crossAxisExtent / 190)
                              .floor()
                              .clamp(2, 8)
                              .toInt();
                          return SliverGrid.builder(
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: columns,
                                  crossAxisSpacing: 16,
                                  mainAxisSpacing: 20,
                                  childAspectRatio: .72,
                                ),
                            itemCount: items.length,
                            itemBuilder: (context, index) {
                              final playlist = items[index];
                              final imageUrl = playlist.coverArt == null
                                  ? null
                                  : client.coverArtUrl(
                                      playlist.coverArt!,
                                      size: 320,
                                    );
                              return InkWell(
                                borderRadius: BorderRadius.circular(18),
                                onTap: () =>
                                    context.go('/playlists/${playlist.id}'),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Expanded(
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(18),
                                        child: imageUrl == null
                                            ? const ColoredBox(
                                                color: Colors.black12,
                                                child: Center(
                                                  child: Icon(
                                                    Icons.queue_music,
                                                    size: 64,
                                                  ),
                                                ),
                                              )
                                            : CachedNetworkImage(
                                                imageUrl: imageUrl,
                                                cacheKey:
                                                    'playlist_${playlist.coverArt}',
                                                fit: BoxFit.cover,
                                              ),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      playlist.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    Text(
                                      '${playlist.songCount ?? playlist.songs.length} 首歌曲',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodySmall,
                                    ),
                                  ],
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
