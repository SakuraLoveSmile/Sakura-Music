import 'model_helpers.dart';
import 'song.dart';

class Album {
  const Album({
    required this.id,
    required this.name,
    this.artist,
    this.artistId,
    this.coverArt,
    this.songCount,
    this.duration,
    this.year,
    this.genre,
    this.created,
    this.songs = const <Song>[],
  });

  factory Album.fromJson(Map<String, dynamic> json) {
    return Album(
      id: asString(json['id']) ?? '',
      name: asString(json['name']) ?? asString(json['title']) ?? '',
      artist: asString(json['artist']),
      artistId: asString(json['artistId']),
      coverArt: asString(json['coverArt']),
      songCount: asInt(json['songCount']),
      duration: asInt(json['duration']),
      year: asInt(json['year']),
      genre: asString(json['genre']),
      created: asString(json['created']),
      songs: asList(json['song'])
          .map(asMap)
          .whereType<Map<String, dynamic>>()
          .map(Song.fromJson)
          .toList(growable: false),
    );
  }

  final String id;
  final String name;
  final String? artist;
  final String? artistId;
  final String? coverArt;
  final int? songCount;
  final int? duration;
  final int? year;
  final String? genre;
  final String? created;
  final List<Song> songs;

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'name': name,
    'artist': artist,
    'artistId': artistId,
    'coverArt': coverArt,
    'songCount': songCount,
    'duration': duration,
    'year': year,
    'genre': genre,
    'created': created,
    'song': songs.map((song) => song.toJson()).toList(growable: false),
  };

  @override
  String toString() => 'Album(id: $id, name: $name)';
}
