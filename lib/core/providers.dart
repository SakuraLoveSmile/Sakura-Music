import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:subsonic_api/subsonic_api.dart';

import '../data/db/app_database.dart';
import '../data/server_repository.dart';

final activeSubsonicClientProvider = Provider<SubsonicClient?>((ref) {
  final server = ref.watch(activeServerProvider);
  if (server == null) {
    return null;
  }
  return SubsonicClient(
    baseUrl: server.baseUrl,
    username: server.username,
    password: server.password,
  );
});

class AlbumsPage {
  const AlbumsPage({
    required this.items,
    required this.hasMore,
    this.isLoadingMore = false,
  });

  final List<Album> items;
  final bool hasMore;
  final bool isLoadingMore;

  AlbumsPage copyWith({
    List<Album>? items,
    bool? hasMore,
    bool? isLoadingMore,
  }) {
    return AlbumsPage(
      items: items ?? this.items,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }
}

class AlbumsPager extends AsyncNotifier<AlbumsPage> {
  static const _pageSize = 30;

  bool _isLoadingMore = false;

  @override
  Future<AlbumsPage> build() async {
    final client = ref.watch(activeSubsonicClientProvider);
    final server = ref.watch(activeServerProvider);
    if (client == null) {
      return const AlbumsPage(items: <Album>[], hasMore: false);
    }

    final database = ref.read(databaseProvider);
    final cached = server == null
        ? const <Album>[]
        : await _albumsFromCache(await database.getCachedAlbums(server.id));
    try {
      final albums = await client.getAlbumList(size: _pageSize);
      if (server != null) {
        await database.cacheAlbums(
          serverId: server.id,
          payloads: <String, String>{
            for (final album in albums) album.id: jsonEncode(album.toJson()),
          },
        );
      }
      return AlbumsPage(items: albums, hasMore: albums.length >= _pageSize);
    } catch (_) {
      if (cached.isNotEmpty) {
        return AlbumsPage(items: cached, hasMore: false);
      }
      rethrow;
    }
  }

  Future<void> loadMore() async {
    if (_isLoadingMore) {
      return;
    }

    final currentPage = state.asData?.value;
    if (currentPage == null || !currentPage.hasMore) {
      return;
    }

    final client = ref.read(activeSubsonicClientProvider);
    if (client == null) {
      return;
    }

    _isLoadingMore = true;
    state = AsyncData<AlbumsPage>(currentPage.copyWith(isLoadingMore: true));
    try {
      final albums = await client.getAlbumList(
        size: _pageSize,
        offset: currentPage.items.length,
      );

      final latestPage = state.asData?.value;
      if (latestPage == null ||
          !identical(latestPage.items, currentPage.items)) {
        return;
      }

      state = AsyncData<AlbumsPage>(
        currentPage.copyWith(
          items: List<Album>.unmodifiable(<Album>[
            ...currentPage.items,
            ...albums,
          ]),
          hasMore: albums.length >= _pageSize,
          isLoadingMore: false,
        ),
      );
      final server = ref.read(activeServerProvider);
      if (server != null) {
        await ref
            .read(databaseProvider)
            .cacheAlbums(
              serverId: server.id,
              payloads: <String, String>{
                for (final album in albums)
                  album.id: jsonEncode(album.toJson()),
              },
            );
      }
    } catch (_) {
      final latestPage = state.asData?.value;
      if (latestPage != null &&
          identical(latestPage.items, currentPage.items)) {
        state = AsyncData<AlbumsPage>(
          currentPage.copyWith(isLoadingMore: false),
        );
      }
    } finally {
      _isLoadingMore = false;
    }
  }
}

final albumsPagerProvider = AsyncNotifierProvider<AlbumsPager, AlbumsPage>(
  AlbumsPager.new,
);

final albumDetailsProvider = FutureProvider.family<Album, String>((ref, id) {
  final client = ref.watch(activeSubsonicClientProvider);
  if (client == null) {
    throw StateError('Add a server before opening an album');
  }
  return _albumWithCache(ref, client, id);
});

final artistsProvider = FutureProvider<List<Artist>>((ref) {
  final client = ref.watch(activeSubsonicClientProvider);
  if (client == null) {
    return const <Artist>[];
  }
  return _artistsWithCache(ref, client);
});

final artistDetailsProvider = FutureProvider.family<Artist, String>((ref, id) {
  final client = ref.watch(activeSubsonicClientProvider);
  if (client == null) {
    throw StateError('Add a server before opening an artist');
  }
  return _artistWithCache(ref, client, id);
});

final artistInfoProvider = FutureProvider.family<ArtistInfo2, String>((
  ref,
  id,
) {
  final client = ref.watch(activeSubsonicClientProvider);
  if (client == null) {
    throw StateError('Add a server before loading artist info');
  }
  return client.getArtistInfo2(id);
});

final newestAlbumsProvider = FutureProvider<List<Album>>((ref) {
  final client = ref.watch(activeSubsonicClientProvider);
  if (client == null) {
    return const <Album>[];
  }
  return client.getAlbumList(type: 'newest', size: 12);
});

final frequentAlbumsProvider = FutureProvider<List<Album>>((ref) {
  final client = ref.watch(activeSubsonicClientProvider);
  if (client == null) {
    return const <Album>[];
  }
  return client.getAlbumList(type: 'frequent', size: 12);
});

final randomAlbumsProvider = FutureProvider<List<Album>>((ref) {
  final client = ref.watch(activeSubsonicClientProvider);
  if (client == null) {
    return const <Album>[];
  }
  return client.getAlbumList(type: 'random', size: 12);
});

final randomSongsProvider = FutureProvider<List<Song>>((ref) {
  final client = ref.watch(activeSubsonicClientProvider);
  if (client == null) {
    return const <Song>[];
  }
  return client.getRandomSongs(size: 12);
});

final dailyRecommendSongsProvider = FutureProvider<List<Song>>((ref) {
  final client = ref.watch(activeSubsonicClientProvider);
  if (client == null) {
    return const <Song>[];
  }
  return client.getRandomSongs(size: 50);
});

final songsListProvider = FutureProvider<List<Song>>((ref) {
  final client = ref.watch(activeSubsonicClientProvider);
  if (client == null) {
    return const <Song>[];
  }
  return client.getRandomSongs(size: 50);
});

final frequentSongsProvider = FutureProvider<List<Song>>((ref) {
  final client = ref.watch(activeSubsonicClientProvider);
  if (client == null) {
    return const <Song>[];
  }
  return client.getRandomSongs(size: 10);
});

final genresProvider = FutureProvider<List<Genre>>((ref) {
  final client = ref.watch(activeSubsonicClientProvider);
  if (client == null) {
    return const <Genre>[];
  }
  return client.getGenres();
});

final songsByGenreProvider = FutureProvider.family<List<Song>, String>((
  ref,
  genre,
) {
  final client = ref.watch(activeSubsonicClientProvider);
  if (client == null || genre.trim().isEmpty) {
    return const <Song>[];
  }
  return client.getSongsByGenre(genre, count: 50);
});

final playlistsProvider = FutureProvider<List<Playlist>>((ref) {
  final client = ref.watch(activeSubsonicClientProvider);
  if (client == null) {
    return const <Playlist>[];
  }
  return client.getPlaylists();
});

final playlistDetailsProvider = FutureProvider.family<Playlist, String>((
  ref,
  id,
) {
  final client = ref.watch(activeSubsonicClientProvider);
  if (client == null) {
    throw StateError('Add a server before opening a playlist');
  }
  return client.getPlaylist(id);
});

final searchProvider = FutureProvider.family<SearchResult3, String>((
  ref,
  query,
) {
  final client = ref.watch(activeSubsonicClientProvider);
  if (client == null || query.trim().isEmpty) {
    return const SearchResult3();
  }
  return client.search3(query.trim());
});

final recentSearchHistoryProvider = FutureProvider<List<String>>((ref) {
  return ref.watch(databaseProvider).getSearchHistory();
});

final recentPlayIdsProvider = FutureProvider<List<String>>((ref) {
  return ref
      .watch(databaseProvider)
      .getRecentPlayIds(serverId: ref.watch(activeServerProvider)?.id);
});

class StarredNotifier extends AsyncNotifier<Starred2> {
  @override
  Future<Starred2> build() async {
    final client = ref.watch(activeSubsonicClientProvider);
    if (client == null) {
      return const Starred2();
    }
    return client.getStarred2();
  }

  Future<void> toggleSong(Song song) => _toggle(
    isStarred: state.value?.songs.any((item) => item.id == song.id) ?? false,
    optimistic: (value) => value.copyWith(
      songs: value.songs
          .where((item) => item.id != song.id)
          .followedBy(
            value.songs.any((item) => item.id == song.id)
                ? const <Song>[]
                : <Song>[song],
          )
          .toList(growable: false),
    ),
    request: (client, starred) =>
        starred ? client.unstar(id: song.id) : client.star(id: song.id),
  );

  Future<void> toggleAlbum(Album album) => _toggle(
    isStarred: state.value?.albums.any((item) => item.id == album.id) ?? false,
    optimistic: (value) => value.copyWith(
      albums: value.albums
          .where((item) => item.id != album.id)
          .followedBy(
            value.albums.any((item) => item.id == album.id)
                ? const <Album>[]
                : <Album>[album],
          )
          .toList(growable: false),
    ),
    request: (client, starred) => starred
        ? client.unstar(albumId: album.id)
        : client.star(albumId: album.id),
  );

  Future<void> toggleArtist(Artist artist) => _toggle(
    isStarred:
        state.value?.artists.any((item) => item.id == artist.id) ?? false,
    optimistic: (value) => value.copyWith(
      artists: value.artists
          .where((item) => item.id != artist.id)
          .followedBy(
            value.artists.any((item) => item.id == artist.id)
                ? const <Artist>[]
                : <Artist>[artist],
          )
          .toList(growable: false),
    ),
    request: (client, starred) => starred
        ? client.unstar(artistId: artist.id)
        : client.star(artistId: artist.id),
  );

  Future<void> _toggle({
    required bool isStarred,
    required Starred2 Function(Starred2 value) optimistic,
    required Future<void> Function(SubsonicClient client, bool starred) request,
  }) async {
    final client = ref.read(activeSubsonicClientProvider);
    final previous = state.value ?? const Starred2();
    if (client == null) {
      throw StateError('Add a server before changing favorites');
    }
    state = AsyncData(optimistic(previous));
    try {
      await request(client, isStarred);
    } catch (error, stackTrace) {
      state = AsyncData(previous);
      Error.throwWithStackTrace(error, stackTrace);
    }
  }
}

final starredProvider = AsyncNotifierProvider<StarredNotifier, Starred2>(
  StarredNotifier.new,
);

final starredIdsProvider =
    Provider<({Set<String> songs, Set<String> albums, Set<String> artists})>((
      ref,
    ) {
      final starred = ref.watch(starredProvider.select((state) => state.value));
      return (
        songs:
            starred?.songs.map((song) => song.id).toSet() ?? const <String>{},
        albums:
            starred?.albums.map((album) => album.id).toSet() ??
            const <String>{},
        artists:
            starred?.artists.map((artist) => artist.id).toSet() ??
            const <String>{},
      );
    });

Future<List<Album>> _albumsFromCache(List<CachedAlbum> rows) async {
  final albums = <Album>[];
  for (final row in rows) {
    try {
      final decoded = jsonDecode(row.payload);
      final map = decoded is Map
          ? decoded.map((key, value) => MapEntry(key.toString(), value))
          : null;
      if (map != null) {
        albums.add(Album.fromJson(map));
      }
    } catch (_) {
      // Ignore one malformed cache record and keep the remaining albums.
    }
  }
  return albums;
}

Future<Album> _albumWithCache(Ref ref, SubsonicClient client, String id) async {
  try {
    final album = await client.getAlbum(id);
    final server = ref.read(activeServerProvider);
    if (server != null) {
      await ref
          .read(databaseProvider)
          .cacheAlbum(
            serverId: server.id,
            albumId: album.id,
            payload: jsonEncode(album.toJson()),
          );
    }
    return album;
  } catch (error) {
    final server = ref.read(activeServerProvider);
    if (server != null) {
      final rows = await ref.read(databaseProvider).getCachedAlbums(server.id);
      for (final row in rows.where((row) => row.albumId == id)) {
        try {
          final decoded = jsonDecode(row.payload);
          if (decoded is Map) {
            return Album.fromJson(
              decoded.map((key, value) => MapEntry(key.toString(), value)),
            );
          }
        } catch (_) {
          continue;
        }
      }
    }
    rethrow;
  }
}

Future<List<Artist>> _artistsWithCache(Ref ref, SubsonicClient client) async {
  try {
    final artists = await client.getArtists();
    final server = ref.read(activeServerProvider);
    if (server != null) {
      await ref
          .read(databaseProvider)
          .cacheArtists(
            serverId: server.id,
            payloads: <String, String>{
              for (final artist in artists)
                artist.id: jsonEncode(artist.toJson()),
            },
          );
    }
    return artists;
  } catch (error) {
    final server = ref.read(activeServerProvider);
    if (server == null) {
      rethrow;
    }
    final rows = await ref.read(databaseProvider).getCachedArtists(server.id);
    final artists = <Artist>[];
    for (final row in rows) {
      try {
        final decoded = jsonDecode(row.payload);
        if (decoded is Map) {
          artists.add(
            Artist.fromJson(
              decoded.map((key, value) => MapEntry(key.toString(), value)),
            ),
          );
        }
      } catch (_) {
        continue;
      }
    }
    if (artists.isNotEmpty) {
      return artists;
    }
    rethrow;
  }
}

Future<Artist> _artistWithCache(
  Ref ref,
  SubsonicClient client,
  String id,
) async {
  try {
    final artist = await client.getArtist(id);
    final server = ref.read(activeServerProvider);
    if (server != null) {
      await ref
          .read(databaseProvider)
          .cacheArtist(
            serverId: server.id,
            artistId: artist.id,
            payload: jsonEncode(artist.toJson()),
          );
    }
    return artist;
  } catch (error) {
    final server = ref.read(activeServerProvider);
    if (server != null) {
      final rows = await ref.read(databaseProvider).getCachedArtists(server.id);
      for (final row in rows.where((row) => row.artistId == id)) {
        try {
          final decoded = jsonDecode(row.payload);
          if (decoded is Map) {
            return Artist.fromJson(
              decoded.map((key, value) => MapEntry(key.toString(), value)),
            );
          }
        } catch (_) {
          continue;
        }
      }
    }
    rethrow;
  }
}
