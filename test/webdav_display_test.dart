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

  group('isAudioHref', () {
    test('accepts audio hrefs with encoded names and upper-case suffixes', () {
      for (final href in <String>[
        '/Music/01%20-%20One.mp3',
        '/Music/SONG.MP3',
        '/a/b/song.flac',
        '/song.mp3',
      ]) {
        expect(isAudioHref(href), isTrue, reason: href);
      }
    });

    test('rejects lyric, artwork and playlist hrefs', () {
      for (final href in <String>[
        '/Music/01%20-%20One.lrc',
        '/Music/cover.jpg',
        '/Music/list.m3u',
        '/Music/notes.txt',
        '/Music/noext',
      ]) {
        expect(isAudioHref(href), isFalse, reason: href);
      }
    });

    test('rejects directory hrefs', () {
      for (final href in <String>['/Music/', '/Music/Album/', '/', '']) {
        expect(isAudioHref(href), isFalse, reason: href);
      }
    });

    test('ignores query strings and fragments', () {
      expect(isAudioHref('/Music/song.mp3?token=abc'), isTrue);
      expect(isAudioHref('/Music/song.mp3#t=30'), isTrue);
      expect(isAudioHref('/Music/cover.jpg?x=1'), isFalse);
    });

    test('recognises a percent-encoded file name', () {
      // The name is decoded before the suffix is inspected.
      expect(isAudioHref('/Music/%E5%A4%9C%E6%9B%B2.MP3'), isTrue);
    });
  });
}
