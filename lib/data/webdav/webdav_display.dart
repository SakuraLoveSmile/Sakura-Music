/// Pure display helpers for WebDAV rows.
///
/// Deliberately free of Flutter imports so the functions can be exercised from
/// plain Dart.
library;

/// File extensions (without the dot) that are treated as audio.
const Set<String> _audioExtensions = <String>{
  'mp3',
  'flac',
  'm4a',
  'aac',
  'ogg',
  'oga',
  'opus',
  'wav',
  'wma',
  'ape',
  'alac',
  'aiff',
  'aif',
  'wv',
  'dsf',
  'dff',
};

/// Matches a leading track number: `01 `, `01. `, `01 - `, `#12 `,
/// `Track 03 - ` (case-insensitive).
final RegExp _trackPrefix = RegExp(
  r'^\s*(?:#|track\s+)?\d+\s*[-.]?\s+',
  caseSensitive: false,
);

final RegExp _whitespace = RegExp(r'\s+');

/// Human-readable label for a percent-encoded WebDAV path: `%E9%9F%B3%E4%B9%90`
/// becomes the decoded text. Invalid escapes are returned unchanged. The root
/// (empty) path renders as `/`.
String webdavPathLabel(String path) {
  if (path.isEmpty) {
    return '/';
  }
  try {
    return Uri.decodeComponent(path);
  } catch (_) {
    return path;
  }
}

/// Title shown for one audio file when no tag title is available: drops the
/// file extension and a leading track number (`01 `, `01. `, `01 - `, `#12 `,
/// `Track 03 - `), collapses runs of whitespace and trims. When nothing is
/// left, the extension-stripped original name is returned instead.
String cleanTrackTitle(String fileName) {
  final stripped = _stripExtension(fileName);
  // The leading track number is dropped whenever the separator rule matches
  // (`01 `, `01. `, `01 - `, `#12 `, `Track 03 - `), extension or not, so a
  // name that only differs by its container still cleans up the same way.
  final name = _collapse(
    _collapse(stripped).replaceFirst(_trackPrefix, ''),
  ).trim();
  if (name.isNotEmpty) {
    return name;
  }
  // Nothing but a track marker was left (`01 - .mp3`): fall back to the
  // extension-stripped original so the row never renders an empty title.
  final fallback = _collapse(stripped).trim();
  if (fallback.isNotEmpty) {
    return fallback;
  }
  return fileName;
}

/// True when [name] looks like an audio file (mp3/flac/m4a/aac/ogg/oga/opus/
/// wav/wma/ape/alac/aiff/aif/wv/dsf/dff, case-insensitive).
bool isAudioFileName(String name) {
  final extension = _extensionOf(name);
  return extension != null && _audioExtensions.contains(extension);
}

/// Extension of [name] without its leading dot, lower-cased, or `null` when
/// there is none. A dot without any suffix (`song.`) is not an extension.
String? _extensionOf(String name) {
  final dot = name.lastIndexOf('.');
  if (dot < 0 || dot == name.length - 1) {
    return null;
  }
  return name.substring(dot + 1).toLowerCase();
}

/// Drops the extension of [fileName]. Only the last dot counts and the suffix
/// must be free of whitespace, so `01. Hello` keeps its name untouched while
/// `01. Hello.mp3` loses `.mp3`.
String _stripExtension(String fileName) {
  final dot = fileName.lastIndexOf('.');
  if (dot < 0 || dot == fileName.length - 1) {
    return fileName;
  }
  final suffix = fileName.substring(dot + 1);
  if (_whitespace.hasMatch(suffix)) {
    return fileName;
  }
  return fileName.substring(0, dot);
}

String _collapse(String value) => value.replaceAll(_whitespace, ' ');
