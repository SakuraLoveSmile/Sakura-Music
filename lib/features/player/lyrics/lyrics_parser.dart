/// A timestamped line returned by the LRC parser and lyrics service.
class ParsedLyricsLine {
  const ParsedLyricsLine({required this.timeMs, required this.text});

  final int timeMs;
  final String text;
}

/// Backwards-compatible descriptive alias for callers that prefer the
/// shorter model name.
typedef LyricsLine = ParsedLyricsLine;

final _timestampPattern = RegExp(r'\[(\d{1,4}):(\d{1,2})(?:[.:](\d{1,3}))?\]');
final _offsetPattern = RegExp(
  r'\[offset\s*:\s*([+-]?\d+)\]',
  caseSensitive: false,
);

/// Parses common LRC files.
///
/// The parser intentionally ignores metadata such as `[ti]`, `[ar]`, and
/// `[al]`, applies every offset tag globally, accepts multiple timestamps on
/// one line, tolerates malformed lines, sorts the result, and merges
/// translated lines that share a timestamp. Merged texts are separated by a
/// newline so both the original and translation remain readable.
List<ParsedLyricsLine> parseLrc(String source) {
  final offsetMs = _readOffset(source);
  final grouped = <int, List<String>>{};

  for (final rawLine in source.split(RegExp(r'\r?\n'))) {
    final matches = _timestampPattern
        .allMatches(rawLine)
        .toList(growable: false);
    if (matches.isEmpty) {
      // This also skips metadata and malformed lines without making metadata
      // parsing part of the returned model.
      continue;
    }

    final text = rawLine.substring(matches.last.end).trim();
    if (text.isEmpty) {
      continue;
    }
    for (final match in matches) {
      final minutes = int.tryParse(match.group(1)!);
      final seconds = int.tryParse(match.group(2)!);
      if (minutes == null || seconds == null || seconds > 59) {
        continue;
      }
      final timeMs =
          minutes * 60 * 1000 +
          seconds * 1000 +
          _fractionToMilliseconds(match.group(3)) +
          offsetMs;
      final values = grouped.putIfAbsent(timeMs, () => <String>[]);
      if (!values.contains(text)) {
        values.add(text);
      }
    }
  }

  final lines = grouped.entries
      .map(
        (entry) =>
            ParsedLyricsLine(timeMs: entry.key, text: entry.value.join('\n')),
      )
      .toList(growable: false);
  lines.sort((a, b) => a.timeMs.compareTo(b.timeMs));
  return List<ParsedLyricsLine>.unmodifiable(lines);
}

/// Normalizes structured lyrics using the same ordering and translation merge
/// rules as LRC lyrics.
List<ParsedLyricsLine> mergeLyricsLines(Iterable<ParsedLyricsLine> lines) {
  final grouped = <int, List<String>>{};
  for (final line in lines) {
    final text = line.text.trim();
    if (text.isEmpty) {
      continue;
    }
    final values = grouped.putIfAbsent(line.timeMs, () => <String>[]);
    if (!values.contains(text)) {
      values.add(text);
    }
  }
  final result = grouped.entries
      .map(
        (entry) =>
            ParsedLyricsLine(timeMs: entry.key, text: entry.value.join('\n')),
      )
      .toList(growable: false);
  result.sort((a, b) => a.timeMs.compareTo(b.timeMs));
  return List<ParsedLyricsLine>.unmodifiable(result);
}

int _readOffset(String source) {
  // The last tag wins, matching common LRC player behavior and making the
  // parser tolerant of files that contain a corrected offset later on.
  var offsetMs = 0;
  for (final match in _offsetPattern.allMatches(source)) {
    offsetMs = int.tryParse(match.group(1)!) ?? offsetMs;
  }
  return offsetMs;
}

int _fractionToMilliseconds(String? fraction) {
  if (fraction == null || fraction.isEmpty) {
    return 0;
  }
  final value = int.tryParse(fraction);
  if (value == null) {
    return 0;
  }
  return switch (fraction.length) {
    1 => value * 100,
    2 => value * 10,
    _ => int.parse(fraction.substring(0, 3)),
  };
}
