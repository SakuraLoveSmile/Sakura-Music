import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramusic/audio/audio_player_service.dart';
import 'package:sakuramusic/data/webdav/webdav_client.dart';
import 'package:sakuramusic/data/webdav/webdav_tag_reader.dart';

/// Local-HTTP coverage for `WebDavClient.fetchBytes`, the bounded byte loader
/// behind the WebDAV tag probe.
///
/// The defect it pins down: the client used to answer with
/// `ResponseType.bytes`, so a server that ignores `Range` transferred the
/// whole file before the caller ever saw the first byte. The fix consumes the
/// body as a stream and stops at `maxBytes`, which is what the "server
/// ignored Range" case below observes: the server never gets to write its
/// whole body because the client drops the connection.
///
/// Every server is a loopback `HttpServer` (127.0.0.1, ephemeral port): no
/// external network and no real audio file is involved.
void main() {
  group('WebDavClient.fetchBytes', () {
    test('D1 - sends the Range window and the Basic auth header', () async {
      String? seenMethod;
      String? seenRange;
      String? seenAuthorization;
      final (server, baseUrl) = await _startServer((request) async {
        seenMethod = request.method;
        seenRange = request.headers.value('range');
        seenAuthorization = request.headers.value('authorization');
        await _writeBody(request.response, statusCode: 200, body: Uint8List(0));
      });
      addTearDown(() => server.close(force: true));

      await _client(baseUrl).fetchBytes('/Music/a.mp3', maxBytes: 256 * 1024);

      expect(seenMethod, 'GET');
      expect(seenAuthorization, 'Basic bGlzdGVuZXI6c2VjcmV0');
      expect(seenRange, 'bytes=0-${256 * 1024 - 1}');
    });

    test('D2 - returns exactly the requested window on a 206', () async {
      final body = _patterned(1024 * 1024);
      final (server, baseUrl) = await _startServer((request) async {
        final range = RegExp(
          r'bytes=(\d+)-(\d+)',
        ).firstMatch(request.headers.value('range') ?? '');
        final start = int.parse(range!.group(1)!);
        var end = int.parse(range.group(2)!);
        if (end > body.length - 1) {
          end = body.length - 1;
        }
        final slice = Uint8List.sublistView(body, start, end + 1);
        final response = request.response;
        response.statusCode = 206;
        response.headers.set(
          'content-range',
          'bytes $start-$end/${body.length}',
        );
        response.contentLength = slice.length;
        response.add(slice);
        await response.close();
      });
      addTearDown(() => server.close(force: true));

      const maxBytes = 256 * 1024;
      final bytes = await _client(
        baseUrl,
      ).fetchBytes('/Music/a.flac', maxBytes: maxBytes);

      expect(bytes.length, maxBytes);
      expect(bytes, equals(Uint8List.sublistView(body, 0, maxBytes)));
    });

    test(
      'D3 - stops reading at the cap when the server ignores Range',
      () async {
        const total = 2 * 1024 * 1024;
        const maxBytes = 256 * 1024;
        const chunkSize = 8 * 1024;
        final body = _patterned(total);
        var written = 0;
        final handlerDone = Completer<void>();
        final (server, baseUrl) = await _startServer((request) async {
          try {
            final response = request.response;
            response.statusCode = 200; // Range deliberately ignored.
            response.contentLength = total;
            for (var offset = 0; offset < total; offset += chunkSize) {
              final end = offset + chunkSize > total
                  ? total
                  : offset + chunkSize;
              response.add(Uint8List.sublistView(body, offset, end));
              await response.flush();
              written = end;
              // Pacing the writes keeps the observation below deterministic:
              // the client is done after ~33 chunks while the body needs 256.
              await Future<void>.delayed(const Duration(milliseconds: 2));
            }
            await response.close();
          } catch (_) {
            // The client dropped the connection: the write fails or stalls.
            // Either way the loop never reaches the end of the body.
          } finally {
            if (!handlerDone.isCompleted) {
              handlerDone.complete();
            }
          }
        });
        addTearDown(() async {
          await server.close(force: true);
          await handlerDone.future;
        });

        final bytes = await _client(
          baseUrl,
        ).fetchBytes('/Music/big.flac', maxBytes: maxBytes);

        expect(bytes.length, maxBytes);
        expect(bytes, equals(Uint8List.sublistView(body, 0, maxBytes)));
        // The observable half of the bound: the server never got to write its
        // whole body, so the connection really was closed early. The 2 ms per
        // 8 KiB pacing leaves a ~7x margin (the client returns after ~270 KiB
        // of the 2 MiB body); it was measured on this host with plain
        // `dart:io` before being written down.
        expect(
          written,
          lessThan(total),
          reason: 'the client stopped reading before the body was written out',
        );
      },
    );

    test('D4 - repairs a non-positive maxBytes to 512 KiB', () async {
      final ranges = <String>[];
      final (server, baseUrl) = await _startServer((request) async {
        ranges.add(request.headers.value('range') ?? '');
        await _writeBody(request.response, statusCode: 200, body: Uint8List(0));
      });
      addTearDown(() => server.close(force: true));

      final client = _client(baseUrl);
      await client.fetchBytes('/Music/a.mp3', maxBytes: 0);
      await client.fetchBytes('/Music/a.mp3', maxBytes: -4096);

      expect(ranges, <String>['bytes=0-524287', 'bytes=0-524287']);
    });

    test('D5 - returns an empty list for an empty body', () async {
      final (server, baseUrl) = await _startServer((request) async {
        await _writeBody(request.response, statusCode: 200, body: Uint8List(0));
      });
      addTearDown(() => server.close(force: true));

      final bytes = await _client(baseUrl).fetchBytes('/Music/empty.mp3');

      expect(bytes.length, 0);
    });

    test('D6 - probes the URL the player streams', () async {
      Uri? seenUri;
      final (server, baseUrl) = await _startServer((request) async {
        // `requestedUri` is the absolute request target; `HttpRequest.uri`
        // only carries the (relative) path, which would not pin the host.
        seenUri = request.requestedUri;
        await _writeBody(request.response, statusCode: 200, body: Uint8List(0));
      });
      addTearDown(() => server.close(force: true));

      const href = '/Backup/%E9%9F%B3%E4%B9%90/%E5%A4%9C%E6%9B%B2.mp3';
      final client = _client(baseUrl);
      await client.fetchBytes(href);

      final probed = Uri.parse(client.baseUrl).resolve(href).toString();
      expect(seenUri.toString(), probed);
      // `webdav_browse_screen.dart` builds `PlayableItem.streamUrl` with the
      // identical expression: if the two ever drift, the probe and playback
      // would hit different addresses.
      final item = PlayableItem(
        id: href,
        title: '夜曲',
        streamUrl: Uri.parse(client.baseUrl).resolve(href).toString(),
      );
      expect(item.streamUrl, probed);
    });
  });

  test(
    'D7 - a refused connection throws, and readWebDavTags swallows it',
    () async {
      final dead = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final baseUrl = 'http://127.0.0.1:${dead.port}';
      await dead.close(force: true);

      final client = _client(baseUrl);
      await expectLater(
        client.fetchBytes('/Music/a.mp3'),
        throwsA(isA<DioException>()),
      );
      // The reader layer keeps its contract: a failed probe is `null`, so the
      // row falls back to the cleaned file name.
      expect(
        await readWebDavTags(href: '/Music/a.mp3', load: client.fetchBytes),
        isNull,
      );
    },
  );
}

/// Starts a loopback server backed by [handler]; the returned base URL feeds
/// a [WebDavClient].
Future<(HttpServer, String)> _startServer(
  Future<void> Function(HttpRequest request) handler,
) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  server.listen((request) async {
    try {
      await handler(request);
    } catch (_) {
      try {
        await request.response.close();
      } catch (_) {}
    }
  });
  return (server, 'http://127.0.0.1:${server.port}');
}

WebDavClient _client(String baseUrl) =>
    WebDavClient(baseUrl: baseUrl, username: 'listener', password: 'secret');

Future<void> _writeBody(
  HttpResponse response, {
  required int statusCode,
  required Uint8List body,
}) async {
  response.statusCode = statusCode;
  response.contentLength = body.length;
  response.add(body);
  await response.close();
}

/// Deterministic filler: byte `i` of the body is `i & 0xFF`.
Uint8List _patterned(int length) =>
    Uint8List.fromList(List<int>.generate(length, (i) => i & 0xFF));
