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
  if (!isAudioHref(href)) {
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
