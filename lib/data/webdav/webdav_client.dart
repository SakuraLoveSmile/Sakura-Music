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
/// Only the `PROPFIND` verb is used: `Depth: 0` for a connection test and
/// `Depth: 1` for a directory listing. Basic-auth credentials are attached
/// both here and to the audio backend (via `PlayableItem.headers`) so the
/// player can stream protected files.
class WebDavClient {
  WebDavClient({
    required this.baseUrl,
    required this.username,
    required this.password,
  }) : authHeader = 'Basic ${base64Encode(utf8.encode('$username:$password'))}';

  /// Collection the client is rooted at, as entered by the user.
  final String baseUrl;
  final String username;
  final String password;

  /// Authorization header shared with the audio backend.
  final String authHeader;

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

  /// Fetches at most [maxBytes] leading bytes of [href] (a `Range` request
  /// when the server honours it). Used for bounded tag probes.
  ///
  /// The body is consumed as a stream and abandoned as soon as the cap is
  /// reached, so a server that ignores `Range` still never transfers or
  /// buffers more than the window the caller asked for: the connection is
  /// dropped early instead of the whole file being read into memory.
  Future<Uint8List> fetchBytes(String href, {int maxBytes = 512 * 1024}) async {
    final limit = maxBytes <= 0 ? 512 * 1024 : maxBytes;
    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 30),
        responseType: ResponseType.stream,
      ),
    );
    final response = await dio.request<ResponseBody>(
      Uri.parse(baseUrl).resolve(href).toString(),
      options: Options(
        method: 'GET',
        headers: <String, String>{
          'Authorization': authHeader,
          'Range': 'bytes=0-${limit - 1}',
        },
      ),
    );
    final stream = response.data?.stream;
    if (stream == null) {
      return Uint8List(0);
    }
    // Leaving the `await for` loop cancels the subscription, which closes the
    // connection: the server stops sending once the cap is reached instead of
    // the whole body being drained into memory first.
    final builder = BytesBuilder();
    await for (final chunk in stream) {
      builder.add(chunk);
      if (builder.length >= limit) {
        break;
      }
    }
    final bytes = builder.takeBytes();
    // A single chunk can push the builder past the cap.
    return bytes.length > limit
        ? Uint8List.sublistView(bytes, 0, limit)
        : bytes;
  }
}
