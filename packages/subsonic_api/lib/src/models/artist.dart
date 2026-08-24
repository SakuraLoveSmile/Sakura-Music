import 'model_helpers.dart';
import 'album.dart';

class Artist {
  const Artist({
    required this.id,
    required this.name,
    this.albumCount,
    this.coverArt,
    this.artistImageUrl,
    this.albums = const <Album>[],
  });

  factory Artist.fromJson(Map<String, dynamic> json) {
    return Artist(
      id: asString(json['id']) ?? '',
      name: asString(json['name']) ?? '',
      albumCount: asInt(json['albumCount']),
      coverArt: asString(json['coverArt']),
      artistImageUrl: asString(json['artistImageUrl']),
      albums: asList(json['album'] ?? json['albums'])
          .map(asMap)
          .whereType<Map<String, dynamic>>()
          .map(Album.fromJson)
          .toList(growable: false),
    );
  }

  final String id;
  final String name;
  final int? albumCount;
  final String? coverArt;
  final String? artistImageUrl;
  final List<Album> albums;

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'name': name,
    'albumCount': albumCount,
    'coverArt': coverArt,
    'artistImageUrl': artistImageUrl,
    'album': albums.map((album) => album.toJson()).toList(growable: false),
  };

  @override
  String toString() => 'Artist(id: $id, name: $name)';
}
