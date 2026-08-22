import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramusic/audio/playable_item_builder.dart';
import 'package:sakuramusic/data/db/app_database.dart';
import 'package:sakuramusic/data/download_service.dart';
import 'package:subsonic_api/subsonic_api.dart';

void main() {
  test('persists download progress and terminal states', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    await database.upsertDownload(
      songId: 'song-1',
      serverId: 1,
      title: 'Sakura',
      artist: 'Artist',
      album: 'Album',
      filePath: '/tmp/song-1.mp3',
      coverArtId: null,
      ext: 'mp3',
    );
    await database.updateDownload(
      songId: 'song-1',
      bytes: 512,
      progress: .5,
      status: 'downloading',
    );
    final downloading = await database.getDownload('song-1');
    expect(downloading?.bytes, 512);
    expect(downloading?.progress, .5);

    await database.updateDownload(
      songId: 'song-1',
      bytes: 1024,
      progress: 1,
      status: 'completed',
    );
    expect(
      (await database.getCompletedDownload('song-1'))?.status,
      'completed',
    );
  });

  test('uses a completed local file when building a playable item', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final file = File(
      '${Directory.systemTemp.path}/sakuramusic-download-test.mp3',
    );
    await file.writeAsBytes(<int>[0, 1, 2]);
    addTearDown(() async {
      if (await file.exists()) {
        await file.delete();
      }
    });

    await database.upsertDownload(
      songId: 'song-2',
      serverId: 1,
      title: 'Offline',
      artist: 'Artist',
      album: 'Album',
      filePath: file.path,
      coverArtId: null,
      ext: 'mp3',
      status: 'completed',
      bytes: 3,
      progress: 1,
    );
    final service = DownloadService(
      database: database,
      client: SubsonicClient(
        baseUrl: 'https://music.example.test',
        username: 'demo',
        password: 'password',
      ),
      serverId: 1,
    );
    addTearDown(service.dispose);

    final item = await playableItemForSongWithLocalFile(
      service.client,
      service,
      const Song(id: 'song-2', title: 'Offline'),
    );
    expect(item.streamUrl, Uri.file(file.path).toString());
  });
}
