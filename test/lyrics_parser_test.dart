import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramusic/features/player/lyrics/lyrics_parser.dart';
import 'package:sakuramusic/features/player/lyrics/lyrics_service.dart';

void main() {
  test('lyrics query uses stable value equality for Riverpod family keys', () {
    expect(
      const LyricsQuery(id: 'song-1', artist: 'Artist', title: 'Title'),
      const LyricsQuery(id: 'song-1', artist: 'Artist', title: 'Title'),
    );
    expect(
      const LyricsQuery(id: 'song-1', artist: 'Artist', title: 'Title'),
      isNot(const LyricsQuery(id: 'song-2', artist: 'Artist', title: 'Title')),
    );
  });

  test('parses multiple timestamps and sorts out-of-order lines', () {
    final lines = parseLrc('''
[00:02.50][00:01.00] First
[00:03:25] Second
not a timestamp
''');

    expect(lines.map((line) => line.timeMs), <int>[1000, 2500, 3250]);
    expect(lines.map((line) => line.text), <String>[
      'First',
      'First',
      'Second',
    ]);
  });

  test('applies positive and negative offset metadata', () {
    expect(parseLrc('[offset:500]\n[00:01.00] Hello').single.timeMs, 1500);
    expect(parseLrc('[offset:-250]\n[00:01.00] Hello').single.timeMs, 750);
  });

  test('skips malformed and empty lines', () {
    final lines = parseLrc('''
[00:01.00]
[bad] Nope
 [00:02.00] Good
''');

    expect(lines, hasLength(1));
    expect(lines.single.text, 'Good');
  });

  test(
    'ignores metadata and merges translated lines at the same timestamp',
    () {
      final lines = parseLrc('''
[ti:Song]
[ar:Artist]
[al:Album]
[00:02.00] Original
[00:02.00] Translation
[00:01.00] Earlier
''');

      expect(lines.map((line) => line.timeMs), <int>[1000, 2000]);
      expect(lines.last.text, 'Original\nTranslation');
    },
  );

  test('applies an offset declared after the lyric lines', () {
    expect(parseLrc('[00:01.00] Hello\n[offset:+250]').single.timeMs, 1250);
  });

  test('deduplicates repeated timestamps from one line', () {
    final lines = parseLrc('[00:01.00][00:01.00] Repeat');
    expect(lines, hasLength(1));
    expect(lines.single.text, 'Repeat');
  });
}
