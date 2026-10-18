/// Zero-dependency audio tag probing.
///
/// Only SDK libraries are used so the parser can run from plain Dart, and every
/// entry point swallows malformed input instead of throwing: the tag probe sits
/// on a list-rendering path where a bad file must never break the UI.
library;

import 'dart:convert';
import 'dart:typed_data';

/// Text metadata parsed from an audio container's tag block.
class AudioTags {
  const AudioTags({this.title, this.artist, this.album});

  final String? title;
  final String? artist;
  final String? album;

  bool get isEmpty => _isBlank(title) && _isBlank(artist) && _isBlank(album);

  bool get isNotEmpty => !isEmpty;

  @override
  String toString() =>
      'AudioTags(title: $title, artist: $artist, album: $album)';
}

bool _isBlank(String? value) => value == null || value.trim().isEmpty;

const List<int> _id3Signature = <int>[0x49, 0x44, 0x33]; // 'ID3'
const List<int> _flacSignature = <int>[0x66, 0x4C, 0x61, 0x43]; // 'fLaC'
const List<int> _oggSignature = <int>[0x4F, 0x67, 0x67, 0x53]; // 'OggS'
const List<int> _vorbisCommentSignature = <int>[
  0x03,
  0x76, // v
  0x6F, // o
  0x72, // r
  0x62, // b
  0x69, // i
  0x73, // s
];

/// Upper bound for comment entries, so a malformed count cannot spin forever.
const int _maxCommentEntries = 4096;

/// Best-effort tag probe over the leading bytes of an audio file. Supports
/// ID3v2 (`.mp3`), Ogg Vorbis comments, FLAC `VORBIS_COMMENT` and MP4 `ilst`
/// atoms. Returns `null` when no supported tag block is found, when it holds
/// no title/artist/album, or when the bytes are malformed. Never throws.
AudioTags? parseAudioTags(Uint8List bytes) {
  try {
    if (bytes.length < 4) {
      return null;
    }
    AudioTags? tags;
    if (_startsWith(bytes, _flacSignature)) {
      tags = _parseFlac(bytes);
    } else if (_startsWith(bytes, _id3Signature)) {
      tags = _parseId3v2(bytes);
    } else if (_startsWith(bytes, _oggSignature)) {
      tags = _parseOggVorbis(bytes);
    } else {
      tags = _parseMp4(bytes);
    }
    if (tags == null || tags.isEmpty) {
      return null;
    }
    return tags;
  } catch (_) {
    return null;
  }
}

// ---------------------------------------------------------------------------
// ID3v2
// ---------------------------------------------------------------------------

/// Parses an ID3v2.3/v2.4 tag block at the head of [bytes].
AudioTags? _parseId3v2(Uint8List bytes) {
  if (bytes.length < 10) {
    return null;
  }
  final major = bytes[3];
  final flags = bytes[5];
  var offset = 10;
  if ((flags & 0x40) != 0) {
    if (offset + 4 > bytes.length) {
      return null;
    }
    // v2.4 stores a syncsafe size that includes its own four bytes; v2.3
    // stores a plain 32-bit size that excludes the size field, so the whole
    // extended header is `size + 4` bytes long.
    final extendedSize = major >= 4
        ? _syncSafe(bytes, offset)
        : _u32(bytes, offset) + 4;
    offset += extendedSize;
  }
  var end = 10 + _syncSafe(bytes, 6);
  if (end > bytes.length) {
    end = bytes.length;
  }
  if (offset < 10) {
    offset = 10;
  }

  String? title;
  String? artist;
  String? album;
  while (offset + 10 <= end) {
    final id = String.fromCharCodes(bytes, offset, offset + 4);
    if (!_isFrameId(id)) {
      break;
    }
    final size = major >= 4
        ? _syncSafe(bytes, offset + 4)
        : _u32(bytes, offset + 4);
    final frameStart = offset + 10;
    final frameEnd = frameStart + size;
    if (size <= 0 || frameEnd > end) {
      break;
    }
    if (id == 'TIT2' || id == 'TPE1' || id == 'TALB') {
      final text = _decodeId3Text(bytes, frameStart, frameEnd);
      if (text != null && text.isNotEmpty) {
        switch (id) {
          case 'TIT2':
            title ??= text;
          case 'TPE1':
            artist ??= text;
          case 'TALB':
            album ??= text;
        }
      }
    }
    offset = frameEnd;
    if (title != null && artist != null && album != null) {
      break;
    }
  }
  return AudioTags(title: title, artist: artist, album: album);
}

/// True for a plausible four-character frame identifier (`A`-`Z`, `0`-`9`).
bool _isFrameId(String id) {
  if (id.length != 4) {
    return false;
  }
  for (final code in id.codeUnits) {
    final isUpper = code >= 0x41 && code <= 0x5A;
    final isDigit = code >= 0x30 && code <= 0x39;
    if (!isUpper && !isDigit) {
      return false;
    }
  }
  return true;
}

/// Decodes an ID3v2 text frame payload (`[encoding][text]`).
String? _decodeId3Text(Uint8List bytes, int start, int end) {
  if (start >= end) {
    return null;
  }
  final encoding = bytes[start];
  return _decodeWithEncoding(bytes, start + 1, end, encoding);
}

/// Decodes [start]..[end] with an ID3v2 text encoding byte (0 = latin1,
/// 1 = UTF-16 with BOM, 2 = UTF-16BE, 3 = UTF-8).
String? _decodeWithEncoding(Uint8List bytes, int start, int end, int encoding) {
  if (start >= end) {
    return null;
  }
  final String decoded;
  switch (encoding) {
    case 0:
      decoded = latin1.decode(bytes.sublist(start, end));
    case 1:
      decoded = _decodeUtf16(bytes, start, end);
    case 2:
      decoded = _decodeUtf16(bytes, start, end);
    default:
      decoded = utf8.decode(bytes.sublist(start, end), allowMalformed: true);
  }
  return _cleanText(decoded);
}

/// Decodes UTF-16 between [start] and [end]. A BOM selects the byte order;
/// without one, big-endian is assumed. Trailing zero pairs are dropped so
/// framing padding does not leak into the value.
String _decodeUtf16(Uint8List bytes, int start, int end) {
  var s = start;
  var e = end;
  var littleEndian = false;
  if (e - s >= 2) {
    final b0 = bytes[s];
    final b1 = bytes[s + 1];
    if (b0 == 0xFF && b1 == 0xFE) {
      littleEndian = true;
      s += 2;
    } else if (b0 == 0xFE && b1 == 0xFF) {
      s += 2;
    }
  }
  while (e - s >= 2 && bytes[e - 2] == 0 && bytes[e - 1] == 0) {
    e -= 2;
  }
  final units = <int>[];
  for (var i = s; i + 1 < e; i += 2) {
    units.add(
      littleEndian
          ? bytes[i] | (bytes[i + 1] << 8)
          : (bytes[i] << 8) | bytes[i + 1],
    );
  }
  return String.fromCharCodes(units);
}

String? _cleanText(String value) {
  var text = value.replaceAll('\u0000', '').trim();
  if (text.isEmpty) {
    return null;
  }
  return text;
}

// ---------------------------------------------------------------------------
// Vorbis comments (Ogg and FLAC)
// ---------------------------------------------------------------------------

/// Finds the `\x03vorbis` packet in an Ogg stream and reads its comment block.
AudioTags? _parseOggVorbis(Uint8List bytes) {
  final index = _indexOf(bytes, _vorbisCommentSignature, _oggSignature.length);
  if (index < 0) {
    return null;
  }
  return _parseVorbisComment(
    bytes,
    index + _vorbisCommentSignature.length,
    bytes.length,
  );
}

/// Walks the FLAC metadata block chain and reads the `VORBIS_COMMENT` block.
AudioTags? _parseFlac(Uint8List bytes) {
  var offset = _flacSignature.length;
  while (offset + 4 <= bytes.length) {
    final header = bytes[offset];
    final isLast = (header & 0x80) != 0;
    final type = header & 0x7F;
    final length =
        (bytes[offset + 1] << 16) |
        (bytes[offset + 2] << 8) |
        bytes[offset + 3];
    final blockStart = offset + 4;
    final blockEnd = blockStart + length;
    if (blockEnd > bytes.length) {
      // Block runs past the probe window: nothing usable left to parse.
      return null;
    }
    if (type == 4) {
      final tags = _parseVorbisComment(bytes, blockStart, blockEnd);
      if (tags != null && tags.isNotEmpty) {
        return tags;
      }
    }
    if (isLast) {
      break;
    }
    offset = blockEnd;
  }
  return null;
}

/// Reads a Vorbis comment block: `vendorLength u32le`, vendor, `count u32le`,
/// then `length u32le + 'KEY=value' UTF-8` per entry.
AudioTags? _parseVorbisComment(Uint8List bytes, int start, int end) {
  var offset = start;
  if (offset + 4 > end) {
    return null;
  }
  final vendorLength = _u32le(bytes, offset);
  offset += 4;
  if (vendorLength <= 0 || offset + vendorLength > end) {
    return null;
  }
  offset += vendorLength;
  if (offset + 4 > end) {
    return null;
  }
  final count = _u32le(bytes, offset);
  offset += 4;
  if (count < 0 || count > _maxCommentEntries) {
    return null;
  }

  String? title;
  String? artist;
  String? album;
  for (var i = 0; i < count; i++) {
    if (offset + 4 > end) {
      break;
    }
    final length = _u32le(bytes, offset);
    offset += 4;
    if (length < 0 || offset + length > end) {
      break;
    }
    final entry = utf8.decode(
      bytes.sublist(offset, offset + length),
      allowMalformed: true,
    );
    offset += length;
    final equals = entry.indexOf('=');
    if (equals <= 0) {
      continue;
    }
    final key = entry.substring(0, equals).trim().toUpperCase();
    final value = entry.substring(equals + 1).trim();
    if (value.isEmpty) {
      continue;
    }
    switch (key) {
      case 'TITLE':
        title ??= value;
      case 'ARTIST':
        artist ??= value;
      case 'ALBUM':
        album ??= value;
    }
  }
  return AudioTags(title: title, artist: artist, album: album);
}

// ---------------------------------------------------------------------------
// MP4 atoms
// ---------------------------------------------------------------------------

const String _mp4TitleKey = '\u00A9nam';
const String _mp4ArtistKey = '\u00A9ART';
const String _mp4AlbumKey = '\u00A9alb';

/// One parsed MP4 atom: [start] points at the size field, [dataStart] past the
/// header (8 or 16 bytes) and [end] at the first byte after the atom.
class _Atom {
  const _Atom(this.type, this.start, this.dataStart, this.end);

  final String type;
  final int start;
  final int dataStart;
  final int end;
}

/// Reads `moov` → `udta` → `meta` → `ilst` and returns the text values of the
/// `©nam` / `©ART` / `©alb` atoms.
AudioTags? _parseMp4(Uint8List bytes) {
  for (final atom in _atoms(bytes, 0, bytes.length)) {
    if (atom.type == 'moov') {
      final ilst = _findIlst(bytes, atom.dataStart, atom.end);
      if (ilst == null) {
        continue;
      }
      String? title;
      String? artist;
      String? album;
      for (final item in _atoms(bytes, ilst.dataStart, ilst.end)) {
        final value = _mp4Value(bytes, item);
        if (value == null) {
          continue;
        }
        switch (item.type) {
          case _mp4TitleKey:
            title ??= value;
          case _mp4ArtistKey:
            artist ??= value;
          case _mp4AlbumKey:
            album ??= value;
        }
      }
      return AudioTags(title: title, artist: artist, album: album);
    }
  }
  return null;
}

/// Descends [start]..[end] looking for the `ilst` atom of a `meta` atom.
_Atom? _findIlst(Uint8List bytes, int start, int end) {
  for (final atom in _atoms(bytes, start, end)) {
    if (atom.type == 'meta') {
      // `meta` is a full atom: 4 bytes of version/flags before its children.
      final childrenStart = atom.dataStart + 4;
      if (childrenStart > atom.end) {
        continue;
      }
      for (final child in _atoms(bytes, childrenStart, atom.end)) {
        if (child.type == 'ilst') {
          return child;
        }
      }
    } else if (atom.type == 'udta' ||
        atom.type == 'moov' ||
        atom.type == 'trak') {
      final found = _findIlst(bytes, atom.dataStart, atom.end);
      if (found != null) {
        return found;
      }
    }
  }
  return null;
}

/// Reads the `data` atom inside a metadata item ([item]).
String? _mp4Value(Uint8List bytes, _Atom item) {
  for (final data in _atoms(bytes, item.dataStart, item.end)) {
    if (data.type != 'data') {
      continue;
    }
    final type = _u32(bytes, data.dataStart) & 0x00FFFFFF;
    // Payload follows the type/flags field; some writers add a locale field of
    // Payload follows the type/flags field; some writers add a locale field of
    // four zero bytes, which the leading-zero trim below discards. UTF-16
    // payloads keep their bytes untouched: their first byte is legitimately
    // 0x00 for ASCII text, and `_cleanText` drops locale zeros anyway.
    var start = data.dataStart + 4;
    if (type != 2) {
      var zeroes = 0;
      while (start < data.end && bytes[start] == 0 && zeroes < 4) {
        start++;
        zeroes++;
      }
    }
    if (start >= data.end) {
      return null;
    }
    return _decodeMp4Text(bytes, start, data.end, type);
  }
  return null;
}

/// Decodes an `ilst` value. MP4 `data` types: 2 = UTF-16 (a BOM decides the
/// byte order), anything else = UTF-8 text.
String? _decodeMp4Text(Uint8List bytes, int start, int end, int type) {
  if (start >= end) {
    return null;
  }
  if (type == 2) {
    return _cleanText(_decodeUtf16(bytes, start, end));
  }
  return _cleanText(
    utf8.decode(bytes.sublist(start, end), allowMalformed: true),
  );
}

/// Splits a sequence of sibling atoms out of [start]..[end]. Tolerates 64-bit
/// (`size == 1`) and to-the-end (`size == 0`) lengths, and stops on malformed
/// sizes rather than running away.
List<_Atom> _atoms(Uint8List bytes, int start, int end) {
  final result = <_Atom>[];
  var offset = start;
  while (offset + 8 <= end) {
    var size = _u32(bytes, offset);
    final type = String.fromCharCodes(bytes, offset + 4, offset + 8);
    var headerSize = 8;
    if (size == 1) {
      if (offset + 16 > end) {
        break;
      }
      size = _u64(bytes, offset + 8);
      headerSize = 16;
    } else if (size == 0) {
      size = end - offset;
    }
    if (size < headerSize) {
      break;
    }
    var atomEnd = offset + size;
    if (atomEnd > end || atomEnd <= offset) {
      atomEnd = end;
    }
    result.add(_Atom(type, offset, offset + headerSize, atomEnd));
    offset = atomEnd;
  }
  return result;
}

// ---------------------------------------------------------------------------
// Small byte helpers
// ---------------------------------------------------------------------------

bool _startsWith(Uint8List bytes, List<int> signature) {
  if (bytes.length < signature.length) {
    return false;
  }
  for (var i = 0; i < signature.length; i++) {
    if (bytes[i] != signature[i]) {
      return false;
    }
  }
  return true;
}

int _u32(Uint8List bytes, int offset) {
  if (offset < 0 || offset + 4 > bytes.length) {
    return 0;
  }
  return (bytes[offset] << 24) |
      (bytes[offset + 1] << 16) |
      (bytes[offset + 2] << 8) |
      bytes[offset + 3];
}

int _u64(Uint8List bytes, int offset) {
  if (offset < 0 || offset + 8 > bytes.length) {
    return 0;
  }
  var value = 0;
  for (var i = 0; i < 8; i++) {
    value = (value << 8) | bytes[offset + i];
  }
  return value;
}

/// Big-endian syncsafe integer: 7 significant bits per byte.
int _syncSafe(Uint8List bytes, int offset) {
  if (offset < 0 || offset + 4 > bytes.length) {
    return 0;
  }
  return ((bytes[offset] & 0x7F) << 21) |
      ((bytes[offset + 1] & 0x7F) << 14) |
      ((bytes[offset + 2] & 0x7F) << 7) |
      (bytes[offset + 3] & 0x7F);
}

int _indexOf(Uint8List bytes, List<int> pattern, int from) {
  if (pattern.isEmpty || bytes.length < pattern.length) {
    return -1;
  }
  outer:
  for (var i = from; i + pattern.length <= bytes.length; i++) {
    for (var j = 0; j < pattern.length; j++) {
      if (bytes[i + j] != pattern[j]) {
        continue outer;
      }
    }
    return i;
  }
  return -1;
}

/// Little-endian 32-bit integer, used by Vorbis comment blocks.
int _u32le(Uint8List bytes, int offset) {
  if (offset < 0 || offset + 4 > bytes.length) {
    return 0;
  }
  return bytes[offset] |
      (bytes[offset + 1] << 8) |
      (bytes[offset + 2] << 16) |
      (bytes[offset + 3] << 24);
}
