import 'artist.dart';
import 'model_helpers.dart';

/// Additional biography and discovery metadata for an artist.
class ArtistInfo2 {
  const ArtistInfo2({
    this.artistId,
    this.name,
    this.biography,
    this.musicBrainzId,
    this.lastFmUrl,
    this.smallImageUrl,
    this.mediumImageUrl,
    this.largeImageUrl,
    this.coverArt,
    this.similarArtists = const <Artist>[],
  });

  factory ArtistInfo2.fromJson(Map<String, dynamic> json) {
    return ArtistInfo2(
      artistId: asString(json['artistId'] ?? json['id']),
      name: asString(json['name']),
      biography: asString(json['biography']),
      musicBrainzId: asString(json['musicBrainzId']),
      lastFmUrl: asString(json['lastFmUrl']),
      smallImageUrl: asString(json['smallImageUrl']),
      mediumImageUrl: asString(json['mediumImageUrl']),
      largeImageUrl: asString(json['largeImageUrl']),
      coverArt: asString(json['coverArt']),
      similarArtists: asList(json['similarArtist'] ?? json['similarArtists'])
          .map(asMap)
          .whereType<Map<String, dynamic>>()
          .map(Artist.fromJson)
          .toList(growable: false),
    );
  }

  final String? artistId;
  final String? name;
  final String? biography;
  final String? musicBrainzId;
  final String? lastFmUrl;
  final String? smallImageUrl;
  final String? mediumImageUrl;
  final String? largeImageUrl;
  final String? coverArt;
  final List<Artist> similarArtists;
}
