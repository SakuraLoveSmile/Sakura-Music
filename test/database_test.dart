import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramusic/data/db/app_database.dart';

void main() {
  test('persists servers and recent plays through Drift', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    final serverId = await database.insertServer(
      ServersCompanion.insert(
        name: 'Test server',
        baseUrl: 'https://music.example.test',
        username: 'demo',
        password: 'password',
      ),
    );
    final server = await database.getServer(serverId);
    expect(server?.name, 'Test server');
    expect(server?.baseUrl, 'https://music.example.test');

    await database.addRecentPlay(songId: 'song-1', serverId: serverId);
    final recentPlays = await database.select(database.recentPlays).get();
    expect(recentPlays, hasLength(1));
    expect(recentPlays.single.songId, 'song-1');
    expect(recentPlays.single.serverId, serverId);

    await database.recordRecentPlay(songId: 'song-1', serverId: serverId);
    expect(await database.select(database.recentPlays).get(), hasLength(1));

    await database.recordSearch('  sakura  ');
    await database.recordSearch('j-pop');
    await database.recordSearch('sakura');
    expect(await database.getSearchHistory(), <String>['sakura', 'j-pop']);

    await database.saveSettings(themeMode: 'dark', seedColorValue: 0xff7b8fe8);
    final settings = await database.getSettings();
    expect(settings?.themeMode, 'dark');
    expect(settings?.seedColorValue, 0xff7b8fe8);

    await database.saveSettings(
      equalizerEnabled: true,
      equalizerGainsJson: '[1,2,3,4,5]',
      equalizerPreset: 'pop',
      listenBrainzToken: 'token',
      listenBrainzEnabled: true,
    );
    final updatedSettings = await database.getSettings();
    expect(updatedSettings?.equalizerEnabled, isTrue);
    expect(updatedSettings?.equalizerPreset, 'pop');
    expect(updatedSettings?.listenBrainzToken, 'token');
    expect(updatedSettings?.listenBrainzEnabled, isTrue);
  });

  test('loads completed download paths as one server-scoped map', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    await database.upsertDownload(
      songId: 'song-1',
      serverId: 7,
      title: 'One',
      artist: null,
      album: null,
      filePath: '/music/song-1.mp3',
      coverArtId: null,
      ext: 'mp3',
      status: 'completed',
    );
    await database.upsertDownload(
      songId: 'song-2',
      serverId: 7,
      title: 'Two',
      artist: null,
      album: null,
      filePath: '/music/song-2.mp3',
      coverArtId: null,
      ext: 'mp3',
      status: 'downloading',
    );
    await database.upsertDownload(
      songId: 'song-3',
      serverId: 8,
      title: 'Other server',
      artist: null,
      album: null,
      filePath: '/music/song-3.mp3',
      coverArtId: null,
      ext: 'mp3',
      status: 'completed',
    );

    expect(await database.getCompletedDownloadPaths(7), <String, String>{
      'song-1': '/music/song-1.mp3',
    });
  });

  test(
    'batch cache writes replace only the requested server entries',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);

      await database.cacheAlbums(
        serverId: 7,
        payloads: <String, String>{'album-1': 'old', 'album-2': 'keep'},
      );
      await database.cacheAlbums(
        serverId: 7,
        payloads: <String, String>{'album-1': 'new'},
      );
      await database.cacheAlbums(
        serverId: 8,
        payloads: <String, String>{'album-1': 'other-server'},
      );

      final serverSeven = await database.getCachedAlbums(7);
      final serverEight = await database.getCachedAlbums(8);
      expect(
        serverSeven.map((row) => row.payload),
        containsAll(<String>['new', 'keep']),
      );
      expect(serverSeven, hasLength(2));
      expect(serverEight.single.payload, 'other-server');
    },
  );
}
