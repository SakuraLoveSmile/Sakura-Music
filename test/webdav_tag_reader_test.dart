import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramusic/data/webdav/webdav_tag_reader.dart';
import 'package:sakuramusic/data/webdav/webdav_tags.dart';

/// Coverage for the zero-dependency WebDAV audio tag probe: `parseAudioTags`
/// is exercised against synthetic ID3v2.3 (UTF-8, UTF-16LE with BOM, UTF-16BE),
/// Ogg Vorbis comment, FLAC `VORBIS_COMMENT` and MP4 `ilst` blocks, plus
/// malformed input that must never throw. `readWebDavTags` is then checked for
/// its audio-file gate (a non-audio href must not trigger a single fetch), the
/// bounded byte limit it forwards to the loader and its error handling.
///
/// Every byte array is built by the helpers at the bottom of this file; no
/// network access and no real file is involved.
void main() {
  group('parseAudioTags - ID3v2', () {
    test('A1 - decodes an ID3v2.3 tag whose text frames are UTF-8', () {
      final bytes = _id3v23(<Uint8List>[
        _id3Text('TIT2', '夜曲'),
        _id3Text('TPE1', '周杰伦'),
        _id3Text('TALB', '十一月的萧邦'),
      ]);

      final tags = parseAudioTags(bytes);

      expect(tags, isNotNull, reason: 'TIT2/TPE1/TALB are a usable tag block');
      expect(tags!.title, '夜曲');
      expect(tags.artist, '周杰伦');
      expect(tags.album, '十一月的萧邦');
    });

    test(
      'A2 - decodes ID3v2.3 UTF-16LE text frames with a BOM (encoding 1)',
      () {
        final bytes = _id3v23(<Uint8List>[
          _id3Text('TIT2', '夜曲', encoding: 1),
          _id3Text('TPE1', 'Jay Chou', encoding: 1),
        ]);

        final tags = parseAudioTags(bytes);

        expect(tags, isNotNull);
        expect(
          tags!.title,
          '夜曲',
          reason: 'the FF FE BOM selects little-endian',
        );
        expect(tags.artist, 'Jay Chou');
        expect(tags.album, isNull, reason: 'no TALB frame was written');
      },
    );

    test(
      'A3 - decodes ID3v2.3 UTF-16BE (encoding 2) and BOM-less encoding 1',
      () {
        final bigEndian = _id3v23(<Uint8List>[
          _id3Text('TIT2', '青花瓷', encoding: 2),
          _id3Text('TALB', '我很忙', encoding: 2),
        ]);

        final bigEndianTags = parseAudioTags(bigEndian);

        expect(bigEndianTags, isNotNull);
        expect(bigEndianTags!.title, '青花瓷');
        expect(bigEndianTags.album, '我很忙');

        final noBom = _id3v23(<Uint8List>[
          _id3Text('TIT2', '夜曲', encoding: 1, bom: false),
        ]);

        final noBomTags = parseAudioTags(noBom);

        expect(noBomTags, isNotNull, reason: 'BOM-less UTF-16 defaults to BE');
        expect(noBomTags!.title, '夜曲');
      },
    );

    test(
      'A4 - decodes an Ogg Vorbis comment block, keys are case-insensitive',
      () {
        final bytes = _ogg('sakuramusic-tests', <String>[
          'title=夜曲',
          'ARTIST=周杰伦',
          'ALBUM=十一月的萧邦',
        ]);

        final tags = parseAudioTags(bytes);

        expect(tags, isNotNull);
        expect(
          tags!.title,
          '夜曲',
          reason: 'a lowercase "title" key still counts',
        );
        expect(tags.artist, '周杰伦');
        expect(tags.album, '十一月的萧邦');
      },
    );

    test('A5 - decodes a FLAC VORBIS_COMMENT block and leaves album null', () {
      final bytes = _flac('sakuramusic-tests', <String>[
        'TITLE=标签标题',
        'ARTIST=标签歌手',
      ]);

      final tags = parseAudioTags(bytes);

      expect(tags, isNotNull);
      expect(tags!.title, '标签标题');
      expect(tags.artist, '标签歌手');
      expect(tags.album, isNull, reason: 'the block carries no ALBUM entry');
    });

    test('A5 - walks past a preceding STREAMINFO metadata block', () {
      final bytes = _flac('sakuramusic-tests', <String>[
        'TITLE=蓝色天空',
        'ALBUM=专题专辑',
      ], withStreamInfo: true);

      final tags = parseAudioTags(bytes);

      expect(tags, isNotNull);
      expect(tags!.title, '蓝色天空');
      expect(tags.album, '专题专辑');
      expect(tags.artist, isNull);
    });
    test('A7 - accepts a Vorbis comment whose vendor string is empty', () {
      // An empty vendor string is legal; only an out-of-range length is not.
      final flac = _flac('', <String>['TITLE=空厂商', 'ARTIST=歌手']);
      final ogg = _ogg('', <String>['TITLE=空厂商', 'ARTIST=歌手']);

      expect(parseAudioTags(flac)?.title, '空厂商');
      expect(parseAudioTags(flac)?.artist, '歌手');
      expect(parseAudioTags(ogg)?.title, '空厂商');
      expect(parseAudioTags(ogg)?.artist, '歌手');
    });

    test('A7 - resolves tags when the FLAC Vorbis vendor string is empty', () {
      final bytes = _flac('', <String>['TITLE=空供应商', 'ARTIST=未知歌手']);

      final tags = parseAudioTags(bytes);

      expect(
        tags,
        isNotNull,
        reason: 'vendorLength 0 is a legal empty vendor and keeps the block',
      );
      expect(tags!.title, '空供应商');
      expect(tags.artist, '未知歌手');
      expect(tags.album, isNull, reason: 'the block carries no ALBUM entry');
    });

    test('A6 - decodes MP4 ilst ©nam/©ART/©alb atoms', () {
      final bytes = _mp4(title: '夜曲', artist: '周杰伦', album: '十一月的萧邦');

      final tags = parseAudioTags(bytes);

      expect(tags, isNotNull, reason: 'moov>udta>meta>ilst carries the items');
      expect(tags!.title, '夜曲');
      expect(tags.artist, '周杰伦');
      expect(tags.album, '十一月的萧邦');
    });
  });

  group('parseAudioTags - robustness', () {
    test('B7 - returns null for 200 bytes of unrecognised junk', () {
      final junk = _junk(200);

      expect(junk.length, 200);
      // Sanity check: the filler really starts with no container magic.
      expect(junk[0], isNot(0x49));
      expect(junk[0], isNot(0x66));
      expect(junk[0], isNot(0x4F));
      expect(parseAudioTags(junk), isNull);
    });

    test(
      'B8 - returns null for a valid ID3v2.3 header without usable frames',
      () {
        final onlyTxxx = _id3v23(<Uint8List>[
          _id3Text('TXXX', 'replaygain=1.0'),
        ]);
        final noFrames = _id3v23(const <Uint8List>[]);

        expect(parseAudioTags(onlyTxxx), isNull);
        expect(parseAudioTags(noFrames), isNull);
      },
    );

    test('B9 - returns null for an empty byte array', () {
      expect(parseAudioTags(Uint8List(0)), isNull);
    });

    test(
      'B10 - never throws on a truncated ID3 header or truncated frames',
      () {
        final truncatedHeader = Uint8List.fromList(<int>[
          0x49, 0x44, 0x33, // 'ID3'
          0x03, 0x00, 0x00,
        ]);
        final full = _id3v23(<Uint8List>[_id3Text('TIT2', '夜曲')]);
        final truncatedFrame = Uint8List.sublistView(full, 0, 14);

        expect(() => parseAudioTags(truncatedHeader), returnsNormally);
        expect(() => parseAudioTags(truncatedFrame), returnsNormally);
        expect(parseAudioTags(truncatedHeader), isNull);
      },
    );
  });

  group('readWebDavTags', () {
    test('C11 - a non-audio href never reaches the loader', () async {
      var calls = 0;
      Future<Uint8List> load(String href, {int maxBytes = 0}) async {
        calls++;
        return _id3v23(<Uint8List>[_id3Text('TIT2', '夜曲')]);
      }

      for (final href in <String>[
        '/Music/cover.jpg',
        '/Music/playlist.m3u',
        '/Music/noext',
      ]) {
        expect(
          await readWebDavTags(href: href, load: load),
          isNull,
          reason: '$href is not an audio file',
        );
      }
      expect(
        calls,
        0,
        reason: 'no audio name was probed, so no fetch happened',
      );
    });

    test(
      'C12 - probes an audio href and forwards the raw href and the limit',
      () async {
        const href = '/Music/%E5%A4%9C%E6%9B%B2.mp3';
        String? seenHref;
        int? seenMaxBytes;
        final bytes = _id3v23(<Uint8List>[
          _id3Text('TIT2', '夜曲'),
          _id3Text('TPE1', '周杰伦'),
          _id3Text('TALB', '十一月的萧邦'),
        ]);
        Future<Uint8List> load(String requested, {int maxBytes = 0}) async {
          seenHref = requested;
          seenMaxBytes = maxBytes;
          return bytes;
        }

        final tags = await readWebDavTags(href: href, load: load);

        expect(seenHref, href, reason: 'the loader gets the untouched href');
        expect(seenMaxBytes, kWebDavTagProbeBytes);
        expect(seenMaxBytes, 524288);
        expect(tags, isNotNull);
        expect(tags!.title, '夜曲');
        expect(tags.artist, '周杰伦');
        expect(tags.album, '十一月的萧邦');
      },
    );

    test('C13 - a failing loader yields null instead of propagating', () async {
      Future<Uint8List> failsAsync(String href, {int maxBytes = 0}) async {
        throw StateError('network down');
      }

      Future<Uint8List> failsSync(String href, {int maxBytes = 0}) {
        throw StateError('bad request');
      }

      expect(
        await readWebDavTags(href: '/Music/a.mp3', load: failsAsync),
        isNull,
      );
      expect(
        await readWebDavTags(href: '/Music/a.mp3', load: failsSync),
        isNull,
      );
    });

    test('C14 - garbage or empty bytes from the loader yield null', () async {
      Future<Uint8List> junk(String href, {int maxBytes = 0}) async {
        return _junk(200);
      }

      Future<Uint8List> nothing(String href, {int maxBytes = 0}) async {
        return Uint8List(0);
      }

      expect(await readWebDavTags(href: '/Music/b.flac', load: junk), isNull);
      expect(
        await readWebDavTags(href: '/Music/b.flac', load: nothing),
        isNull,
      );
    });

    test(
      'C15 - forwards an explicit maxBytes and repairs non-positive values',
      () async {
        final seen = <int>[];
        Future<Uint8List> load(String href, {int maxBytes = 0}) async {
          seen.add(maxBytes);
          return Uint8List(0);
        }

        await readWebDavTags(href: '/Music/a.mp3', load: load, maxBytes: 1024);
        await readWebDavTags(href: '/Music/a.mp3', load: load, maxBytes: 0);
        await readWebDavTags(href: '/Music/a.mp3', load: load, maxBytes: -4096);

        expect(seen, <int>[1024, kWebDavTagProbeBytes, kWebDavTagProbeBytes]);
      },
    );

    test('C16 - kWebDavTagProbeBytes is 512 KiB', () {
      expect(kWebDavTagProbeBytes, 512 * 1024);
      expect(kWebDavTagProbeBytes, 524288);
    });
  });
}

// ---------------------------------------------------------------------------
// Synthetic byte builders
// ---------------------------------------------------------------------------

Uint8List _u32be(int value) => Uint8List.fromList(<int>[
  (value >> 24) & 0xFF,
  (value >> 16) & 0xFF,
  (value >> 8) & 0xFF,
  value & 0xFF,
]);

Uint8List _u32le(int value) => Uint8List.fromList(<int>[
  value & 0xFF,
  (value >> 8) & 0xFF,
  (value >> 16) & 0xFF,
  (value >> 24) & 0xFF,
]);

Uint8List _u24be(int value) => Uint8List.fromList(<int>[
  (value >> 16) & 0xFF,
  (value >> 8) & 0xFF,
  value & 0xFF,
]);

/// Big-endian "syncsafe" integer: 7 significant bits per byte.
Uint8List _syncsafe(int value) => Uint8List.fromList(<int>[
  (value >> 21) & 0x7F,
  (value >> 14) & 0x7F,
  (value >> 7) & 0x7F,
  value & 0x7F,
]);

/// Encodes [value] as UTF-16 code units without a BOM.
List<int> _utf16(String value, {required bool littleEndian}) {
  final out = <int>[];
  for (final unit in value.codeUnits) {
    if (littleEndian) {
      out
        ..add(unit & 0xFF)
        ..add((unit >> 8) & 0xFF);
    } else {
      out
        ..add((unit >> 8) & 0xFF)
        ..add(unit & 0xFF);
    }
  }
  return out;
}

/// One ID3v2.3 frame: 4-character [id], 32-bit big-endian size, 2 flag bytes.
Uint8List _id3Frame(String id, List<int> payload) => Uint8List.fromList(<int>[
  ...id.codeUnits,
  ..._u32be(payload.length),
  0x00,
  0x00,
  ...payload,
]);

/// ID3v2 text frame: `[encoding]` followed by the encoded [value]. Encoding 1
/// is UTF-16 with a BOM when [bom] is set, otherwise plain big-endian UTF-16.
Uint8List _id3Text(
  String id,
  String value, {
  int encoding = 3,
  bool bom = true,
}) {
  final List<int> text;
  if (encoding == 1) {
    text = bom
        ? <int>[0xFF, 0xFE, ..._utf16(value, littleEndian: true)]
        : _utf16(value, littleEndian: false);
  } else if (encoding == 2) {
    text = _utf16(value, littleEndian: false);
  } else {
    text = utf8.encode(value);
  }
  return _id3Frame(id, <int>[encoding, ...text]);
}

/// ID3v2.3 tag (`ID3`, version 3.0, no flags) wrapping [frames].
Uint8List _id3v23(List<Uint8List> frames) {
  final body = <int>[];
  for (final frame in frames) {
    body.addAll(frame);
  }
  return Uint8List.fromList(<int>[
    0x49, 0x44, 0x33, // 'ID3'
    0x03, 0x00, // version 2.3.0
    0x00, // flags: no unsynchronisation, no extended header
    ..._syncsafe(body.length),
    ...body,
  ]);
}

/// Vorbis comment block: `vendorLength u32le`, vendor, `count u32le`, then
/// `length u32le` + `KEY=value` UTF-8 per entry.
Uint8List _vorbisComment(String vendor, List<String> entries) {
  final out = <int>[];
  final vendorBytes = utf8.encode(vendor);
  out
    ..addAll(_u32le(vendorBytes.length))
    ..addAll(vendorBytes)
    ..addAll(_u32le(entries.length));
  for (final entry in entries) {
    final entryBytes = utf8.encode(entry);
    out
      ..addAll(_u32le(entryBytes.length))
      ..addAll(entryBytes);
  }
  return Uint8List.fromList(out);
}

/// A single Ogg page holding the identification packet (`\x01vorbis` plus 30
/// header bytes) followed by the comment packet (`\x03vorbis` + comment block
/// + framing bit).
Uint8List _ogg(String vendor, List<String> entries) {
  final payload = <int>[
    0x01, ...'vorbis'.codeUnits,
    ..._u32le(0), // vorbis version
    0x02, // channels
    ..._u32le(44100), // sample rate
    ..._u32le(0), // bitrate maximum
    ..._u32le(0), // bitrate nominal
    ..._u32le(0), // bitrate minimum
    0x00, // block sizes
    0x01, // framing bit
    0x03, ...'vorbis'.codeUnits,
    ..._vorbisComment(vendor, entries),
    0x01, // comment framing bit
  ];
  final lacing = <int>[];
  var remaining = payload.length;
  while (remaining >= 255) {
    lacing.add(255);
    remaining -= 255;
  }
  lacing.add(remaining);
  return Uint8List.fromList(<int>[
    ...'OggS'.codeUnits,
    0x00, // stream structure version
    0x00, // header type: beginning of stream
    ...List<int>.filled(8, 0), // granule position
    ..._u32le(1), // bitstream serial number
    ..._u32le(0), // page sequence number
    ..._u32le(0), // CRC
    lacing.length, // page segment count
    ...lacing,
    ...payload,
  ]);
}

/// FLAC stream: `fLaC`, an optional STREAMINFO block, then the last-marked
/// `VORBIS_COMMENT` block (type 4).
Uint8List _flac(
  String vendor,
  List<String> entries, {
  bool withStreamInfo = false,
}) {
  final out = <int>[...'fLaC'.codeUnits];
  if (withStreamInfo) {
    const streamInfoLength = 34;
    out
      ..add(0x00) // block type 0, not last
      ..addAll(_u24be(streamInfoLength))
      ..addAll(List<int>.filled(streamInfoLength, 0));
  }
  final comment = _vorbisComment(vendor, entries);
  out
    ..add(0x84) // block type 4 (VORBIS_COMMENT), last-metadata-block flag
    ..addAll(_u24be(comment.length))
    ..addAll(comment);
  return Uint8List.fromList(out);
}

/// One ISO base media file format atom: 32-bit size, 4-character [type],
/// [payload].
Uint8List _mp4Atom(String type, List<int> payload) => Uint8List.fromList(<int>[
  ..._u32be(8 + payload.length),
  ...type.codeUnits,
  ...payload,
]);

/// An `ilst` `data` atom holding [value] as UTF-8 text (data type 1).
Uint8List _mp4TextData(String value) =>
    _mp4Atom('data', <int>[..._u32be(1), ...utf8.encode(value)]);

/// MP4 metadata: `ftyp` followed by `moov` > `udta` > `meta` > `ilst`.
Uint8List _mp4({String? title, String? artist, String? album}) {
  final items = <int>[];
  void addItem(String key, String? value) {
    if (value == null) {
      return;
    }
    items.addAll(_mp4Atom(key, _mp4TextData(value)));
  }

  addItem('\u00A9nam', title);
  addItem('\u00A9ART', artist);
  addItem('\u00A9alb', album);
  final ilst = _mp4Atom('ilst', items);
  final meta = _mp4Atom('meta', <int>[0x00, 0x00, 0x00, 0x00, ...ilst]);
  final udta = _mp4Atom('udta', meta);
  final moov = _mp4Atom('moov', udta);
  final ftyp = _mp4Atom('ftyp', <int>[
    ...'isom'.codeUnits,
    ..._u32be(512),
    ...'isomiso2'.codeUnits,
  ]);
  return Uint8List.fromList(<int>[...ftyp, ...moov]);
}

/// Deterministic filler bytes that carry no container magic.
Uint8List _junk(int length) =>
    Uint8List.fromList(List<int>.generate(length, (i) => (i * 37 + 11) & 0xFF));
