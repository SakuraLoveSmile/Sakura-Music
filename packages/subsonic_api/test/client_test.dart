import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:subsonic_api/subsonic_api.dart';
import 'package:test/test.dart';

class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.body);

  final String body;
  RequestOptions? lastRequest;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastRequest = options;
    return ResponseBody.fromString(
      body,
      200,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>[Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Dio _dioFor(String payload, _FakeAdapter Function(_FakeAdapter) capture) {
  final adapter = _FakeAdapter(payload);
  capture(adapter);
  return Dio()..httpClientAdapter = adapter;
}

void main() {
  test('ping succeeds for an ok response', () async {
    late _FakeAdapter adapter;
    final dio = _dioFor(
      jsonEncode(<String, dynamic>{
        'subsonic-response': <String, dynamic>{
          'status': 'ok',
          'version': '1.16.1',
        },
      }),
      (value) => adapter = value,
    );
    final client = SubsonicClient(
      baseUrl: 'https://music.example.test',
      username: 'demo',
      password: 'password',
      dio: dio,
    );

    await client.ping();

    expect(adapter.lastRequest?.uri.path, '/rest/ping');
  });

  test('parses a paginated album list', () async {
    late _FakeAdapter adapter;
    final dio = _dioFor(
      jsonEncode(<String, dynamic>{
        'subsonic-response': <String, dynamic>{
          'status': 'ok',
          'albumList': <String, dynamic>{
            'album': <Map<String, dynamic>>[
              <String, dynamic>{
                'id': 'a1',
                'name': 'First album',
                'artist': 'An Artist',
                'songCount': 2,
              },
              <String, dynamic>{'id': 'a2', 'name': 'Second album'},
            ],
          },
        },
      }),
      (value) => adapter = value,
    );
    final client = SubsonicClient(
      baseUrl: 'https://music.example.test',
      username: 'demo',
      password: 'password',
      dio: dio,
    );

    final albums = await client.getAlbumList(size: 2, offset: 4);

    expect(adapter.lastRequest?.uri.path, '/rest/getAlbumList');
    expect(albums.map((album) => album.id), <String>['a1', 'a2']);
  });

  test('maps authentication and server errors to SubsonicException', () async {
    for (final code in <int>[40, 70]) {
      final dio = Dio()
        ..httpClientAdapter = _FakeAdapter(
          jsonEncode(<String, dynamic>{
            'subsonic-response': <String, dynamic>{
              'status': 'failed',
              'error': <String, dynamic>{
                'code': code,
                'message': 'error $code',
              },
            },
          }),
        );
      final client = SubsonicClient(
        baseUrl: 'https://music.example.test',
        username: 'demo',
        password: 'password',
        dio: dio,
      );

      expect(
        () => client.ping(),
        throwsA(
          isA<SubsonicException>().having((error) => error.code, 'code', code),
        ),
      );
    }
  });

  test('builds signed stream and cover-art URLs', () {
    final client = SubsonicClient(
      baseUrl: 'https://music.example.test/music/rest/',
      username: 'demo',
      password: 'password',
    );

    final stream = Uri.parse(client.streamUrl('song-1', maxBitRate: 320));
    final cover = Uri.parse(client.coverArtUrl('cover-1', size: 512));

    expect(stream.path, '/music/rest/stream');
    expect(stream.queryParameters['id'], 'song-1');
    expect(stream.queryParameters['maxBitRate'], '320');
    expect(cover.path, '/music/rest/getCoverArt');
    expect(cover.queryParameters['size'], '512');
    expect(
      stream.queryParameters.keys,
      containsAll(<String>['u', 't', 's', 'v', 'c', 'f']),
    );
    expect(
      stream.queryParameters['t'],
      SubsonicAuth.tokenFor(
        password: 'password',
        salt: stream.queryParameters['s']!,
      ),
    );
  });
}
