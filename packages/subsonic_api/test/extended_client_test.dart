import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:subsonic_api/subsonic_api.dart';
import 'package:test/test.dart';

class _EndpointAdapter implements HttpClientAdapter {
  _EndpointAdapter(this.responses);

  final Map<String, String> responses;
  RequestOptions? lastRequest;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastRequest = options;
    return ResponseBody.fromString(
      responses[options.uri.pathSegments.last] ?? _ok(),
      200,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>[Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

String _ok([Map<String, dynamic>? body]) {
  return jsonEncode(<String, dynamic>{
    'subsonic-response': <String, dynamic>{'status': 'ok', ...?body},
  });
}

SubsonicClient _client(
  Map<String, String> responses,
  void Function(_EndpointAdapter) capture,
) {
  final adapter = _EndpointAdapter(responses);
  capture(adapter);
  return SubsonicClient(
    baseUrl: 'https://music.example.test',
    username: 'demo',
    password: 'password',
    dio: Dio()..httpClientAdapter = adapter,
  );
}

void main() {
  test('parses artist details and nested albums', () async {
    late _EndpointAdapter adapter;
    final client = _client(<String, String>{
      'getArtist': _ok(<String, dynamic>{
        'artist': <String, dynamic>{
          'id': 'artist-1',
          'name': 'Sakura',
          'album': <Map<String, dynamic>>[
            <String, dynamic>{'id': 'album-1', 'name': 'Bloom'},
          ],
        },
      }),
    }, (value) => adapter = value);

    final artist = await client.getArtist('artist-1');

    expect(adapter.lastRequest?.uri.queryParameters['id'], 'artist-1');
    expect(artist.name, 'Sakura');
    expect(artist.albums.single.id, 'album-1');
  });

  test('parses discovery, folders, and playlist responses', () async {
    late _EndpointAdapter adapter;
    final client = _client(<String, String>{
      'getArtistInfo2': _ok(<String, dynamic>{
        'artistInfo2': <String, dynamic>{
          'artistId': 'artist-1',
          'biography': 'A short bio',
          'similarArtist': <Map<String, dynamic>>[
            <String, dynamic>{'id': 'artist-2', 'name': 'Rose'},
          ],
        },
      }),
      'getRandomSongs': _ok(<String, dynamic>{
        'randomSongs': <String, dynamic>{
          'song': <Map<String, dynamic>>[
            <String, dynamic>{'id': 'song-1', 'title': 'First'},
          ],
        },
      }),
      'getGenres': _ok(<String, dynamic>{
        'genres': <String, dynamic>{
          'genre': <Map<String, dynamic>>[
            <String, dynamic>{'value': 'J-Pop', 'songCount': 4},
          ],
        },
      }),
      'getSongsByGenre': _ok(<String, dynamic>{
        'songsByGenre': <String, dynamic>{
          'song': <Map<String, dynamic>>[
            <String, dynamic>{'id': 'song-2', 'title': 'Second'},
          ],
        },
      }),
      'getMusicFolders': _ok(<String, dynamic>{
        'musicFolders': <String, dynamic>{
          'musicFolder': <Map<String, dynamic>>[
            <String, dynamic>{'id': 1, 'name': 'Music'},
          ],
        },
      }),
      'getPlaylists': _ok(<String, dynamic>{
        'playlists': <String, dynamic>{
          'playlist': <Map<String, dynamic>>[
            <String, dynamic>{'id': 'playlist-1', 'name': 'Favorites'},
          ],
        },
      }),
      'getPlaylist': _ok(<String, dynamic>{
        'playlist': <String, dynamic>{
          'id': 'playlist-1',
          'name': 'Favorites',
          'entry': <Map<String, dynamic>>[
            <String, dynamic>{'id': 'song-3', 'title': 'Third'},
          ],
        },
      }),
    }, (value) => adapter = value);

    expect(
      (await client.getArtistInfo2('artist-1')).similarArtists.single.name,
      'Rose',
    );
    expect((await client.getRandomSongs()).single.id, 'song-1');
    expect((await client.getGenres()).single.name, 'J-Pop');
    expect((await client.getSongsByGenre('J-Pop')).single.id, 'song-2');
    expect((await client.getMusicFolders()).single.name, 'Music');
    expect((await client.getPlaylists()).single.name, 'Favorites');
    expect((await client.getPlaylist('playlist-1')).songs.single.id, 'song-3');
    expect(adapter.lastRequest?.uri.path, '/rest/getPlaylist');
  });

  test(
    'parses favorites and structured lyrics, with tolerant empty values',
    () async {
      final client = _client(<String, String>{
        'getStarred2': _ok(<String, dynamic>{
          'starred2': <String, dynamic>{
            'artist': <Map<String, dynamic>>[
              <String, dynamic>{'id': 'artist-1', 'name': 'Sakura'},
            ],
            'album': <Map<String, dynamic>>[
              <String, dynamic>{'id': 'album-1', 'name': 'Bloom'},
            ],
            'song': <Map<String, dynamic>>[
              <String, dynamic>{'id': 'song-1', 'title': 'First'},
            ],
          },
        }),
        'getLyricsBySongId': _ok(<String, dynamic>{
          'lyricsList': <String, dynamic>{
            'structuredLyrics': <Map<String, dynamic>>[
              <String, dynamic>{
                'lang': 'en',
                'synced': true,
                'line': <Map<String, dynamic>>[
                  <String, dynamic>{'start': 1200, 'value': 'Hello'},
                ],
              },
            ],
          },
        }),
        'getLyrics': _ok(<String, dynamic>{
          'lyrics': <String, dynamic>{'value': '[00:01.00] Hello'},
        }),
      }, (_) {});

      final starred = await client.getStarred2();
      final lyrics = await client.getLyricsBySongId('song-1');

      expect(starred.songs.single.title, 'First');
      expect(lyrics.single.lines.single.timeMs, 1200);
      expect(lyrics.single.lines.single.text, 'Hello');
      expect(await client.getLyrics(title: 'First'), '[00:01.00] Hello');
    },
  );

  test('requires a target for star operations', () async {
    final client = _client(<String, String>{}, (_) {});

    expect(() => client.star(), throwsArgumentError);
    expect(() => client.unstar(), throwsArgumentError);
  });
}
