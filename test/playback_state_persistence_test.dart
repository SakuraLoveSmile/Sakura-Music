import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramusic/audio/audio_player_service.dart';
import 'package:sakuramusic/audio/equalizer_models.dart';
import 'package:sakuramusic/audio/playback_coordinator.dart';
import 'package:sakuramusic/audio/persisted_playable_item.dart';
import 'package:sakuramusic/data/db/app_database.dart';

/// Records every queue mutation so restore behaviour can be asserted.
class _FakeAudioPlayerService implements AudioPlayerService {
  final _controller = StreamController<PlayerSnapshot>.broadcast();
  final List<List<PlayableItem>> setQueueCalls = <List<PlayableItem>>[];
  PlayerSnapshot? _current;

  void emit(PlayerSnapshot snapshot) {
    _current = snapshot;
    _controller.add(snapshot);
  }

  @override
  PlayerSnapshot? get currentSnapshot => _current;

  @override
  Stream<PlayerSnapshot> get snapshot => _controller.stream;

  @override
  Future<void> setQueue(List<PlayableItem> items, {int startIndex = 0}) async {
    setQueueCalls.add(items);
  }

  @override
  Future<void> play() async {}

  @override
  Future<void> pause() async {}

  @override
  Future<void> next() async {}

  @override
  Future<void> previous() async {}

  @override
  Future<void> seek(Duration position) async {}

  @override
  Future<void> setLoopMode(AppLoopMode mode) async {}

  @override
  Future<void> setShuffle(bool enabled) async {}

  @override
  Future<void> playAt(int index) async {}

  @override
  Future<void> insertNext(PlayableItem item) async {}

  @override
  Future<void> removeAt(int index) async {}

  @override
  Future<void> moveItem(int from, int to) async {}

  @override
  Future<void> setVolume(double value) async {}

  @override
  Future<void> setSpeed(double value) async {}

  @override
  Future<bool> setPreferredOutputDevice(int? deviceId) async => false;

  @override
  Future<void> setEqualizer(EqualizerSettings settings) async {}

  @override
  Future<void> dispose() async {}
}

PlayableItem _sensitiveSubsonicItem() {
  return PlayableItem(
    id: 'song-1',
    title: 'Secret Song',
    artist: 'Artist A',
    album: 'Album A',
    albumId: 'al-1',
    artistId: 'ar-1',
    artworkId: 'al-1',
    artworkUrl: 'https://host/rest/getCoverArt?id=al-1&u=admin&t=tok&s=salt',
    artworkCacheKey: 'cover_al-1_600',
    duration: const Duration(milliseconds: 95000),
    streamUrl: 'https://host/rest/stream?id=song-1&u=admin&t=tok&s=salt',
    headers: const <String, String>{'Authorization': 'Basic dXNlcjpwYXNz'},
  );
}

const _legacyQueueJson =
    '[{"id":"song-1","title":"Secret Song","streamUrl":'
    '"https://host/rest/stream?id=song-1&u=admin&t=tok&s=salt",'
    '"artist":"Artist A","album":"Album A","albumId":"al-1","artistId":"ar-1",'
    '"artworkUrl":"https://host/rest/getCoverArt?id=al-1&u=admin&t=tok&s=salt",'
    '"artworkCacheKey":"cover_al-1_600","durationMs":95000,'
    '"headers":{"Authorization":"Basic dXNlcjpwYXNz"}}]';

void main() {
  group('PersistedPlayableItem', () {
    test('serialized form never contains credentials or signed URLs', () {
      final persisted = PersistedPlayableItem.fromPlayable(
        _sensitiveSubsonicItem(),
        sourceType: 'subsonic',
      );
      final json = jsonEncode(persisted.toJson());

      expect(json, isNot(contains('Authorization')));
      expect(json, isNot(contains('Basic')));
      expect(json, isNot(contains('&t=')));
      expect(json, isNot(contains('&s=')));
      expect(json, isNot(contains('streamUrl')));
      expect(json, isNot(contains('headers')));
      expect(json, isNot(contains('artworkUrl')));
      expect(json, isNot(contains('admin')));
      expect(json, isNot(contains('tok')));
    });

    test('round-trips non-sensitive metadata symmetrically', () {
      final persisted = PersistedPlayableItem.fromPlayable(
        _sensitiveSubsonicItem(),
        sourceType: 'subsonic',
      );
      final restored = PersistedPlayableItem.fromJson(
        persisted.toJson().map((key, value) => MapEntry(key, value)),
      );

      expect(restored.sourceType, 'subsonic');
      expect(restored.id, 'song-1');
      expect(restored.title, 'Secret Song');
      expect(restored.artist, 'Artist A');
      expect(restored.album, 'Album A');
      expect(restored.albumId, 'al-1');
      expect(restored.artistId, 'ar-1');
      expect(restored.durationMs, 95000);
      expect(restored.artworkId, 'al-1');
      expect(restored.localFilePath, isNull);
    });

    test('derives localFilePath from a file stream URL', () {
      final item = PlayableItem(
        id: 'song-2',
        title: 'Downloaded',
        streamUrl: Uri.file('/tmp/downloads/song-2.flac').toString(),
      );
      final persisted = PersistedPlayableItem.fromPlayable(
        item,
        sourceType: 'local',
      );
      expect(persisted.localFilePath, '/tmp/downloads/song-2.flac');
      expect(persisted.toJson(), isNot(contains('streamUrl')));
    });

    test('migrates legacy PlayableItem JSON dropping credentials', () {
      final legacy = jsonDecode(_legacyQueueJson) as List;
      final persisted = PersistedPlayableItem.fromLegacyJson(
        (legacy.single as Map).map((k, v) => MapEntry(k.toString(), v)),
        sourceType: 'subsonic',
      );

      final json = jsonEncode(persisted.toJson());
      expect(json, isNot(contains('Authorization')));
      expect(json, isNot(contains('Basic')));
      expect(json, isNot(contains('streamUrl')));
      expect(json, isNot(contains('admin')));

      expect(persisted.id, 'song-1');
      expect(persisted.albumId, 'al-1');
      expect(persisted.artistId, 'ar-1');
      expect(persisted.artworkId, 'al-1');
      expect(persisted.durationMs, 95000);
    });

    test('isLegacyJson detects the old raw item format', () {
      final legacy = jsonDecode(_legacyQueueJson) as List;
      expect(
        PersistedPlayableItem.isLegacyJson(
          (legacy.single as Map).map((k, v) => MapEntry(k.toString(), v)),
        ),
        isTrue,
      );
      expect(
        PersistedPlayableItem.isLegacyJson(
          PersistedPlayableItem.fromPlayable(
            _sensitiveSubsonicItem(),
            sourceType: 'subsonic',
          ).toJson(),
        ),
        isFalse,
      );
    });
  });

  group('PlaybackCoordinator persistence', () {
    late AppDatabase database;

    setUp(() {
      database = AppDatabase(NativeDatabase.memory());
    });

    tearDown(() async {
      await database.close();
    });

    Future<int> addServer({String? type}) {
      return database.insertServer(
        ServersCompanion.insert(
          name: 'Test server',
          baseUrl: 'https://music.example.test',
          username: 'demo',
          password: 'server-password',
          type: Value(type),
        ),
      );
    }

    test(
      'saving a snapshot strips credentials from persisted queue JSON',
      () async {
        final serverId = await addServer();
        final server = await database.getServer(serverId);
        final service = _FakeAudioPlayerService();
        final coordinator = PlaybackCoordinator(
          service: service,
          database: database,
          server: server,
        );
        addTearDown(() => coordinator.dispose());

        // Let the restore pass finish so snapshots are processed.
        await Future<void>.delayed(const Duration(milliseconds: 50));

        service.emit(
          PlayerSnapshot(
            status: PlayerStatus.ready,
            playing: true,
            currentItem: _sensitiveSubsonicItem(),
            currentIndex: 0,
            queue: <PlayableItem>[_sensitiveSubsonicItem()],
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 50));

        // dispose() persists the last snapshot immediately.
        await coordinator.dispose();

        final saved = await database.getPlaybackState();
        expect(saved, isNotNull);
        final queueJson = saved!.queueJson;
        expect(queueJson, isNot(contains('Authorization')));
        expect(queueJson, isNot(contains('Basic')));
        expect(queueJson, isNot(contains('&t=')));
        expect(queueJson, isNot(contains('&s=')));
        expect(queueJson, isNot(contains('streamUrl')));
        expect(queueJson, contains('"sourceType":"subsonic"'));
        expect(queueJson, contains('"albumId":"al-1"'));
        expect(queueJson, contains('"artistId":"ar-1"'));
        expect(queueJson, contains('"artworkId":"al-1"'));
      },
    );

    test('restores a subsonic queue with freshly signed URLs', () async {
      final serverId = await addServer();
      final server = await database.getServer(serverId);
      final persisted = PersistedPlayableItem.fromPlayable(
        _sensitiveSubsonicItem(),
        sourceType: 'subsonic',
      );
      await database.savePlaybackState(
        serverId: serverId,
        queueJson: jsonEncode(<Map<String, Object?>>[persisted.toJson()]),
        currentIndex: 0,
        positionMs: 12000,
        loopMode: 'all',
        shuffle: true,
        volume: 0.5,
        speed: 1.25,
      );

      final service = _FakeAudioPlayerService();
      final coordinator = PlaybackCoordinator(
        service: service,
        database: database,
        server: server,
      );
      addTearDown(() => coordinator.dispose());

      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(service.setQueueCalls, hasLength(1));
      final item = service.setQueueCalls.single.single;
      expect(item.streamUrl, contains('/rest/stream'));
      expect(item.streamUrl, contains('id=song-1'));
      expect(item.streamUrl, contains('u=demo'));
      expect(item.streamUrl, contains('t='));
      expect(item.streamUrl, contains('s='));
      expect(item.headers, isNull);
      expect(item.albumId, 'al-1');
      expect(item.artistId, 'ar-1');
      expect(item.artworkUrl, contains('getCoverArt'));
      expect(item.artworkUrl, contains('id=al-1'));
      expect(item.artworkCacheKey, 'cover_al-1_600');
      expect(item.duration, const Duration(milliseconds: 95000));
    });

    test('migrates a legacy queue and restores regenerated URLs', () async {
      final serverId = await addServer();
      final server = await database.getServer(serverId);
      await database.savePlaybackState(
        serverId: serverId,
        queueJson: _legacyQueueJson,
        currentIndex: 0,
        positionMs: 0,
        loopMode: 'off',
        shuffle: false,
        volume: 1,
        speed: 1,
      );

      final service = _FakeAudioPlayerService();
      final coordinator = PlaybackCoordinator(
        service: service,
        database: database,
        server: server,
      );
      addTearDown(() => coordinator.dispose());

      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(service.setQueueCalls, hasLength(1));
      final item = service.setQueueCalls.single.single;
      // The restored URL is freshly generated, not the persisted one.
      expect(item.streamUrl, contains('id=song-1'));
      expect(item.streamUrl, isNot(contains('t=tok')));
      expect(item.headers, isNull);
      expect(item.albumId, 'al-1');

      // The next save rewrites the state into the sanitized format.
      service.emit(
        PlayerSnapshot(
          status: PlayerStatus.ready,
          currentItem: item,
          currentIndex: 0,
          queue: <PlayableItem>[item],
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await coordinator.dispose();
      final saved = await database.getPlaybackState();
      expect(saved!.queueJson, contains('"sourceType"'));
      expect(saved.queueJson, isNot(contains('streamUrl')));
    });

    test('restores a webdav queue with a fresh Authorization header', () async {
      final serverId = await addServer(type: 'webdav');
      final server = await database.getServer(serverId);
      final persisted = const PersistedPlayableItem(
        sourceType: 'webdav',
        id: '/music/song.flac',
        title: 'Song FLAC',
        artistId: null,
        albumId: null,
      );
      await database.savePlaybackState(
        serverId: serverId,
        queueJson: jsonEncode(<Map<String, Object?>>[persisted.toJson()]),
        currentIndex: 0,
        positionMs: 0,
        loopMode: 'off',
        shuffle: false,
        volume: 1,
        speed: 1,
      );

      final service = _FakeAudioPlayerService();
      final coordinator = PlaybackCoordinator(
        service: service,
        database: database,
        server: server,
      );
      addTearDown(() => coordinator.dispose());

      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(service.setQueueCalls, hasLength(1));
      final item = service.setQueueCalls.single.single;
      expect(item.streamUrl, 'https://music.example.test/music/song.flac');
      final headers = item.headers!;
      expect(headers, contains('Authorization'));
      final auth = headers['Authorization']!;
      expect(auth, startsWith('Basic '));
      expect(auth, isNot(contains('server-password')));
      // base64('demo:server-password') decodes back to the credentials used
      // for the fresh header only; nothing from disk was reused.
      expect(
        utf8.decode(base64Decode(auth.substring(6))),
        'demo:server-password',
      );
    });

    test('keeps local downloads and drops unrebuildable entries', () async {
      final tempDir = await Directory.systemTemp.createTemp('dl_test');
      addTearDown(() => tempDir.delete(recursive: true));
      final file = File('${tempDir.path}/song-3.flac');
      await file.writeAsBytes(<int>[1, 2, 3]);

      final serverId = await addServer();
      final server = await database.getServer(serverId);
      final entries = <PersistedPlayableItem>[
        PersistedPlayableItem(
          sourceType: 'local',
          id: 'song-3',
          title: 'Local Song',
          localFilePath: file.path,
        ),
        const PersistedPlayableItem(
          sourceType: 'external',
          id: 'radio-1',
          title: 'Radio Station',
        ),
        PersistedPlayableItem(
          sourceType: 'local',
          id: 'song-4',
          title: 'Vanished Download',
          localFilePath: '${tempDir.path}/missing.flac',
        ),
      ];
      await database.savePlaybackState(
        serverId: serverId,
        queueJson: jsonEncode(<Map<String, Object?>>[
          for (final entry in entries) entry.toJson(),
        ]),
        currentIndex: 2,
        positionMs: 0,
        loopMode: 'off',
        shuffle: false,
        volume: 1,
        speed: 1,
      );

      final service = _FakeAudioPlayerService();
      final coordinator = PlaybackCoordinator(
        service: service,
        database: database,
        server: server,
      );
      addTearDown(() => coordinator.dispose());

      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(service.setQueueCalls, hasLength(1));
      final items = service.setQueueCalls.single;
      expect(items, hasLength(1));
      expect(items.single.id, 'song-3');
      expect(items.single.streamUrl, startsWith('file:'));
    });

    test('does not restore a queue saved for a different server', () async {
      final serverId = await addServer();
      final server = await database.getServer(serverId);
      final persisted = PersistedPlayableItem.fromPlayable(
        _sensitiveSubsonicItem(),
        sourceType: 'subsonic',
      );
      await database.savePlaybackState(
        serverId: serverId + 1,
        queueJson: jsonEncode(<Map<String, Object?>>[persisted.toJson()]),
        currentIndex: 0,
        positionMs: 0,
        loopMode: 'off',
        shuffle: false,
        volume: 1,
        speed: 1,
      );

      final service = _FakeAudioPlayerService();
      final coordinator = PlaybackCoordinator(
        service: service,
        database: database,
        server: server,
      );
      addTearDown(() => coordinator.dispose());

      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(service.setQueueCalls, isEmpty);
    });
  });
}
