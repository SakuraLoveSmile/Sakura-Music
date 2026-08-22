import 'package:subsonic_api/subsonic_api.dart';

import 'audio_player_service.dart';
import '../data/download_manager.dart';

PlayableItem playableItemForSong(
  SubsonicClient client,
  Song song, {
  String? fallbackAlbum,
  String? fallbackCoverArt,
}) {
  final coverArt = song.coverArt ?? fallbackCoverArt;
  return PlayableItem(
    id: song.id,
    title: song.title,
    artist: song.artist,
    album: song.album ?? fallbackAlbum,
    artworkUrl: coverArt == null
        ? null
        : client.coverArtUrl(coverArt, size: 600),
    artworkCacheKey: coverArt == null ? null : 'cover_${coverArt}_600',
    duration: song.duration == null ? null : Duration(seconds: song.duration!),
    streamUrl: client.streamUrl(song.id),
  );
}

List<PlayableItem> playableItemsForSongs(
  SubsonicClient client,
  List<Song> songs, {
  String? fallbackAlbum,
  String? fallbackCoverArt,
}) {
  return songs
      .map(
        (song) => playableItemForSong(
          client,
          song,
          fallbackAlbum: fallbackAlbum,
          fallbackCoverArt: fallbackCoverArt,
        ),
      )
      .toList(growable: false);
}

Future<PlayableItem> playableItemForSongWithLocalFile(
  SubsonicClient client,
  DownloadManager? downloads,
  Song song, {
  String? fallbackAlbum,
  String? fallbackCoverArt,
}) async {
  final remote = playableItemForSong(
    client,
    song,
    fallbackAlbum: fallbackAlbum,
    fallbackCoverArt: fallbackCoverArt,
  );
  final localPath = await downloads?.completedPathForSong(song.id);
  return localPath == null ? remote : _withLocalPath(remote, localPath);
}

Future<List<PlayableItem>> playableItemsForSongsWithLocalFiles(
  SubsonicClient client,
  DownloadManager? downloads,
  List<Song> songs, {
  String? fallbackAlbum,
  String? fallbackCoverArt,
}) async {
  // Queue construction performs one database read for the whole list and no
  // per-song file stat. The single-song builder above remains the validating
  // path for an item that is about to start playback.
  final localPaths =
      await downloads?.completedDownloadPaths() ?? const <String, String>{};
  return songs
      .map((song) {
        final remote = playableItemForSong(
          client,
          song,
          fallbackAlbum: fallbackAlbum,
          fallbackCoverArt: fallbackCoverArt,
        );
        final localPath = localPaths[song.id];
        return localPath == null ? remote : _withLocalPath(remote, localPath);
      })
      .toList(growable: false);
}

PlayableItem _withLocalPath(PlayableItem remote, String localPath) {
  return PlayableItem(
    id: remote.id,
    title: remote.title,
    streamUrl: Uri.file(localPath).toString(),
    artist: remote.artist,
    album: remote.album,
    artworkUrl: remote.artworkUrl,
    artworkCacheKey: remote.artworkCacheKey,
    duration: remote.duration,
  );
}
