import 'dart:typed_data';

import 'webdav_display.dart';
import 'webdav_tags.dart';

/// Upper bound for one tag probe: tag blocks live in the file head.
const int kWebDavTagProbeBytes = 512 * 1024;

/// Bounded byte loader: fetches at most [maxBytes] leading bytes of [href].
/// `WebDavClient.fetchBytes` matches this shape.
typedef WebDavByteLoader =
    Future<Uint8List> Function(String href, {int maxBytes});

/// Reads tags for one WebDAV audio file. Returns `null` when the name is not
/// an audio file, when the fetch fails, or when no usable tag was parsed, so
/// callers can fall back to the cleaned file name without blocking the list.
Future<AudioTags?> readWebDavTags({
  required String href,
  required WebDavByteLoader load,
  int maxBytes = kWebDavTagProbeBytes,
}) async {
  if (!isAudioFileName(_fileNameOf(href))) {
    return null;
  }
  final limit = maxBytes <= 0 ? kWebDavTagProbeBytes : maxBytes;
  try {
    final bytes = await load(href, maxBytes: limit);
    if (bytes.isEmpty) {
      return null;
    }
    return parseAudioTags(bytes);
  } catch (_) {
    return null;
  }
}

/// Last path segment of [href], percent-decoded when possible. Query strings
/// and fragments are not part of the file name.
String _fileNameOf(String href) {
  var path = href;
  final query = path.indexOf('?');
  if (query >= 0) {
    path = path.substring(0, query);
  }
  final fragment = path.indexOf('#');
  if (fragment >= 0) {
    path = path.substring(0, fragment);
  }
  path = path.replaceAll(RegExp(r'/+$'), '');
  final slash = path.lastIndexOf('/');
  final segment = slash >= 0 ? path.substring(slash + 1) : path;
  if (segment.isEmpty) {
    return path;
  }
  try {
    return Uri.decodeComponent(segment);
  } catch (_) {
    return segment;
  }
}
