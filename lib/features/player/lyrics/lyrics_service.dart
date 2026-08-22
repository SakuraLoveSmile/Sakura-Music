import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:subsonic_api/subsonic_api.dart';

import '../../../core/providers.dart';
import 'lyrics_parser.dart';

class LyricsQuery {
  const LyricsQuery({required this.id, this.artist, this.title});

  final String id;
  final String? artist;
  final String? title;

  @override
  bool operator ==(Object other) {
    return other is LyricsQuery &&
        other.id == id &&
        other.artist == artist &&
        other.title == title;
  }

  @override
  int get hashCode => Object.hash(id, artist, title);
}

class LyricsService {
  LyricsService(this.client);

  final SubsonicClient? client;
  final Map<String, Future<List<ParsedLyricsLine>?>> _cache =
      <String, Future<List<ParsedLyricsLine>?>>{};

  Future<List<ParsedLyricsLine>?> load(LyricsQuery query) async {
    final cached = _cache[query.id];
    if (cached != null) {
      return cached;
    }
    final pending = _loadUncached(query);
    _cache[query.id] = pending;
    return pending;
  }

  Future<List<ParsedLyricsLine>?> _loadUncached(LyricsQuery query) async {
    final subsonic = client;
    if (subsonic == null) {
      return null;
    }
    try {
      final structured = await subsonic.getLyricsBySongId(query.id);
      final synced = structured.where(
        (item) => item.synced && item.lines.isNotEmpty,
      );
      if (synced.isNotEmpty) {
        return mergeLyricsLines(
          synced.first.lines.map(
            (line) => ParsedLyricsLine(timeMs: line.timeMs, text: line.text),
          ),
        );
      }
    } catch (_) {
      // Older Subsonic servers may return 404 for this OpenSubsonic endpoint.
    }

    try {
      final plainText = await subsonic.getLyrics(
        artist: query.artist,
        title: query.title,
      );
      if (plainText == null || plainText.trim().isEmpty) {
        return null;
      }
      final parsed = parseLrc(plainText);
      return parsed.isEmpty ? null : parsed;
    } catch (_) {
      return null;
    }
  }
}

final lyricsServiceProvider = Provider<LyricsService?>((ref) {
  final client = ref.watch(activeSubsonicClientProvider);
  return client == null ? null : LyricsService(client);
});

final lyricsProvider =
    FutureProvider.family<List<ParsedLyricsLine>?, LyricsQuery>((ref, query) {
      return ref.watch(lyricsServiceProvider)?.load(query);
    });
