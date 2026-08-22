import 'model_helpers.dart';
import 'song.dart';

class Playlist {
  const Playlist({
    required this.id,
    required this.name,
    this.songCount,
    this.duration,
    this.coverArt,
    this.owner,
    this.created,
    this.changed,
    this.public,
    this.songs = const <Song>[],
  });

  factory Playlist.fromJson(Map<String, dynamic> json) {
    return Playlist(
      id: asString(json['id']) ?? '',
      name: asString(json['name']) ?? '',
      songCount: asInt(json['songCount']),
      duration: asInt(json['duration']),
      coverArt: asString(json['coverArt']),
      owner: asString(json['owner']),
      created: asString(json['created']),
      changed: asString(json['changed']),
      public: asBool(json['public']),
      songs: asList(json['entry'] ?? json['song'])
          .map(asMap)
          .whereType<Map<String, dynamic>>()
          .map(Song.fromJson)
          .toList(growable: false),
    );
  }

  final String id;
  final String name;
  final int? songCount;
  final int? duration;
  final String? coverArt;
  final String? owner;
  final String? created;
  final String? changed;
  final bool? public;
  final List<Song> songs;
}
