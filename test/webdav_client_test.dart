import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramusic/audio/audio_player_service.dart';
import 'package:sakuramusic/data/webdav/webdav_client.dart';
import 'package:sakuramusic/data/webdav/webdav_tag_reader.dart';

/// HTTP-level coverage for the bounded tag probe in `WebDavClient.fetchBytes`.
///
/// These tests talk to a real `HttpServer` on the loopback interface (no fake
/// client and no injected `Dio`), because the property under test is a
/// transport property: a server that ignores `Range` must not be allowed to
/// push the whole file into memory. The decisive assertion is therefore made
/// on the *server* side — the number of bytes it managed to write before the
/// client dropped the connection — which is exactly what a whole-body
/// `ResponseType.bytes` implementation cannot satisfy.
///
/// The bodies are written in paced chunks so the client's abort is observed
/// while the transfer is still in flight; without pacing the whole body would
/// sit in the socket buffers and the abort would be invisible either way.

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
  /// Total size of the "large file" the ignoring server tries to push.
  const int hugeFileBytes = 8 * 1024 * 1024;

  /// Chunk size the paced servers write at a time.
  const int chunkBytes = 64 * 1024;

  /// Pause between two chunks: slow enough that the client's abort always
  /// lands before the server reaches the end of the body.
  const Duration chunkPace = Duration(milliseconds: 3);

  group('WebDavClient.fetchBytes', () {
    test('A1 - a server ignoring Range cannot push the whole file', () async {
      final server = await _LoopbackServer.start((request, counter) async {
        // Deliberately ignore the `Range` request: answer 200 with the
        // entire file, exactly like a server without range support.
        final response = request.response;
        response.statusCode = 200;
        response.headers.contentLength = hugeFileBytes;
        response.headers.contentType = ContentType.binary;
        final chunk = Uint8List(chunkBytes);
        try {
          while (counter.written < hugeFileBytes) {
            response.add(chunk);
            await response.flush();
            counter.written += chunkBytes;
            await Future<void>.delayed(chunkPace);
          }
          await response.close();
        } catch (_) {
          // The client tore the connection down mid-transfer.
        }
      });
      addTearDown(server.close);

      final client = _clientFor(server);
      final bytes = await client.fetchBytes('huge.flac');

      // Exactly the window, never more.
      expect(bytes.length, 512 * 1024);
      expect(server.requests, hasLength(1));
      expect(server.requests.single.rangeHeader, 'bytes=0-524287');
      expect(server.requests.single.authorizationHeader, 'Basic dXNlcjpwYXNz');
      expect(server.requests.single.path, '/huge.flac');
      expect(server.requests.single.method, 'GET');

      // The decisive observation: the server must be unable to finish. A
      // whole-body implementation would have read all 8 MiB, letting the
      // server write every chunk.
      final written = await server.waitUntilStalled(hugeFileBytes);
      expect(
        written,
        lessThan(hugeFileBytes),
        reason:
            'the client must drop the connection once its window is full '
            'instead of draining the rest of the file',
      );
      expect(
        written,
        lessThan(4 * 1024 * 1024),
        reason:
            'the body must be abandoned right after the ~512 KiB window, '
            'not merely truncated at the end',
      );
    });

    test(
      'A2 - a server honouring Range returns the requested prefix',
      () async {
        const int maxBytes = 4096;
        const int totalBytes = 3 * 1024 * 1024;

        final server = await _LoopbackServer.start((request, counter) async {
          final range = request.headers.value(HttpHeaders.rangeHeader) ?? '';
          final match = RegExp(r'^bytes=0-(\d+)$').firstMatch(range);
          // A request without a usable range is rejected, so the assertions
          // in the test body fail instead of the server quietly succeeding.
          final last = match == null ? -1 : int.parse(match.group(1)!);

          final response = request.response;
          if (last < 0) {
            response.statusCode = HttpStatus.badRequest;
            await response.close();
            return;
          }
          response.statusCode = HttpStatus.partialContent;
          response.headers.set(
            HttpHeaders.contentRangeHeader,
            'bytes 0-$last/$totalBytes',
          );
          response.headers.contentLength = last + 1;
          response.headers.contentType = ContentType.binary;
          final body = Uint8List(last + 1);
          for (var i = 0; i <= last; i++) {
            body[i] = _patternByte(i);
          }
          response.add(body);
          counter.written += body.length;
          await response.close();
        });
        addTearDown(server.close);

        final client = _clientFor(server);
        final bytes = await client.fetchBytes('song.flac', maxBytes: maxBytes);

        expect(bytes.length, maxBytes);
        expect(server.requests.single.rangeHeader, 'bytes=0-${maxBytes - 1}');
        expect(
          bytes,
          equals(
            Uint8List.fromList(<int>[
              for (var i = 0; i < maxBytes; i++) _patternByte(i),
            ]),
          ),
          reason: 'the returned bytes must be the requested prefix, in order',
        );
      },
    );

    test('A3 - maxBytes below the file length truncates exactly', () async {
      const int totalBytes = 1024 * 1024;
      const int maxBytes = 128 * 1024;

      final server = await _LoopbackServer.start((request, counter) async {
        // Ignores `Range` too, so only the client-side window bounds this.
        final response = request.response;
        response.statusCode = 200;
        response.headers.contentLength = totalBytes;
        final body = Uint8List(totalBytes);
        for (var i = 0; i < totalBytes; i++) {
          body[i] = _patternByte(i);
        }
        response.add(body);
        counter.written += body.length;
        await response.close();
      });
      addTearDown(server.close);

      final client = _clientFor(server);
      final bytes = await client.fetchBytes('album.flac', maxBytes: maxBytes);

      expect(bytes.length, maxBytes);
      expect(bytes.first, _patternByte(0));
      expect(bytes.last, _patternByte(maxBytes - 1));
    });

    test('A4 - maxBytes of zero or less falls back to 512 KiB', () async {
      const int totalBytes = 1024 * 1024;

      final server = await _LoopbackServer.start((request, counter) async {
        // Ignores `Range` too, so only the client-side window bounds this.
        final response = request.response;
        response.statusCode = 200;
        response.headers.contentLength = totalBytes;
        final body = Uint8List(totalBytes);
        response.add(body);
        counter.written += body.length;
        try {
          await response.close();
        } catch (_) {
          // Aborted by the client once its window was full.
        }
      });
      addTearDown(server.close);

      final client = _clientFor(server);
      final zero = await client.fetchBytes('a.flac', maxBytes: 0);
      final negative = await client.fetchBytes('a.flac', maxBytes: -1024);

      expect(zero.length, 512 * 1024);
      expect(negative.length, 512 * 1024);
      expect(
        server.requests.map((r) => r.rangeHeader),
        everyElement('bytes=0-524287'),
        reason: 'a non-positive window must fall back to the 512 KiB default',
      );
    });

    test(
      'A5 - a failing request still throws and still yields null tags',
      () async {
        final server = await _LoopbackServer.start((request, counter) async {
          final response = request.response;
          response.statusCode = HttpStatus.notFound;
          response.headers.contentType = ContentType.text;
          response.write('not found');
          await response.close();
        });
        addTearDown(server.close);

        final client = _clientFor(server);

        // The error is raised before the window fills, so it must reach the
        // caller instead of being silently turned into empty bytes.
        await expectLater(
          client.fetchBytes('missing.flac'),
          throwsA(isA<DioException>()),
        );

        // `readWebDavTags` keeps its `try/catch -> null` contract so the row
        // falls back to the cleaned file name.
        expect(
          await readWebDavTags(href: '/missing.flac', load: client.fetchBytes),
          isNull,
        );
      },
    );

    test(
      'A6 - an unreachable target throws instead of returning bytes',
      () async {
        // Bind and release a port so nothing is listening on it any more.
        final probe = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
        final closedPort = probe.port;
        await probe.close();

        final client = WebDavClient(
          baseUrl: 'http://127.0.0.1:$closedPort/',
          username: 'user',
          password: 'pass',
        );

        await expectLater(
          client.fetchBytes('gone.flac'),
          throwsA(isA<DioException>()),
        );
        expect(
          await readWebDavTags(href: '/gone.flac', load: client.fetchBytes),
          isNull,
        );
      },
    );
  });

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

/// Deterministic body pattern so a prefix can be asserted byte for byte.
int _patternByte(int index) => index % 251;

WebDavClient _clientFor(_LoopbackServer server) =>
    WebDavClient(baseUrl: server.baseUrl, username: 'user', password: 'pass');

/// One request as the loopback server saw it.
class _SeenRequest {
  _SeenRequest(
    this.method,
    this.path,
    this.rangeHeader,
    this.authorizationHeader,
  );

  final String method;
  final String path;
  final String? rangeHeader;
  final String? authorizationHeader;
}

/// A loopback server that records the requests it received and how many body
/// bytes it managed to write, so a test can prove the client stopped reading.
class _LoopbackServer {
  _LoopbackServer._(this._server, this.requests);

  static Future<_LoopbackServer> start(
    Future<void> Function(HttpRequest request, _ByteCounter counter) handler,
  ) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final requests = <_SeenRequest>[];
    final counter = _ByteCounter();
    unawaited(() async {
      await for (final request in server) {
        requests.add(
          _SeenRequest(
            request.method,
            request.uri.path,
            request.headers.value(HttpHeaders.rangeHeader),
            request.headers.value(HttpHeaders.authorizationHeader),
          ),
        );
        // Requests are served concurrently: an aborted transfer leaves its
        // handler parked mid-write and must not block the next request.
        unawaited(handler(request, counter));
      }
    }());
    return _LoopbackServer._(server, requests).._counter = counter;
  }

  final HttpServer _server;

  /// Requests observed so far, in arrival order.
  final List<_SeenRequest> requests;

  late _ByteCounter _counter;

  int get port => _server.port;

  String get baseUrl => 'http://${InternetAddress.loopbackIPv4.address}:$port/';

  int get written => _counter.written;

  Future<void> close() => _server.close(force: true);

  /// Returns once the server either pushed [total] bytes (a client that read
  /// the whole body) or stopped making progress for several ticks (a client
  /// that dropped the connection).
  Future<int> waitUntilStalled(int total) async {
    var last = -1;
    var idleTicks = 0;
    while (written < total && idleTicks < 3) {
      await Future<void>.delayed(const Duration(milliseconds: 150));
      if (written == last) {
        idleTicks++;
      } else {
        idleTicks = 0;
        last = written;
      }
    }
    return written;
  }
}

/// Mutable counter shared with the server handler, which runs concurrently
/// with the test body.
class _ByteCounter {
  int written = 0;
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
