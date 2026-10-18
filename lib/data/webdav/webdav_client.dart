import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:xml/xml.dart';

/// A single entry returned by a WebDAV `PROPFIND` listing.
class WebDavEntry {
  const WebDavEntry({
    required this.href,
    required this.name,
    required this.isDirectory,
  });

  /// Percent-encoded path as returned by the server.
  final String href;

  /// Human-readable file or folder name.
  final String name;

  /// True when the entry is a collection (directory).
  final bool isDirectory;
}

/// Minimal WebDAV client used for directory-style music sources.
///
/// `PROPFIND` drives browsing (`Depth: 0` for a connection test, `Depth: 1`
/// for a directory listing) and a ranged `GET` feeds bounded tag probes.
/// Basic-auth credentials are attached both here and to the audio backend
/// (via `PlayableItem.headers`) so the player can stream protected files.
class WebDavClient {
  WebDavClient({
    required this.baseUrl,
    required this.username,
    required this.password,
    Dio? dio,
  }) : _dio = dio,
       authHeader = 'Basic ${base64Encode(utf8.encode('$username:$password'))}';

  /// Collection the client is rooted at, as entered by the user.
  final String baseUrl;
  final String username;
  final String password;

  /// Authorization header shared with the audio backend.
  final String authHeader;

  /// Transport override. `null` builds a fresh [Dio] per call with the
  /// defaults below; tests may inject one.
  final Dio? _dio;

  Map<String, String> _headers({String depth = '0'}) => <String, String>{
    'Authorization': authHeader,
    'Depth': depth,
  };

  /// Returns true when the server answers a `PROPFIND` at the root.
  Future<bool> testConnection() async {
    try {
      final dio = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 20),
          responseType: ResponseType.plain,
        ),
      );
      final response = await dio.request<String>(
        baseUrl,
        options: Options(method: 'PROPFIND', headers: _headers()),
        data:
            '<?xml version="1.0"?>'
            '<a:propfind xmlns:a="DAV:"><a:prop><a:resourcetype/></a:prop></a:propfind>',
      );
      return response.statusCode == 207 || response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Lists [path] (a `/`-delimited collection path). Folders come first,
  /// then files, both alphabetically. The listing's own row is skipped.
  Future<List<WebDavEntry>> list(String path) async {
    final normalized = path.startsWith('/') ? path : '/$path';
    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 30),
        responseType: ResponseType.plain,
      ),
    );
    final response = await dio.request<String>(
      '${baseUrl.replaceAll(RegExp(r'/+$'), '')}$normalized',
      options: Options(
        method: 'PROPFIND',
        headers: _headers(depth: '1'),
      ),
      data:
          '<?xml version="1.0"?>'
          '<a:propfind xmlns:a="DAV:"><a:prop>'
          '<a:resourcetype/><a:displayname/>'
          '</a:prop></a:propfind>',
    );
    final body = response.data ?? '';
    final document = XmlDocument.parse(body);

    final entries = <WebDavEntry>[];
    final selfHref = _normalizeHref(normalized);
    for (final responseEl in _elementsByName(
      document.rootElement,
      'response',
    )) {
      final href = _firstText(responseEl, 'href');
      if (href == null || href.isEmpty) {
        continue;
      }
      final isDirectory = _elementsByName(responseEl, 'collection').isNotEmpty;
      final displayname = _firstText(responseEl, 'displayname');
      if (_normalizeHref(href) == selfHref ||
          _normalizeHref(href) ==
              _normalizeHref('$normalized${isDirectory ? '/' : ''}')) {
        continue;
      }
      String name = displayname?.trim() ?? '';
      if (name.isEmpty) {
        final segments = Uri.parse(
          href,
        ).pathSegments.where((s) => s.isNotEmpty).toList();
        name = segments.isEmpty ? href : Uri.decodeComponent(segments.last);
      }
      entries.add(
        WebDavEntry(href: href, name: name, isDirectory: isDirectory),
      );
    }
    entries.sort((a, b) {
      if (a.isDirectory != b.isDirectory) {
        return a.isDirectory ? -1 : 1;
      }
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return entries;
  }

  /// Resolves [href] against [baseUrl] and strips trailing slashes so rows
  /// can be compared regardless of encoding differences.
  String _normalizeHref(String href) => Uri.parse(
    baseUrl,
  ).resolve(href).toString().replaceAll(RegExp(r'/+$'), '');

  String? _firstText(XmlElement parent, String local) {
    for (final node in _elementsByName(parent, local)) {
      final text = node.innerText.trim();
      if (text.isNotEmpty) {
        return text;
      }
    }
    return null;
  }

  /// Namespace-agnostic descendant lookup: WebDAV servers freely choose
  /// prefixes (`d:`, `D:`, `a:` or none).
  List<XmlElement> _elementsByName(XmlElement root, String local) {
    final result = <XmlElement>[];
    void visit(XmlElement node) {
      if (node.name.local == local) {
        result.add(node);
      }
      for (final child in node.childElements) {
        visit(child);
      }
    }

    visit(root);
    return result;
  }

  /// Fetches at most [maxBytes] leading bytes of [href] for a tag probe.
  ///
  /// The body is streamed rather than collected. A `Range` request is sent
  /// first, and a server that ignores it and answers `200` with the whole
  /// file is still safe: only the first [maxBytes] bytes are ever held in
  /// memory, and reading stops — cancelling the transfer — as soon as that
  /// window is full, so a large audio file is never downloaded in full.
  ///
  /// Network and HTTP failures raised *before* the window fills propagate to
  /// the caller; an error caused by our own cancellation does not, and the
  /// bytes collected so far are returned. The result is never longer than the
  /// window.
  Future<Uint8List> fetchBytes(String href, {int maxBytes = 512 * 1024}) async {
    final limit = maxBytes <= 0 ? 512 * 1024 : maxBytes;
    final dio =
        _dio ??
        Dio(
          BaseOptions(
            connectTimeout: const Duration(seconds: 10),
            receiveTimeout: const Duration(seconds: 30),
            responseType: ResponseType.stream,
          ),
        );
    final cancelToken = CancelToken();
    final response = await dio.request<ResponseBody>(
      Uri.parse(baseUrl).resolve(href).toString(),
      options: Options(
        method: 'GET',
        responseType: ResponseType.stream,
        headers: <String, String>{
          'Authorization': authHeader,
          'Range': 'bytes=0-${limit - 1}',
        },
      ),
      cancelToken: cancelToken,
    );
    final body = response.data;
    if (body == null) {
      return Uint8List(0);
    }

    final builder = BytesBuilder(copy: false);
    final finished = Completer<void>();
    // Flipped synchronously the moment the window fills, so the teardown
    // error Dio reports for an aborted transfer is never mistaken for a real
    // network failure.
    var aborted = false;
    late StreamSubscription<Uint8List> subscription;
    subscription = body.stream.listen(
      (chunk) {
        if (aborted) {
          return;
        }
        final remaining = limit - builder.length;
        if (remaining <= 0) {
          return;
        }
        if (chunk.length >= remaining) {
          builder.add(Uint8List.sublistView(chunk, 0, remaining));
          aborted = true;
          // Stop reading and drop the connection instead of draining the
          // rest of the file. Returning only after the cancellation settled
          // means no probe leaves a request running in the background.
          subscription.cancel().whenComplete(() {
            cancelToken.cancel('tag probe window full');
            if (!finished.isCompleted) {
              finished.complete();
            }
          });
          return;
        }
        builder.add(chunk);
      },
      onError: (Object error, StackTrace stackTrace) {
        if (aborted) {
          // Raised by our own cancellation: keep what was read.
          if (!finished.isCompleted) {
            finished.complete();
          }
          return;
        }
        if (!finished.isCompleted) {
          finished.completeError(error, stackTrace);
        }
      },
      onDone: () {
        if (!finished.isCompleted) {
          finished.complete();
        }
      },
      cancelOnError: true,
    );

    try {
      await finished.future;
    } on DioException catch (error) {
      if (!aborted && !CancelToken.isCancel(error)) {
        rethrow;
      }
    } on StateError {
      // Tearing down an aborted transfer can surface a late state error; the
      // bytes read before the abort are still valid.
      if (!aborted) {
        rethrow;
      }
    }
    return builder.takeBytes();
  }
}
