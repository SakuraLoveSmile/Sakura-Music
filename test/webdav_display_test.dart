import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramusic/data/webdav/webdav_display.dart';

/// Coverage for the dependency-free display helpers used by the WebDAV
/// playlist UI: the app-bar path label must show decoded text instead of the
/// raw percent-encoded href, and a row without tags must fall back to a
/// cleaned-up version of the file name.
void main() {
  group('webdavPathLabel', () {
    test('renders the root for an empty path', () {
      expect(webdavPathLabel(''), '/');
      expect(webdavPathLabel('/'), '/');
    });

    test('decodes percent-encoded folder names', () {
      expect(webdavPathLabel('/Backup/%E9%9F%B3%E4%B9%90/'), '/Backup/音乐/');
      expect(
        webdavPathLabel('/%E9%9F%B3%E4%B9%90/%E6%AD%8C%E6%9B%B2/'),
        '/音乐/歌曲/',
      );
    });

    test('keeps plain paths untouched', () {
      expect(webdavPathLabel('/Backup/Live/'), '/Backup/Live/');
    });

    test('never throws on a malformed escape', () {
      expect(webdavPathLabel('/a%ZZb'), '/a%ZZb');
      expect(webdavPathLabel('%E9%9F'), '%E9%9F');
    });
  });

  group('cleanTrackTitle', () {
    test('drops the file extension', () {
      expect(cleanTrackTitle('Hello.mp3'), 'Hello');
      expect(cleanTrackTitle('Hello.flac'), 'Hello');
      expect(cleanTrackTitle('Hello World.m4a'), 'Hello World');
    });

    test('drops a leading track number', () {
      expect(cleanTrackTitle('01 Hello World.mp3'), 'Hello World');
      expect(cleanTrackTitle('01. Hello.mp3'), 'Hello');
      expect(cleanTrackTitle('01 - Hello.mp3'), 'Hello');
      expect(cleanTrackTitle('#12 Hello.mp3'), 'Hello');
      expect(cleanTrackTitle('Track 03 - Hello.mp3'), 'Hello');
      expect(cleanTrackTitle('track 03 - Hello.MP3'), 'Hello');
      expect(cleanTrackTitle('#7 Song.flac'), 'Song');
      expect(cleanTrackTitle('01 夜曲.mp3'), '夜曲');
    });

    test('collapses whitespace and trims', () {
      expect(cleanTrackTitle('Hello   World.flac'), 'Hello World');
      expect(cleanTrackTitle('  Hello World  .mp3'), 'Hello World');
      expect(cleanTrackTitle('01   -   Hello.mp3'), 'Hello');
    });

    test('drops a dotted track marker from a name without extension', () {
      expect(cleanTrackTitle('01. Hello'), 'Hello');
    });

    test('falls back to the extension-stripped name when nothing is left', () {
      expect(cleanTrackTitle('01 - .mp3'), '01 -');
    });
  });

  group('isAudioFileName', () {
    test('accepts the supported audio containers', () {
      for (final name in <String>[
        'song.mp3',
        'song.flac',
        'SONG.MP3',
        'song.m4a',
        'song.ogg',
        'song.opus',
        'song.wav',
      ]) {
        expect(isAudioFileName(name), isTrue, reason: name);
      }
    });

    test('rejects everything else', () {
      for (final name in <String>[
        'cover.jpg',
        'playlist.m3u',
        'notes.txt',
        'noextension',
        '01. Hello',
      ]) {
        expect(isAudioFileName(name), isFalse, reason: name);
      }
    });
  });
}
