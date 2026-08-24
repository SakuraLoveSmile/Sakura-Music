import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../audio/audio_player_provider.dart';
import '../../audio/playable_item_builder.dart';
import '../../core/providers.dart';
import '../../data/download_manager.dart';
import '../../data/server_repository.dart';
import '../../l10n/l10n.dart';
import '../shared/media_widgets.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  Timer? _debounce;
  String _query = '';

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      if (!mounted) return;
      setState(() => _query = value.trim());
    });
  }

  Future<void> _recordSearch(String value) async {
    final query = value.trim();
    if (query.isEmpty) return;
    await ref.read(databaseProvider).recordSearch(query);
    ref.invalidate(recentSearchHistoryProvider);
  }

  @override
  Widget build(BuildContext context) {
    final client = ref.watch(activeSubsonicClientProvider);
    if (client == null) {
      return const SafeArea(child: NoServerView());
    }
    final history = ref.watch(recentSearchHistoryProvider);
    final starredIds = ref.watch(starredIdsProvider);
    final results = _query.isEmpty ? null : ref.watch(searchProvider(_query));

    return Scaffold(
      backgroundColor: const Color(0xFF131418),
      appBar: AppBar(
        backgroundColor: const Color(0xFF131418),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.chevron_left_rounded,
            size: 28,
            color: Colors.white,
          ),
          tooltip: context.l10n.back,
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/home');
            }
          },
        ),
        title: Container(
          height: 38,
          decoration: BoxDecoration(
            color: const Color(0xFF22242D),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
          ),
          child: TextField(
            controller: _controller,
            autofocus: true,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: context.l10n.searchHint,
              hintStyle: TextStyle(
                color: Colors.white.withValues(alpha: 0.4),
                fontSize: 13.5,
              ),
              border: InputBorder.none,
              prefixIcon: Icon(
                Icons.search_rounded,
                size: 18,
                color: Colors.white.withValues(alpha: 0.45),
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 8),
              suffixIcon: _controller.text.isNotEmpty
                  ? IconButton(
                      tooltip: context.l10n.clear,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints.tightFor(
                        width: 28,
                        height: 28,
                      ),
                      icon: const Icon(
                        Icons.close_rounded,
                        size: 16,
                        color: Colors.white54,
                      ),
                      onPressed: () {
                        _controller.clear();
                        setState(() => _query = '');
                      },
                    )
                  : null,
            ),
            onChanged: _onQueryChanged,
            onSubmitted: _recordSearch,
          ),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: CustomScrollView(
            slivers: <Widget>[
              if (_query.isEmpty)
                SliverToBoxAdapter(
                  child: _SearchHistory(
                    history: history,
                    onTap: (keyword) {
                      _controller.text = keyword;
                      _controller.selection = TextSelection.fromPosition(
                        TextPosition(offset: keyword.length),
                      );
                      setState(() => _query = keyword);
                    },
                    onClear: () async {
                      await ref.read(databaseProvider).clearSearchHistory();
                      ref.invalidate(recentSearchHistoryProvider);
                    },
                  ),
                )
              else
                results!.when(
                  loading: () => const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF1E7BF6),
                      ),
                    ),
                  ),
                  error: (error, stackTrace) => SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Text(
                        context.l10n.searchFailed(error.toString()),
                        style: const TextStyle(color: Colors.white60),
                      ),
                    ),
                  ),
                  data: (value) => SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                    sliver: SliverMainAxisGroup(
                      slivers: <Widget>[
                        // 1. Artists Section
                        if (value.artists.isNotEmpty) ...[
                          _ResultHeader(
                            title: context.l10n.navArtists,
                            count: value.artists.length,
                          ),
                          SliverList.builder(
                            itemCount: value.artists.length,
                            itemBuilder: (context, index) {
                              final artist = value.artists[index];
                              return ArtistListTile(
                                artist: artist,
                                isFavorite: starredIds.artists.contains(
                                  artist.id,
                                ),
                                onFavorite: () => ref
                                    .read(starredProvider.notifier)
                                    .toggleArtist(artist),
                                onTap: () => context.go(
                                  '/artists/${Uri.encodeComponent(artist.id)}',
                                ),
                              );
                            },
                          ),
                        ],

                        // 2. Albums Section
                        if (value.albums.isNotEmpty) ...[
                          _ResultHeader(
                            title: context.l10n.navAlbums,
                            count: value.albums.length,
                          ),
                          SliverToBoxAdapter(
                            child: SizedBox(
                              height: 230,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: value.albums.length,
                                separatorBuilder: (context, index) =>
                                    const SizedBox(width: 14),
                                itemBuilder: (context, index) {
                                  final album = value.albums[index];
                                  return SizedBox(
                                    width: 154,
                                    child: AlbumCard(
                                      album: album,
                                      client: client,
                                      isFavorite: starredIds.albums.contains(
                                        album.id,
                                      ),
                                      onFavorite: () => ref
                                          .read(starredProvider.notifier)
                                          .toggleAlbum(album),
                                      onTap: () => context.go(
                                        '/albums/${Uri.encodeComponent(album.id)}',
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ],

                        // 3. Songs Section
                        if (value.songs.isNotEmpty) ...[
                          _ResultHeader(
                            title: context.l10n.navSongs,
                            count: value.songs.length,
                          ),
                          SliverList.builder(
                            itemCount: value.songs.length,
                            itemBuilder: (context, index) {
                              final song = value.songs[index];
                              return SongListTile(
                                index: index + 1,
                                song: song,
                                client: client,
                                isFavorite: starredIds.songs.contains(song.id),
                                onFavorite: () => ref
                                    .read(starredProvider.notifier)
                                    .toggleSong(song),
                                onTap: () async {
                                  final items =
                                      await playableItemsForSongsWithLocalFiles(
                                        client,
                                        ref.read(downloadManagerProvider),
                                        value.songs,
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
                        ],

                        if (value.artists.isEmpty &&
                            value.albums.isEmpty &&
                            value.songs.isEmpty)
                          SliverFillRemaining(
                            hasScrollBody: false,
                            child: Center(
                              child: Text(
                                context.l10n.noSearchMatches,
                                style: const TextStyle(
                                  color: Colors.white54,
                                  fontSize: 14,
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
    );
  }
}

class _SearchHistory extends StatelessWidget {
  const _SearchHistory({
    required this.history,
    required this.onTap,
    required this.onClear,
  });

  final AsyncValue<List<String>> history;
  final ValueChanged<String> onTap;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text(
                context.l10n.searchHistory,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                tooltip: context.l10n.clearHistory,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints.tightFor(
                  width: 28,
                  height: 28,
                ),
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  size: 18,
                  color: Colors.white38,
                ),
                onPressed: onClear,
              ),
            ],
          ),
          const SizedBox(height: 10),
          history.when(
            loading: () => const SizedBox.shrink(),
            error: (error, stackTrace) => Text(
              context.l10n.searchHistoryLoadFailed(error.toString()),
              style: const TextStyle(color: Colors.white38),
            ),
            data: (items) => items.isEmpty
                ? Text(
                    context.l10n.emptySearchHistory,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.35),
                      fontSize: 13,
                    ),
                  )
                : Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: items
                        .map(
                          (keyword) => InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: () => onTap(keyword),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E2028),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.06),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  const Icon(
                                    Icons.history_rounded,
                                    size: 15,
                                    color: Colors.white38,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    keyword,
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        )
                        .toList(growable: false),
                  ),
          ),
        ],
      ),
    );
  }
}

class _ResultHeader extends StatelessWidget {
  const _ResultHeader({required this.title, required this.count});

  final String title;
  final int count;

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 16, 4, 10),
        child: Row(
          children: <Widget>[
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: const Color(0xFF1E7BF6).withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '$count',
                style: const TextStyle(
                  color: Color(0xFF1E7BF6),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
