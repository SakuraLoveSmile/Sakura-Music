import 'album.dart';
import 'artist.dart';
import 'model_helpers.dart';
import 'song.dart';

class Starred2 {
  const Starred2({
    this.artists = const <Artist>[],
    this.albums = const <Album>[],
    this.songs = const <Song>[],
  });

  factory Starred2.fromJson(Map<String, dynamic> json) {
    return Starred2(
      artists: asList(json['artist'] ?? json['artists'])
          .map(asMap)
          .whereType<Map<String, dynamic>>()
          .map(Artist.fromJson)
          .toList(growable: false),
      albums: asList(json['album'] ?? json['albums'])
          .map(asMap)
          .whereType<Map<String, dynamic>>()
          .map(Album.fromJson)
          .toList(growable: false),
      songs: asList(json['song'] ?? json['songs'])
          .map(asMap)
          .whereType<Map<String, dynamic>>()
          .map(Song.fromJson)
          .toList(growable: false),
    );
  }

  final List<Artist> artists;
  final List<Album> albums;
  final List<Song> songs;

  Starred2 copyWith({
    List<Artist>? artists,
    List<Album>? albums,
    List<Song>? songs,
  }) {
    return Starred2(
      artists: artists ?? this.artists,
      albums: albums ?? this.albums,
      songs: songs ?? this.songs,
    );
  }
}
