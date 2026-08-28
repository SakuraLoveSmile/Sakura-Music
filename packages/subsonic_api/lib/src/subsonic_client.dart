import 'dart:convert';

import 'package:dio/dio.dart';

import 'models/album.dart';
import 'models/artist.dart';
import 'models/artist_info.dart';
import 'models/genre.dart';
import 'models/lyrics.dart';
import 'models/model_helpers.dart';
import 'models/music_folder.dart';
import 'models/playlist.dart';
import 'models/search_result.dart';
import 'models/song.dart';
import 'models/starred.dart';
import 'subsonic_auth.dart';
import 'subsonic_exception.dart';

/// A minimal Subsonic/Navidrome REST client.
class SubsonicClient {
  SubsonicClient({
    required String baseUrl,
    required this.username,
    required this.password,
    Dio? dio,
    SubsonicAuth? auth,
  }) : baseUri = _normalizeBaseUrl(baseUrl),
       dio = dio ?? Dio(),
       auth = auth ?? const SubsonicAuth();

  final Uri baseUri;
  final String username;
  final String password;
  final Dio dio;
  final SubsonicAuth auth;

  Future<void> ping() async {
    await _request('ping');
  }

  Future<List<Artist>> getArtists() async {
    final response = await _request('getArtists');
    final artists = <Artist>[];
    for (final indexValue in asList(asMap(response['artists'])?['index'])) {
      final index = asMap(indexValue);
      if (index == null) {
        continue;
      }
      final entries = asList(index['artist']).toList();
      if (entries.isEmpty && index.containsKey('id')) {
        entries.add(index);
      }
      artists.addAll(
        entries
            .map(asMap)
            .whereType<Map<String, dynamic>>()
            .map(Artist.fromJson),
      );
    }
    return List<Artist>.unmodifiable(artists);
  }

  Future<Artist> getArtist(String id) async {
    final response = await _request('getArtist', <String, Object?>{'id': id});
    final artist = asMap(response['artist']);
    if (artist == null) {
      throw const SubsonicException(0, 'The server returned no artist');
    }
    return Artist.fromJson(artist);
  }

  Future<ArtistInfo2> getArtistInfo2(String id) async {
    final response = await _request('getArtistInfo2', <String, Object?>{
      'id': id,
    });
    return ArtistInfo2.fromJson(asMap(response['artistInfo2']) ?? const {});
  }

  Future<List<Song>> getRandomSongs({int size = 10}) async {
    _validateCount(size, 'size');
    final response = await _request('getRandomSongs', <String, Object?>{
      'size': size,
    });
    return _songsFrom(asMap(response['randomSongs']));
  }

  Future<List<Genre>> getGenres() async {
    final response = await _request('getGenres');
    final container = asMap(response['genres']);
    return asList(container?['genre'])
        .map(asMap)
        .whereType<Map<String, dynamic>>()
        .map(Genre.fromJson)
        .toList(growable: false);
  }

  Future<List<Song>> getSongsByGenre(
    String genre, {
    int count = 50,
    int offset = 0,
  }) async {
    if (genre.trim().isEmpty) {
      throw ArgumentError.value(genre, 'genre', 'must not be empty');
    }
    _validateCount(count, 'count');
    if (offset < 0) {
      throw ArgumentError.value(offset, 'offset', 'must not be negative');
    }
    final response = await _request('getSongsByGenre', <String, Object?>{
      'genre': genre,
      'count': count,
      'offset': offset,
    });
    return _songsFrom(asMap(response['songsByGenre'] ?? response['songs']));
  }

  Future<List<MusicFolder>> getMusicFolders() async {
    final response = await _request('getMusicFolders');
    final container = asMap(response['musicFolders']);
    return asList(container?['musicFolder'])
        .map(asMap)
        .whereType<Map<String, dynamic>>()
        .map(MusicFolder.fromJson)
        .toList(growable: false);
  }

  Future<List<Album>> getAlbumList({
    String type = 'newest',
    int size = 50,
    int offset = 0,
  }) async {
    if (size < 1 || size > 500) {
      throw ArgumentError.value(size, 'size', 'must be between 1 and 500');
    }
    if (offset < 0) {
      throw ArgumentError.value(offset, 'offset', 'must not be negative');
    }

    final response = await _request('getAlbumList', <String, Object?>{
      'type': type,
      'size': size,
      'offset': offset,
    });
    final container = asMap(response['albumList2'] ?? response['albumList']);
    final albums = asList(container?['album'])
        .map(asMap)
        .whereType<Map<String, dynamic>>()
        .map(Album.fromJson)
        .toList(growable: false);
    return albums;
  }

  Future<Album> getAlbum(String id) async {
    final response = await _request('getAlbum', <String, Object?>{'id': id});
    final album = asMap(response['album']);
    if (album == null) {
      throw const SubsonicException(0, 'The server returned no album');
    }
    return Album.fromJson(album);
  }

  Future<SearchResult3> search3(String query) async {
    final response = await _request('search3', <String, Object?>{
      'query': query,
    });
    return SearchResult3.fromJson(asMap(response['searchResult3']) ?? const {});
  }

  Future<List<Playlist>> getPlaylists() async {
    final response = await _request('getPlaylists');
    final container = asMap(response['playlists']);
    return asList(container?['playlist'])
        .map(asMap)
        .whereType<Map<String, dynamic>>()
        .map(Playlist.fromJson)
        .toList(growable: false);
  }

  Future<Playlist> getPlaylist(String id) async {
    final response = await _request('getPlaylist', <String, Object?>{'id': id});
    final playlist = asMap(response['playlist']);
    if (playlist == null) {
      throw const SubsonicException(0, 'The server returned no playlist');
    }
    return Playlist.fromJson(playlist);
  }

  Future<Playlist> createPlaylist({
    String? playlistId,
    required String name,
    List<String>? songIds,
  }) async {
    final params = <String, Object?>{
      'name': name,
      'playlistId': ?playlistId,
      if (songIds != null && songIds.isNotEmpty) 'songId': songIds,
    };
    final response = await _request('createPlaylist', params);
    final playlist = asMap(response['playlist']);
    if (playlist != null) {
      return Playlist.fromJson(playlist);
    }
    return Playlist(id: playlistId ?? '', name: name, songCount: songIds?.length ?? 0);
  }

  Future<void> updatePlaylist({
    required String playlistId,
    String? name,
    String? comment,
    bool? isPublic,
    List<String>? songIdsToAdd,
    List<int>? songIndexesToRemove,
  }) async {
    final params = <String, Object?>{
      'playlistId': playlistId,
      'name': ?name,
      'comment': ?comment,
      'public': ?isPublic,
      if (songIdsToAdd != null && songIdsToAdd.isNotEmpty) 'songIdToAdd': songIdsToAdd,
      if (songIndexesToRemove != null && songIndexesToRemove.isNotEmpty)
        'songIndexToRemove': songIndexesToRemove,
    };
    await _request('updatePlaylist', params);
  }

  Future<void> deletePlaylist(String id) async {
    await _request('deletePlaylist', <String, Object?>{'id': id});
  }

  Future<void> star({String? id, String? albumId, String? artistId}) async {
    await _request(
      'star',
      _starParameters(id: id, albumId: albumId, artistId: artistId),
    );
  }

  Future<void> unstar({String? id, String? albumId, String? artistId}) async {
    await _request(
      'unstar',
      _starParameters(id: id, albumId: albumId, artistId: artistId),
    );
  }

  Future<Starred2> getStarred2() async {
    final response = await _request('getStarred2');
    return Starred2.fromJson(
      asMap(response['starred2'] ?? response['starred']) ?? const {},
    );
  }

  Future<List<StructuredLyrics>> getLyricsBySongId(String id) async {
    final response = await _request('getLyricsBySongId', <String, Object?>{
      'id': id,
    });
    final container = asMap(response['lyricsList'] ?? response['lyrics']);
    return asList(container?['structuredLyrics'] ?? container?['lyrics'])
        .map(asMap)
        .whereType<Map<String, dynamic>>()
        .map(StructuredLyrics.fromJson)
        .toList(growable: false);
  }

  /// Returns the legacy plain-text/LRC lyrics, or null when unavailable.
  Future<String?> getLyrics({String? artist, String? title}) async {
    final response = await _request('getLyrics', <String, Object?>{
      'artist': artist,
      'title': title,
    });
    final lyrics = asMap(response['lyrics']);
    if (lyrics != null) {
      return asString(lyrics['value'] ?? lyrics['lyrics']);
    }
    final value = response['lyrics'];
    return value is String ? value : null;
  }

  Future<void> scrobble(String id, {bool submission = true}) async {
    await _request('scrobble', <String, Object?>{
      'id': id,
      'submission': submission,
    });
  }

  /// Returns a signed stream URL; the audio bytes are fetched by the player.
  String streamUrl(String id, {int? maxBitRate, String? format}) {
    final parameters = <String, Object?>{'id': id};
    if (maxBitRate != null) {
      parameters['maxBitRate'] = maxBitRate;
    }
    if (format != null) {
      parameters['format'] = format;
    }
    return _restUri('stream', parameters).toString();
  }

  /// Returns a signed cover-art URL; the image widget fetches the bytes.
  String coverArtUrl(String id, {int? size}) {
    final parameters = <String, Object?>{'id': id};
    if (size != null) {
      parameters['size'] = size;
    }
    return _restUri('getCoverArt', parameters).toString();
  }

  Future<Map<String, dynamic>> _request(
    String endpoint, [
    Map<String, Object?> parameters = const <String, Object?>{},
  ]) async {
    try {
      final response = await dio.getUri(_restUri(endpoint, parameters));
      final root = _decodeRoot(response.data);
      final envelope = asMap(root['subsonic-response']) ?? root;
      final status = asString(envelope['status']);
      if (status != null && status != 'ok') {
        final error = asMap(envelope['error']);
        throw SubsonicException(
          asInt(error?['code']) ?? 0,
          asString(error?['message']) ?? 'Subsonic request failed',
        );
      }
      return envelope;
    } on SubsonicException {
      rethrow;
    } on DioException catch (error) {
      throw SubsonicException(
        0,
        error.message ?? 'Network request failed',
        cause: error,
      );
    } on FormatException catch (error) {
      throw SubsonicException(0, 'Invalid JSON response', cause: error);
    }
  }

  Map<String, dynamic> _decodeRoot(dynamic data) {
    final decoded = data is String ? jsonDecode(data) : data;
    final root = asMap(decoded);
    if (root == null) {
      throw const FormatException('Expected a JSON object');
    }
    return root;
  }

  Uri _restUri(String endpoint, Map<String, Object?> parameters) {
    final query = <String, dynamic>{
      ...auth.parameters(
        username: username,
        password: password,
        stableId: endpoint == 'stream' || endpoint == 'getCoverArt'
            ? parameters['id']?.toString()
            : null,
      ),
      for (final entry in parameters.entries)
        if (entry.value != null)
          entry.key: entry.value is Iterable
              ? (entry.value as Iterable).map((e) => e.toString()).toList()
              : entry.value.toString(),
    };
    return baseUri.replace(
      path: '${baseUri.path}/rest/$endpoint',
      queryParameters: query,
      fragment: '',
    );
  }

  List<Song> _songsFrom(Map<String, dynamic>? container) {
    return asList(container?['song'])
        .map(asMap)
        .whereType<Map<String, dynamic>>()
        .map(Song.fromJson)
        .toList(growable: false);
  }

  Map<String, Object?> _starParameters({
    String? id,
    String? albumId,
    String? artistId,
  }) {
    if (id == null && albumId == null && artistId == null) {
      throw ArgumentError(
        'At least one of id, albumId, or artistId is required',
      );
    }
    return <String, Object?>{
      'id': id,
      'albumId': albumId,
      'artistId': artistId,
    };
  }

  static void _validateCount(int value, String name) {
    if (value < 1 || value > 500) {
      throw ArgumentError.value(value, name, 'must be between 1 and 500');
    }
  }

  static Uri _normalizeBaseUrl(String raw) {
    final parsed = Uri.parse(raw.trim());
    if (parsed.scheme.isEmpty || parsed.host.isEmpty) {
      throw ArgumentError.value(raw, 'baseUrl', 'must be an absolute URL');
    }
    var path = parsed.path.replaceFirst(RegExp(r'/+$'), '');
    if (path.endsWith('/rest')) {
      path = path.substring(0, path.length - '/rest'.length);
    }
    return parsed.replace(path: path, query: null, fragment: null);
  }
}
