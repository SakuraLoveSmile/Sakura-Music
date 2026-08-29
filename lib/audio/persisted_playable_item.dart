import 'audio_player_service.dart';

/// Persistence view of a [PlayableItem].
///
/// The runtime item carries a fully signed [PlayableItem.streamUrl] (Subsonic
/// `u/t/s` credentials) and possibly a WebDAV `Authorization` header. Neither
/// may be written to disk, so this DTO stores only non-sensitive metadata and
/// the coordinator regenerates the URL/headers when the queue is restored.
class PersistedPlayableItem {
  const PersistedPlayableItem({
    required this.sourceType,
    required this.id,
    required this.title,
    this.artist,
    this.album,
    this.albumId,
    this.artistId,
    this.durationMs,
    this.coverArtId,
    this.localFilePath,
  });

  /// How the stream URL is rebuilt on restore:
  ///
  /// * `subsonic` — `SubsonicClient.streamUrl(item.id)` on the saved server.
  /// * `webdav`   — `server.baseUrl` resolved against [id] (the WebDAV href)
  ///   plus a freshly built Authorization header.
  /// * `local`    — [localFilePath] when the file still exists.
  /// * `external` — internet radio or any unknown source; the URL cannot be
  ///   rebuilt, so the entry is dropped on restore instead of being played
  ///   with a stale or broken address.
  final String sourceType;
  final String id;
  final String title;
  final String? artist;
  final String? album;
  final String? albumId;
  final String? artistId;
  final int? durationMs;

  /// Subsonic cover-art id; the signed artwork URL is regenerated, never
  /// stored.
  final String? coverArtId;

  /// Compatibility getter for queues created before the field was renamed.
  @Deprecated('Use coverArtId')
  String? get artworkId => coverArtId;

  /// Absolute path of a downloaded file; persisted instead of the `file:`
  /// URI so a moved cache root can still be detected on restore.
  final String? localFilePath;

  /// Classifies a runtime item for persistence. Never persists credentials:
  /// [PlayableItem.streamUrl] and [PlayableItem.headers] are dropped here.
  static PersistedPlayableItem fromPlayable(
    PlayableItem item, {
    required String sourceType,
  }) {
    String? localFilePath;
    if (item.streamUrl.startsWith('file:')) {
      try {
        localFilePath = Uri.parse(item.streamUrl).toFilePath();
      } on FormatException {
        localFilePath = null;
      }
    }
    return PersistedPlayableItem(
      sourceType: sourceType,
      id: item.id,
      title: item.title,
      artist: item.artist,
      album: item.album,
      albumId: item.albumId,
      artistId: item.artistId,
      durationMs: item.duration?.inMilliseconds,
      coverArtId: item.coverArtId,
      localFilePath: localFilePath,
    );
  }

  /// Old builds persisted the raw [PlayableItem] JSON (with `streamUrl` and
  /// `headers`). Reads only the non-sensitive metadata out of it and drops
  /// everything else, so an upgrade never restores credentials to disk-bound
  /// state.
  factory PersistedPlayableItem.fromLegacyJson(
    Map<String, dynamic> json, {
    required String sourceType,
  }) {
    final streamUrl = json['streamUrl']?.toString() ?? '';
    String? localFilePath;
    if (streamUrl.startsWith('file:')) {
      try {
        localFilePath = Uri.parse(streamUrl).toFilePath();
      } on FormatException {
        localFilePath = null;
      }
    }
    return PersistedPlayableItem(
      sourceType: sourceType,
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      artist: json['artist']?.toString(),
      album: json['album']?.toString(),
      albumId: json['albumId']?.toString(),
      artistId: json['artistId']?.toString(),
      durationMs: json['durationMs'] is num
          ? (json['durationMs'] as num).toInt()
          : null,
      coverArtId:
          (json['coverArtId'] ?? json['artworkId'])?.toString() ??
          _coverArtIdFromCacheKey(json['artworkCacheKey']?.toString()),
      localFilePath: localFilePath,
    );
  }

  /// Legacy entries stored the raw runtime item JSON, recognisable by the
  /// presence of the (now forbidden) `streamUrl` key.
  static bool isLegacyJson(Map<String, dynamic> json) =>
      json.containsKey('streamUrl');

  Map<String, Object?> toJson() => <String, Object?>{
    'sourceType': sourceType,
    'id': id,
    'title': title,
    if (artist != null) 'artist': artist,
    if (album != null) 'album': album,
    if (albumId != null) 'albumId': albumId,
    if (artistId != null) 'artistId': artistId,
    if (durationMs != null) 'durationMs': durationMs,
    if (coverArtId != null) 'coverArtId': coverArtId,
    if (localFilePath != null) 'localFilePath': localFilePath,
  };

  factory PersistedPlayableItem.fromJson(Map<String, dynamic> json) {
    return PersistedPlayableItem(
      sourceType: json['sourceType']?.toString() ?? '',
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      artist: json['artist']?.toString(),
      album: json['album']?.toString(),
      albumId: json['albumId']?.toString(),
      artistId: json['artistId']?.toString(),
      durationMs: json['durationMs'] is num
          ? (json['durationMs'] as num).toInt()
          : null,
      coverArtId: (json['coverArtId'] ?? json['artworkId'])?.toString(),
      localFilePath: json['localFilePath']?.toString(),
    );
  }

  /// Rebuilds a playable runtime item from persisted metadata plus the
  /// freshly generated stream address.
  PlayableItem toPlayable({
    required String streamUrl,
    Map<String, String>? headers,
    String? artworkUrl,
    String? artworkCacheKey,
  }) {
    return PlayableItem(
      id: id,
      title: title,
      streamUrl: streamUrl,
      artist: artist,
      album: album,
      albumId: albumId,
      artistId: artistId,
      coverArtId: coverArtId,
      artworkUrl: artworkUrl,
      artworkCacheKey: artworkCacheKey,
      duration: durationMs == null ? null : Duration(milliseconds: durationMs!),
      headers: headers,
    );
  }

  static const artworkCacheKeyPrefix = 'cover_';
  static const artworkCacheKeySuffix = '_600';

  static String? _coverArtIdFromCacheKey(String? cacheKey) {
    if (cacheKey == null ||
        !cacheKey.startsWith(artworkCacheKeyPrefix) ||
        !cacheKey.endsWith(artworkCacheKeySuffix)) {
      return null;
    }
    final id = cacheKey.substring(
      artworkCacheKeyPrefix.length,
      cacheKey.length - artworkCacheKeySuffix.length,
    );
    return id.isEmpty ? null : id;
  }
}
