import 'model_helpers.dart';

class LyricsLine {
  const LyricsLine({required this.timeMs, required this.text});

  factory LyricsLine.fromJson(Map<String, dynamic> json) {
    return LyricsLine(
      timeMs: asInt(json['start'] ?? json['timeMs'] ?? json['time']) ?? 0,
      text: asString(json['value'] ?? json['text']) ?? '',
    );
  }

  final int timeMs;
  final String text;
}

class StructuredLyrics {
  const StructuredLyrics({
    this.lang,
    this.synced = false,
    this.displayArtist,
    this.displayTitle,
    this.lines = const <LyricsLine>[],
  });

  factory StructuredLyrics.fromJson(Map<String, dynamic> json) {
    return StructuredLyrics(
      lang: asString(json['lang'] ?? json['language']),
      synced: asBool(json['synced']) ?? false,
      displayArtist: asString(json['displayArtist']),
      displayTitle: asString(json['displayTitle']),
      lines: asList(json['line'] ?? json['lines'])
          .map(asMap)
          .whereType<Map<String, dynamic>>()
          .map(LyricsLine.fromJson)
          .toList(growable: false),
    );
  }

  final String? lang;
  final bool synced;
  final String? displayArtist;
  final String? displayTitle;
  final List<LyricsLine> lines;
}
