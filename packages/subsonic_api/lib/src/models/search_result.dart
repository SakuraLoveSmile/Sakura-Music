import 'artist.dart';
import 'album.dart';
import 'model_helpers.dart';
import 'song.dart';

class SearchResult3 {
  const SearchResult3({
    this.artists = const <Artist>[],
    this.albums = const <Album>[],
    this.songs = const <Song>[],
  });

  factory SearchResult3.fromJson(Map<String, dynamic> json) {
    return SearchResult3(
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
}
