import 'model_helpers.dart';
import 'song.dart';

class Genre {
  const Genre({
    required this.name,
    this.songCount,
    this.albumCount,
    this.songs = const <Song>[],
  });

  factory Genre.fromJson(Map<String, dynamic> json) {
    return Genre(
      name: asString(json['value'] ?? json['name'] ?? json['genre']) ?? '',
      songCount: asInt(json['songCount']),
      albumCount: asInt(json['albumCount']),
      songs: asList(json['song'] ?? json['songs'])
          .map(asMap)
          .whereType<Map<String, dynamic>>()
          .map(Song.fromJson)
          .toList(growable: false),
    );
  }

  final String name;
  final int? songCount;
  final int? albumCount;
  final List<Song> songs;
}
