import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:subsonic_api/subsonic_api.dart';

import '../data/db/app_database.dart';
import '../data/server_repository.dart';
import 'security/server_connection.dart';

/// Reconstructs a song from denormalized recent-play metadata. New rows use
/// the real cover-art id; the album/song fallback is only for old databases.
Song songFromRecentPlay(RecentPlay play) {
  final legacyCoverArt = play.albumId != null && play.albumId!.trim().isNotEmpty
      ? play.albumId!.trim()
      : play.songId.trim().isNotEmpty
      ? play.songId.trim()
      : null;
  final coverArt = play.coverArtId != null && play.coverArtId!.trim().isNotEmpty
      ? play.coverArtId!.trim()
      : legacyCoverArt;
  return Song(
    id: play.songId,
    title: play.title ?? play.songId,
    artist: play.artist,
    album: play.album,
    albumId: play.albumId,
    artistId: play.artistId,
    coverArt: coverArt,
  );
}

/// Connection config for the active Subsonic-compatible server, with the
/// password resolved from the credential store instead of the (empty) database
/// column. Null for WebDAV servers or when no credential is available.
final activeServerConnectionProvider = Provider<ServerConnection?>((ref) {
  final server = ref.watch(activeServerProvider);
  if (server == null || server.type == 'webdav') {
    return null;
  }
  final password = ref
      .watch(credentialStoreProvider)
      .cachedServerPassword(server.id);
  if (password == null || password.isEmpty) {
    return null;
  }
  return ServerConnection(server: server, password: password);
});

final activeSubsonicClientProvider = Provider<SubsonicClient?>((ref) {
  final connection = ref.watch(activeServerConnectionProvider);
  if (connection == null) {
    return null;
  }
  return SubsonicClient(
    baseUrl: connection.baseUrl,
    username: connection.username,
    password: connection.password,
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

class DailyRecommendCacheState {
  const DailyRecommendCacheState({
    required this.date,
    required this.generation,
  });

  final String date;
  final int generation;
}

class _DatabaseCacheState {
  final Map<int, DailyRecommendCacheState> committed =
      <int, DailyRecommendCacheState>{};
  final Map<int, Future<void>> writeQueues = <int, Future<void>>{};
}

class DailyRecommendCacheCoordinator {
  static final Expando<_DatabaseCacheState> _coordinators =
      Expando<_DatabaseCacheState>();
  static _DatabaseCacheState? _lastUsedState;

  static _DatabaseCacheState _stateFor(AppDatabase? database) {
    if (database != null) {
      final state = _coordinators[database] ??= _DatabaseCacheState();
      _lastUsedState = state;
      return state;
    }
    return _lastUsedState ??= _DatabaseCacheState();
  }

  @visibleForTesting
  static void reset([AppDatabase? database]) {
    if (database != null) {
      final state = _coordinators[database];
      state?.committed.clear();
      state?.writeQueues.clear();
    } else {
      _lastUsedState?.committed.clear();
      _lastUsedState?.writeQueues.clear();
      _lastUsedState = null;
    }
  }

  @visibleForTesting
  static DailyRecommendCacheState? getCommittedState(
    int serverId, {
    AppDatabase? database,
  }) => _stateFor(database).committed[serverId];

  static void markBaseline({
    AppDatabase? database,
    required int serverId,
    required String date,
  }) {
    final state = _stateFor(database);
    final current = state.committed[serverId];
    if (current == null || date.compareTo(current.date) > 0) {
      state.committed[serverId] = DailyRecommendCacheState(
        date: date,
        generation: 0,
      );
    }
  }

  /// Enqueues a read after any pending writes for the given database and serverId.
  static Future<DailyRecommend?> readCache({
    required AppDatabase database,
    required int serverId,
    required String date,
  }) {
    final state = _stateFor(database);
    final previous = state.writeQueues[serverId] ?? Future<void>.value();
    return previous.then((_) => database.getDailyRecommend(serverId, date));
  }

  static Future<void> upsert({
    required AppDatabase database,
    required int serverId,
    required String date,
    required int generation,
    required String songsJson,
  }) {
    final state = _stateFor(database);
    final previous = state.writeQueues[serverId] ?? Future<void>.value();
    final completer = Completer<void>();
    state.writeQueues[serverId] = completer.future;

    return previous.then((_) async {
      try {
        final current = state.committed[serverId];
        if (current != null) {
          final dateCmp = date.compareTo(current.date);
          if (dateCmp < 0) {
            // Stale date: do not overwrite newer date cache.
            return;
          }
          if (dateCmp == 0 && generation < current.generation) {
            // Stale generation on same date: do not overwrite newer generation.
            return;
          }
        }

        await database.upsertDailyRecommend(serverId, date, songsJson);
        state.committed[serverId] = DailyRecommendCacheState(
          date: date,
          generation: generation,
        );
      } catch (_) {
        // Best-effort write
      } finally {
        completer.complete();
      }
    });
  }
}

class DailyRecommendSongsNotifier extends AsyncNotifier<List<Song>> {
  DailyRecommendSongsNotifier([Random? random]) : _random = random ?? Random();

  int _generation = 0;
  int? _activeShuffleTicket;
  int? _activeServerId;
  bool _disposed = false;
  final Random _random;

  @visibleForTesting
  int get generation => _generation;

  @visibleForTesting
  bool get isShuffling => _activeShuffleTicket != null;

  String _formatTodayDate([DateTime? now]) {
    final time = now ?? DateTime.now();
    return '${time.year}-${time.month.toString().padLeft(2, '0')}-${time.day.toString().padLeft(2, '0')}';
  }

  @override
  Future<List<Song>> build() async {
    _disposed = false;
    ref.onDispose(() {
      _disposed = true;
    });

    _generation++;
    final currentGen = _generation;

    final server = ref.watch(activeServerProvider);
    if (server == null) {
      _activeServerId = null;
      return const <Song>[];
    }
    _activeServerId = server.id;

    final client = ref.watch(activeSubsonicClientProvider);
    if (client == null) {
      return const <Song>[];
    }

    final date = _formatTodayDate();
    final database = ref.watch(databaseProvider);

    try {
      final cached = await DailyRecommendCacheCoordinator.readCache(
        database: database,
        serverId: server.id,
        date: date,
      );
      if (_disposed ||
          currentGen != _generation ||
          _activeServerId != server.id) {
        return state.asData?.value ?? const <Song>[];
      }

      if (cached != null && cached.songsJson.isNotEmpty) {
        try {
          final decoded = jsonDecode(cached.songsJson);
          if (decoded is List) {
            final cachedSongs = <Song>[
              for (final entry in decoded)
                Song.fromJson(entry as Map<String, dynamic>),
            ];
            if (cachedSongs.isNotEmpty) {
              DailyRecommendCacheCoordinator.markBaseline(
                database: database,
                serverId: server.id,
                date: date,
              );
              return cachedSongs;
            }
          }
        } catch (_) {
          // Corrupted cache: fall through and refresh from the server.
        }
      }
    } catch (_) {
      // Database read error: fall through and refresh from server.
    }

    try {
      final songs = await client.getRandomSongs(size: 20);
      if (songs.isNotEmpty) {
        await DailyRecommendCacheCoordinator.upsert(
          database: database,
          serverId: server.id,
          date: date,
          generation: currentGen,
          songsJson: jsonEncode(
            songs.map((song) => song.toJson()).toList(growable: false),
          ),
        );
      }
      if (_disposed ||
          currentGen != _generation ||
          _activeServerId != server.id) {
        return state.asData?.value ?? const <Song>[];
      }
      return songs;
    } catch (_) {
      // Fallback: return empty list on build error
      return const <Song>[];
    }
  }

  Future<void> shuffle() async {
    if (_activeShuffleTicket != null) {
      return;
    }

    final server = ref.read(activeServerProvider);
    final client = ref.read(activeSubsonicClientProvider);
    final database = ref.read(databaseProvider);
    if (server == null || client == null) {
      return;
    }

    final ticket = ++_generation;
    _activeShuffleTicket = ticket;
    final targetServerId = server.id;
    final date = _formatTodayDate();

    try {
      final songs = await client.getRandomSongs(size: 20);

      if (songs.isEmpty) {
        return;
      }

      final currentSongs = state.asData?.value ?? const <Song>[];
      final currentFirstId = currentSongs.firstOrNull?.id;
      final adjusted = List<Song>.from(songs);

      if (currentFirstId != null && adjusted.isNotEmpty) {
        final differentIndices = <int>[];
        for (var i = 0; i < adjusted.length; i++) {
          if (adjusted[i].id != currentFirstId) {
            differentIndices.add(i);
          }
        }

        // If every song in the response is identical to current first song (e.g. [A, A]),
        // retain existing batch and do not overwrite cache.
        if (differentIndices.isEmpty) {
          return;
        }

        if (adjusted.first.id == currentFirstId) {
          final chosenIndex =
              differentIndices[_random.nextInt(differentIndices.length)];
          final chosenSong = adjusted.removeAt(chosenIndex);
          adjusted.insert(0, chosenSong);
        }
      }

      final isCurrentForUi =
          !_disposed &&
          ticket == _generation &&
          _activeServerId == targetServerId &&
          ref.read(activeServerProvider)?.id == targetServerId;

      if (isCurrentForUi) {
        state = AsyncData<List<Song>>(List<Song>.unmodifiable(adjusted));
      }

      await DailyRecommendCacheCoordinator.upsert(
        database: database,
        serverId: targetServerId,
        date: date,
        generation: ticket,
        songsJson: jsonEncode(
          adjusted.map((song) => song.toJson()).toList(growable: false),
        ),
      );
    } catch (_) {
      // Retain existing state without throwing
    } finally {
      if (_activeShuffleTicket == ticket) {
        _activeShuffleTicket = null;
      }
    }
  }
}

final dailyRecommendSongsProvider =
    AsyncNotifierProvider<DailyRecommendSongsNotifier, List<Song>>(
      DailyRecommendSongsNotifier.new,
    );

final songsListProvider = FutureProvider<List<Song>>((ref) {
  final client = ref.watch(activeSubsonicClientProvider);
  if (client == null) {
    return const <Song>[];
  }
  return client.getRandomSongs(size: 50);
});

/// Aggregates recent-play events into a most-frequently-played list. The
/// underlying `RecentPlays` stream already caps the history, so a plain Dart
/// aggregation here is sufficient (no SQL grouping needed). Songs are ordered
/// by play count, ties broken by the most recent play time.
final frequentSongsProvider = StreamProvider<List<Song>>((ref) {
  final server = ref.watch(activeServerProvider);
  final serverId = server?.id;
  final stream = ref
      .watch(databaseProvider)
      .watchRecentPlays(serverId: serverId, limit: 200);
  return stream.map((plays) {
    final latest = <String, RecentPlay>{};
    final counts = <String, int>{};
    for (final play in plays) {
      final id = play.songId;
      counts[id] = (counts[id] ?? 0) + 1;
      latest.putIfAbsent(id, () => play);
    }
    final entries = counts.entries.toList(growable: false);
    entries.sort((a, b) {
      final byCount = b.value.compareTo(a.value);
      if (byCount != 0) return byCount;
      final timeA = latest[a.key]!.playedAt;
      final timeB = latest[b.key]!.playedAt;
      return timeB.compareTo(timeA);
    });
    return <Song>[
      for (final entry in entries) songFromRecentPlay(latest[entry.key]!),
    ];
  });
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

/// Returns up to 4 representative cover-art URLs for a genre, used by the
/// genre grid's 2x2 cover preview. Only a small sample of songs is fetched.
final genreCoverArtsProvider = FutureProvider.family<List<String>, String>((
  ref,
  genre,
) async {
  final client = ref.watch(activeSubsonicClientProvider);
  if (client == null || genre.trim().isEmpty) {
    return const <String>[];
  }
  try {
    final songs = await client.getSongsByGenre(genre, count: 8);
    final covers = <String>{};
    for (final song in songs) {
      final coverArt = song.coverArt;
      if (coverArt != null && coverArt.isNotEmpty) {
        covers.add(client.coverArtUrl(coverArt, size: 300));
      }
    }
    return covers.take(4).toList(growable: false);
  } catch (_) {
    return const <String>[];
  }
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

/// Recent plays with the denormalized song metadata recorded at play time, so
/// the home history renders titles without per-song server lookups. This is a
/// live Drift stream: writes refresh the home automatically.
final recentPlaysProvider = StreamProvider<List<RecentPlay>>((ref) {
  final serverId = ref.watch(activeServerProvider)?.id;
  return ref
      .watch(databaseProvider)
      .watchRecentPlays(serverId: serverId, limit: 50);
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

/// Library statistics with honest availability: every field is null when the
/// Subsonic API does not expose a reliable value for it, and the home grid
/// renders those as "—". No fabricated fallback counts, no `songCount * 28MB`
/// style pseudo-precise estimates.
class LibraryStats {
  const LibraryStats({
    this.songCount,
    this.albumCount,
    this.artistCount,
    this.folderCount,
    this.totalSizeBytes,
    this.totalDurationSeconds,
  });

  final int? songCount;
  final int? albumCount;
  final int? artistCount;
  final int? folderCount;
  final int? totalSizeBytes;
  final int? totalDurationSeconds;
}

final libraryStatsProvider = FutureProvider<LibraryStats>((ref) async {
  final client = ref.watch(activeSubsonicClientProvider);
  if (client == null) {
    return const LibraryStats();
  }

  int? artistCount;
  int? albumCount;
  int? folderCount;

  try {
    final artists = await client.getArtists();
    artistCount = artists.length;
    // Each index entry carries the artist's real album count; only sum it
    // when the server actually reported the values.
    var albums = 0;
    var reported = false;
    for (final artist in artists) {
      if (artist.albumCount != null) {
        albums += artist.albumCount!;
        reported = true;
      }
    }
    if (reported) {
      albumCount = albums;
    }
  } catch (_) {}

  try {
    final folders = await client.getMusicFolders();
    folderCount = folders.length;
  } catch (_) {}

  // The Subsonic API has no cheap "total songs / total size / total duration"
  // endpoint, so those stay null (rendered as 暂不可用) instead of being
  // extrapolated from a small album sample.
  return LibraryStats(
    songCount: null,
    albumCount: albumCount,
    artistCount: artistCount,
    folderCount: folderCount,
    totalSizeBytes: null,
    totalDurationSeconds: null,
  );
});
