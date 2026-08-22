import 'model_helpers.dart';

class Song {
  const Song({
    required this.id,
    required this.title,
    this.parent,
    this.album,
    this.albumId,
    this.artist,
    this.artistId,
    this.track,
    this.year,
    this.genre,
    this.coverArt,
    this.duration,
    this.bitRate,
    this.contentType,
    this.suffix,
    this.path,
    this.isDir = false,
  });

  factory Song.fromJson(Map<String, dynamic> json) {
    return Song(
      id: asString(json['id']) ?? '',
      title: asString(json['title']) ?? '',
      parent: asString(json['parent']),
      album: asString(json['album']),
      albumId: asString(json['albumId']),
      artist: asString(json['artist']),
      artistId: asString(json['artistId']),
      track: asInt(json['track']),
      year: asInt(json['year']),
      genre: asString(json['genre']),
      coverArt: asString(json['coverArt']),
      duration: asInt(json['duration']),
      bitRate: asInt(json['bitRate']),
      contentType: asString(json['contentType']),
      suffix: asString(json['suffix']),
      path: asString(json['path']),
      isDir: asBool(json['isDir']) ?? false,
    );
  }

  final String id;
  final String title;
  final String? parent;
  final String? album;
  final String? albumId;
  final String? artist;
  final String? artistId;
  final int? track;
  final int? year;
  final String? genre;
  final String? coverArt;

  /// Subsonic reports duration in seconds.
  final int? duration;
  final int? bitRate;
  final String? contentType;
  final String? suffix;
  final String? path;
  final bool isDir;

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'title': title,
    'parent': parent,
    'album': album,
    'albumId': albumId,
    'artist': artist,
    'artistId': artistId,
    'track': track,
    'year': year,
    'genre': genre,
    'coverArt': coverArt,
    'duration': duration,
    'bitRate': bitRate,
    'contentType': contentType,
    'suffix': suffix,
    'path': path,
    'isDir': isDir,
  };

  @override
  String toString() => 'Song(id: $id, title: $title)';
}
