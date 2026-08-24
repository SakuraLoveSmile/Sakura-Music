import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:subsonic_api/subsonic_api.dart';

import '../../core/providers.dart';
import '../../l10n/l10n.dart';
import '../shared/media_widgets.dart';

enum ArtistViewMode { grid, list }

enum ArtistSortOption { nameAsc, nameDesc, albumCountDesc, starredFirst }

class ArtistsScreen extends ConsumerStatefulWidget {
  const ArtistsScreen({super.key});

  @override
  ConsumerState<ArtistsScreen> createState() => _ArtistsScreenState();
}

class _ArtistsScreenState extends ConsumerState<ArtistsScreen> {
  ArtistViewMode _viewMode = ArtistViewMode.grid;
  ArtistSortOption _sortOption = ArtistSortOption.nameAsc;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isSearching = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Artist> _filterAndSort(List<Artist> items, Set<String> starredArtistIds) {
    var filtered = items;
    if (_searchQuery.trim().isNotEmpty) {
      final query = _searchQuery.trim().toLowerCase();
      filtered = filtered
          .where((artist) => artist.name.toLowerCase().contains(query))
          .toList();
    }

    final sorted = [...filtered];
    switch (_sortOption) {
      case ArtistSortOption.nameAsc:
        sorted.sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );
        break;
      case ArtistSortOption.nameDesc:
        sorted.sort(
          (a, b) => b.name.toLowerCase().compareTo(a.name.toLowerCase()),
        );
        break;
      case ArtistSortOption.albumCountDesc:
        sorted.sort((a, b) {
          final countA = a.albumCount ?? 0;
          final countB = b.albumCount ?? 0;
          if (countA != countB) {
            return countB.compareTo(countA);
          }
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        });
        break;
      case ArtistSortOption.starredFirst:
        sorted.sort((a, b) {
          final isAStarred = starredArtistIds.contains(a.id);
          final isBStarred = starredArtistIds.contains(b.id);
          if (isAStarred != isBStarred) {
            return isAStarred ? -1 : 1;
          }
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        });
        break;
    }
    return sorted;
  }

  @override
  Widget build(BuildContext context) {
    final artistsAsync = ref.watch(artistsProvider);
    final client = ref.watch(activeSubsonicClientProvider);
    final starredIds = ref.watch(starredIdsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF131418),
      body: SafeArea(
        child: artistsAsync.when(
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
                    onPressed: () => ref.invalidate(artistsProvider),
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: Text(context.l10n.refresh),
                  ),
                ],
              ),
            ),
          ),
          data: (rawItems) {
            if (rawItems.isEmpty) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const Icon(
                      Icons.person_outline_rounded,
                      size: 56,
                      color: Colors.white24,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      context.l10n.emptyArtists,
                      style: const TextStyle(color: Colors.white54),
                    ),
                  ],
                ),
              );
            }

            final items = _filterAndSort(rawItems, starredIds.artists);

            return CustomScrollView(
              slivers: <Widget>[
                // Header Bar
                SliverAppBar(
                  backgroundColor: const Color(0xFF131418),
                  floating: true,
                  pinned: true,
                  elevation: 0,
                  title: _isSearching
                      ? Container(
                          height: 38,
                          decoration: BoxDecoration(
                            color: const Color(0xFF22242D),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.08),
                            ),
                          ),
                          child: TextField(
                            controller: _searchController,
                            autofocus: true,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                            ),
                            decoration: InputDecoration(
                              hintText: context.l10n.filterArtistsHint,
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
                              suffixIcon: _searchController.text.isNotEmpty
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
                                        _searchController.clear();
                                        setState(() => _searchQuery = '');
                                      },
                                    )
                                  : null,
                              contentPadding:
                                  const EdgeInsets.symmetric(vertical: 8),
                            ),
                            onChanged: (val) =>
                                setState(() => _searchQuery = val),
                          ),
                        )
                      : Row(
                          children: <Widget>[
                            Text(
                              context.l10n.navArtists,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 20,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E7BF6)
                                    .withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: const Color(0xFF1E7BF6)
                                      .withValues(alpha: 0.3),
                                  width: 0.8,
                                ),
                              ),
                              child: Text(
                                '${rawItems.length}',
                                style: const TextStyle(
                                  color: Color(0xFF5BA4FF),
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                  actions: <Widget>[
                    // Search toggle
                    IconButton(
                      tooltip: _isSearching
                          ? context.l10n.close
                          : context.l10n.search,
                      icon: Icon(
                        _isSearching
                            ? Icons.close_rounded
                            : Icons.search_rounded,
                        color: Colors.white70,
                      ),
                      onPressed: () {
                        setState(() {
                          _isSearching = !_isSearching;
                          if (!_isSearching) {
                            _searchController.clear();
                            _searchQuery = '';
                          }
                        });
                      },
                    ),
                    // View mode switcher
                    IconButton(
                      tooltip: _viewMode == ArtistViewMode.grid
                          ? context.l10n.viewList
                          : context.l10n.viewGrid,
                      icon: Icon(
                        _viewMode == ArtistViewMode.grid
                            ? Icons.view_list_rounded
                            : Icons.grid_view_rounded,
                        color: Colors.white70,
                      ),
                      onPressed: () {
                        setState(() {
                          _viewMode = _viewMode == ArtistViewMode.grid
                              ? ArtistViewMode.list
                              : ArtistViewMode.grid;
                        });
                      },
                    ),
                    // Sort options menu
                    PopupMenuButton<ArtistSortOption>(
                      tooltip: context.l10n.sortBy,
                      icon: const Icon(
                        Icons.sort_rounded,
                        color: Colors.white70,
                      ),
                      color: const Color(0xFF22242D),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      initialValue: _sortOption,
                      onSelected: (option) =>
                          setState(() => _sortOption = option),
                      itemBuilder: (context) => <PopupMenuEntry<ArtistSortOption>>[
                        PopupMenuItem(
                          value: ArtistSortOption.nameAsc,
                          child: Row(
                            children: <Widget>[
                              Icon(
                                Icons.sort_by_alpha_rounded,
                                size: 18,
                                color: _sortOption == ArtistSortOption.nameAsc
                                    ? const Color(0xFF1E7BF6)
                                    : Colors.white70,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                context.l10n.sortNameAsc,
                                style: TextStyle(
                                  color: _sortOption == ArtistSortOption.nameAsc
                                      ? const Color(0xFF5BA4FF)
                                      : Colors.white,
                                  fontWeight:
                                      _sortOption == ArtistSortOption.nameAsc
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                ),
                              ),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: ArtistSortOption.nameDesc,
                          child: Row(
                            children: <Widget>[
                              Icon(
                                Icons.sort_by_alpha_rounded,
                                size: 18,
                                color: _sortOption == ArtistSortOption.nameDesc
                                    ? const Color(0xFF1E7BF6)
                                    : Colors.white70,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                context.l10n.sortNameDesc,
                                style: TextStyle(
                                  color: _sortOption == ArtistSortOption.nameDesc
                                      ? const Color(0xFF5BA4FF)
                                      : Colors.white,
                                  fontWeight:
                                      _sortOption == ArtistSortOption.nameDesc
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                ),
                              ),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: ArtistSortOption.albumCountDesc,
                          child: Row(
                            children: <Widget>[
                              Icon(
                                Icons.album_rounded,
                                size: 18,
                                color:
                                    _sortOption == ArtistSortOption.albumCountDesc
                                        ? const Color(0xFF1E7BF6)
                                        : Colors.white70,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                context.l10n.sortAlbumCount,
                                style: TextStyle(
                                  color:
                                      _sortOption == ArtistSortOption.albumCountDesc
                                          ? const Color(0xFF5BA4FF)
                                          : Colors.white,
                                  fontWeight:
                                      _sortOption ==
                                              ArtistSortOption.albumCountDesc
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                ),
                              ),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: ArtistSortOption.starredFirst,
                          child: Row(
                            children: <Widget>[
                              Icon(
                                Icons.favorite_rounded,
                                size: 18,
                                color:
                                    _sortOption == ArtistSortOption.starredFirst
                                        ? const Color(0xFFFF453A)
                                        : Colors.white70,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                context.l10n.favorite,
                                style: TextStyle(
                                  color:
                                      _sortOption == ArtistSortOption.starredFirst
                                          ? const Color(0xFF5BA4FF)
                                          : Colors.white,
                                  fontWeight:
                                      _sortOption ==
                                              ArtistSortOption.starredFirst
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    // Refresh
                    IconButton(
                      tooltip: context.l10n.refresh,
                      onPressed: () => ref.invalidate(artistsProvider),
                      icon: const Icon(
                        Icons.refresh_rounded,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),

                // Active Search Filter Summary (if searching)
                if (_searchQuery.trim().isNotEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
                      child: Row(
                        children: <Widget>[
                          Text(
                            context.l10n.artistCount(items.length),
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.5),
                              fontSize: 13,
                            ),
                          ),
                          const Spacer(),
                          TextButton(
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                            child: Text(
                              context.l10n.clear,
                              style: const TextStyle(
                                color: Color(0xFF5BA4FF),
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Empty Search Result
                if (items.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          const Icon(
                            Icons.search_off_rounded,
                            size: 48,
                            color: Colors.white30,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            context.l10n.noSearchResults,
                            style: const TextStyle(color: Colors.white60),
                          ),
                          const SizedBox(height: 12),
                          FilledButton.tonal(
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                            child: Text(context.l10n.clear),
                          ),
                        ],
                      ),
                    ),
                  )
                // Grid View Mode
                else if (_viewMode == ArtistViewMode.grid)
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 32),
                    sliver: SliverLayoutBuilder(
                      builder: (context, constraints) {
                        final columns = (constraints.crossAxisExtent / 130)
                            .floor()
                            .clamp(2, 6)
                            .toInt();
                        return SliverGrid.builder(
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: columns,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 14,
                            childAspectRatio: 0.76,
                          ),
                          itemCount: items.length,
                          itemBuilder: (context, index) {
                            final artist = items[index];
                            final isFav =
                                starredIds.artists.contains(artist.id);
                            return ArtistCard(
                              artist: artist,
                              client: client,
                              isFavorite: isFav,
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
                        );
                      },
                    ),
                  )
                // List View Mode
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 32),
                    sliver: SliverList.builder(
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final artist = items[index];
                        final isFav = starredIds.artists.contains(artist.id);
                        return ArtistListTile(
                          artist: artist,
                          client: client,
                          isFavorite: isFav,
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
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

