import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramusic/data/db/app_database.dart';
import 'package:sakuramusic/data/download_service.dart';
import 'package:sakuramusic/audio/playable_item_builder.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:subsonic_api/subsonic_api.dart';

const _songBytes = <int>[1, 2, 3, 4, 5, 6, 7, 8];

/// Abruptly aborts an in-flight HTTP response the way a dropped connection
/// would. Best effort: a response whose headers are already flushed cannot be
/// detached, so closing is the fallback.
Future<void> _abortResponse(HttpRequest request) async {
  try {
    final socket = await request.response.detachSocket();
    socket.destroy();
  } catch (_) {
    try {
      await request.response.close();
    } catch (_) {}
  }
}

/// Starts a loopback HTTP server backed by [handler]; the returned base URL
/// feeds a [SubsonicClient] so `streamUrl` points at the fake server.
Future<(HttpServer, String)> _startServer(
  Future<void> Function(HttpRequest request) handler,
) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  server.listen((request) async {
    try {
      await handler(request);
    } catch (_) {
      await _abortResponse(request);
    }
  });
  return (server, 'http://127.0.0.1:${server.port}');
}

Song _song(String id, {String suffix = 'flac'}) =>
    Song(id: id, title: 'Song $id', suffix: suffix);

AppDatabase _memoryDb() => AppDatabase(NativeDatabase.memory());

void main() {
  group('v13 -> v14 migration', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('download_migration');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test(
      'preserves rows, recovers stale downloads and enforces the new key',
      () async {
        final dbFile = File('${tempDir.path}/legacy.db');
        final fixture = sqlite3.open(dbFile.path);
        const now = 1756000000;
        fixture.execute('''
        CREATE TABLE downloads (
          song_id TEXT NOT NULL PRIMARY KEY,
          server_id INTEGER NOT NULL,
          title TEXT NOT NULL,
          artist TEXT NULL,
          album TEXT NULL,
          file_path TEXT NOT NULL,
          cover_art_id TEXT NULL,
          ext TEXT NOT NULL DEFAULT 'mp3',
          bytes INTEGER NOT NULL DEFAULT 0,
          status TEXT NOT NULL DEFAULT 'downloading',
          progress REAL NOT NULL DEFAULT 0.0,
          created_at INTEGER NOT NULL
        )
      ''');
        fixture.execute('''
        INSERT INTO downloads
          (song_id, server_id, title, artist, album, file_path, cover_art_id,
           ext, bytes, status, progress, created_at)
        VALUES
          ('song-1', 1, 'One', 'Artist', 'Album', '/legacy/song-1.flac', NULL,
           'flac', 100, 'completed', 1.0, $now),
          ('song-2', 2, 'Two', NULL, NULL, '/legacy/song-2.mp3', NULL,
           'mp3', 50, 'completed', 1.0, ${now + 1}),
          ('song-3', 1, 'Three', NULL, NULL, '/legacy/song-3.flac', NULL,
           'flac', 10, 'downloading', 0.1, ${now + 2})
      ''');
        fixture.execute('PRAGMA user_version = 13');
        fixture.dispose();

        final database = AppDatabase(NativeDatabase(dbFile));
        addTearDown(database.close);

        expect(database.schemaVersion, 14);

        // Rows survive the rebuild with their values intact.
        final song1 = await database.getDownload('song-1', serverId: 1);
        expect(song1, isNotNull);
        expect(song1!.status, 'completed');
        expect(song1.filePath, '/legacy/song-1.flac');
        expect(song1.bytes, 100);
        expect(song1.createdAt.millisecondsSinceEpoch ~/ 1000, now);
        final song2 = await database.getDownload('song-2', serverId: 2);
        expect(song2, isNotNull);
        expect(song2!.title, 'Two');

        // The interrupted download moved to failed by the startup recovery and
        // is never treated as completed.
        final song3 = await database.getDownload('song-3', serverId: 1);
        expect(song3!.status, 'failed');
        expect(
          await database.getCompletedDownload('song-3', serverId: 1),
          isNull,
        );

        // The composite key now allows the same song id on a second server.
        await database.upsertDownload(
          songId: 'song-1',
          serverId: 2,
          title: 'One on server 2',
          artist: null,
          album: null,
          filePath: '/other/song-1.flac',
          coverArtId: null,
          ext: 'flac',
          status: 'completed',
        );
        expect(await database.getDownload('song-1', serverId: 1), isNotNull);
        expect(await database.getDownload('song-1', serverId: 2), isNotNull);
        final paths1 = await database.getCompletedDownloadPaths(1);
        final paths2 = await database.getCompletedDownloadPaths(2);
        expect(paths1['song-1'], '/legacy/song-1.flac');
        expect(paths2['song-1'], '/other/song-1.flac');
      },
    );
  });

  group('DownloadService', () {
    late Directory tempDir;
    late AppDatabase database;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('download_service');
      database = _memoryDb();
    });

    tearDown(() async {
      await database.close();
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    DownloadService buildService(int serverId, String baseUrl) {
      final service = DownloadService(
        database: database,
        client: SubsonicClient(
          baseUrl: baseUrl,
          username: 'demo',
          password: 'password',
        ),
        serverId: serverId,
        downloadsRoot: Future.value(tempDir),
      );
      addTearDown(service.dispose);
      return service;
    }

    String canonicalPath(int serverId, String songId, String ext) =>
        '${tempDir.path}/$serverId/${Uri.encodeComponent(songId)}.$ext';

    test('completes a download into the server-scoped directory', () async {
      final (server, baseUrl) = await _startServer((request) async {
        request.response.contentLength = _songBytes.length;
        await request.response.addStream(
          Stream.value(Uint8List.fromList(_songBytes)),
        );
        await request.response.close();
      });
      addTearDown(server.close);

      final service = buildService(11, baseUrl);
      await service.downloadSong(_song('song-1'));

      final finalFile = File(canonicalPath(11, 'song-1', 'flac'));
      expect(await finalFile.exists(), isTrue);
      expect(await finalFile.length(), _songBytes.length);
      expect(await File('${finalFile.path}.part').exists(), isFalse);

      final row = await database.getDownload('song-1', serverId: 11);
      expect(row!.status, 'completed');
      expect(row.filePath, finalFile.path);
      expect(row.bytes, _songBytes.length);
      expect(
        await database.getCompletedDownload('song-1', serverId: 11),
        isNotNull,
      );
    });

    test('accepts a transfer without a Content-Length header', () async {
      final (server, baseUrl) = await _startServer((request) async {
        // No contentLength set: the response is sent chunked.
        await request.response.addStream(
          Stream.value(Uint8List.fromList(_songBytes)),
        );
        await request.response.close();
      });
      addTearDown(server.close);

      final service = buildService(11, baseUrl);
      await service.downloadSong(_song('song-1'));

      expect(
        (await database.getDownload('song-1', serverId: 11))!.status,
        'completed',
      );
    });

    test(
      'marks a length mismatch as failed and never completes the file',
      () async {
        final (server, baseUrl) = await _startServer((request) async {
          // Server advertises more bytes than it actually sends, then closes.
          request.response.contentLength = 100;
          await request.response.addStream(
            Stream.value(Uint8List.fromList(_songBytes)),
          );
          await request.response.close();
        });
        addTearDown(server.close);

        final service = buildService(11, baseUrl);
        // dio surfaces the truncated body as a connection error; the service
        // maps every non-cancelled failure to the failed state.
        await expectLater(
          service.downloadSong(_song('song-1')),
          throwsA(anything),
        );

        expect(
          (await database.getDownload('song-1', serverId: 11))!.status,
          'failed',
        );
        expect(
          await File(canonicalPath(11, 'song-1', 'flac')).exists(),
          isFalse,
        );
        expect(
          await File('${canonicalPath(11, 'song-1', 'flac')}.part').exists(),
          isFalse,
        );
        expect(
          await database.getCompletedDownload('song-1', serverId: 11),
          isNull,
        );
      },
    );

    test(
      'a mid-transfer failure marks the row failed and allows re-download',
      () async {
        var broken = true;
        final (server, baseUrl) = await _startServer((request) async {
          if (broken) {
            request.response.contentLength = 100;
            await request.response.addStream(
              Stream.value(Uint8List.fromList(_songBytes)),
            );
            // End the response before the advertised body is complete: the
            // client sees a truncated transfer.
            await request.response.close();
            return;
          }
          request.response.contentLength = _songBytes.length;
          await request.response.addStream(
            Stream.value(Uint8List.fromList(_songBytes)),
          );
          await request.response.close();
        });
        addTearDown(server.close);

        final service = buildService(11, baseUrl);
        await expectLater(
          service.downloadSong(_song('song-1')),
          throwsA(anything),
        );
        expect(
          (await database.getDownload('song-1', serverId: 11))!.status,
          'failed',
        );

        broken = false;
        await service.downloadSong(_song('song-1'));
        final row = await database.getDownload('song-1', serverId: 11);
        expect(row!.status, 'completed');
        expect(row.bytes, _songBytes.length);
      },
    );

    test(
      'cancelling marks the row cancelled and removes the .part file',
      () async {
        final (server, baseUrl) = await _startServer((request) async {
          request.response.contentLength = 100;
          await request.response.addStream(
            Stream.value(Uint8List.fromList(_songBytes)),
          );
          // Stall so the cancel lands mid-transfer.
          await Future<void>.delayed(const Duration(seconds: 3));
          await request.response.close();
        });
        addTearDown(server.close);

        final service = buildService(11, baseUrl);
        final future = service.downloadSong(_song('song-1'));
        await Future<void>.delayed(const Duration(milliseconds: 100));
        await service.cancel('song-1');
        await future;

        expect(
          (await database.getDownload('song-1', serverId: 11))!.status,
          'cancelled',
        );
        expect(
          await File(canonicalPath(11, 'song-1', 'flac')).exists(),
          isFalse,
        );
        expect(
          await File('${canonicalPath(11, 'song-1', 'flac')}.part').exists(),
          isFalse,
        );
      },
    );

    test('a leftover .part file is never treated as completed', () async {
      final (server, baseUrl) = await _startServer((request) async {
        request.response.contentLength = _songBytes.length;
        await request.response.addStream(
          Stream.value(Uint8List.fromList(_songBytes)),
        );
        await request.response.close();
      });
      addTearDown(server.close);

      // Simulate a crash mid-transfer: a stale .part plus a non-completed row.
      final serverDir = Directory('${tempDir.path}/11');
      await serverDir.create(recursive: true);
      await File(
        '${canonicalPath(11, 'song-1', 'flac')}.part',
      ).writeAsBytes(<int>[9, 9]);
      await database.upsertDownload(
        songId: 'song-1',
        serverId: 11,
        title: 'Song song-1',
        artist: null,
        album: null,
        filePath: canonicalPath(11, 'song-1', 'flac'),
        coverArtId: null,
        ext: 'flac',
        status: 'downloading',
        progress: 0.5,
      );

      final service = buildService(11, baseUrl);
      // The constructor cleans stale .part files for this server.
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(
        await File('${canonicalPath(11, 'song-1', 'flac')}.part').exists(),
        isFalse,
      );

      await service.downloadSong(_song('song-1'));
      final row = await database.getDownload('song-1', serverId: 11);
      expect(row!.status, 'completed');
      expect(row.bytes, _songBytes.length);
    });

    test(
      'downloads for different servers with the same song id coexist',
      () async {
        final (server, baseUrl) = await _startServer((request) async {
          request.response.contentLength = _songBytes.length;
          await request.response.addStream(
            Stream.value(Uint8List.fromList(_songBytes)),
          );
          await request.response.close();
        });
        addTearDown(server.close);

        final serviceA = buildService(1, baseUrl);
        final serviceB = buildService(2, baseUrl);
        await serviceA.downloadSong(_song('shared-song'));
        await serviceB.downloadSong(_song('shared-song'));

        final rowA = await database.getDownload('shared-song', serverId: 1);
        final rowB = await database.getDownload('shared-song', serverId: 2);
        expect(rowA!.status, 'completed');
        expect(rowB!.status, 'completed');
        expect(rowA.filePath, canonicalPath(1, 'shared-song', 'flac'));
        expect(rowB.filePath, canonicalPath(2, 'shared-song', 'flac'));
        expect(
          await File(canonicalPath(1, 'shared-song', 'flac')).exists(),
          isTrue,
        );
        expect(
          await File(canonicalPath(2, 'shared-song', 'flac')).exists(),
          isTrue,
        );
        expect(await database.getCompletedDownloadPaths(1), <String, String>{
          'shared-song': rowA.filePath,
        });
        expect(await database.getCompletedDownloadPaths(2), <String, String>{
          'shared-song': rowB.filePath,
        });
      },
    );

    test(
      're-downloading the same song for the same server keeps one row',
      () async {
        final (server, baseUrl) = await _startServer((request) async {
          request.response.contentLength = _songBytes.length;
          await request.response.addStream(
            Stream.value(Uint8List.fromList(_songBytes)),
          );
          await request.response.close();
        });
        addTearDown(server.close);

        final service = buildService(11, baseUrl);
        await service.downloadSong(_song('song-1'));
        await service.downloadSong(_song('song-1'));

        // Both passes resolve to a single completed row (the composite key
        // upserts instead of duplicating).
        final completed = await database.getCompletedDownloadPaths(11);
        expect(completed.keys, <String>['song-1']);
        final row = await database.getDownload('song-1', serverId: 11);
        expect(row!.bytes, _songBytes.length);
      },
    );

    test('completedPathForSong migrates a legacy flat-layout file', () async {
      final legacyFile = File('${tempDir.path}/legacy-song.flac');
      await legacyFile.writeAsBytes(_songBytes);
      await database.upsertDownload(
        songId: 'song-9',
        serverId: 11,
        title: 'Legacy',
        artist: null,
        album: null,
        filePath: legacyFile.path,
        coverArtId: null,
        ext: 'flac',
        status: 'completed',
        bytes: _songBytes.length,
        progress: 1,
      );

      final service = buildService(11, 'https://music.example.test');
      final path = await service.completedPathForSong('song-9');

      final canonical = File(canonicalPath(11, 'song-9', 'flac'));
      expect(path, canonical.path);
      expect(await canonical.exists(), isTrue);
      expect(await legacyFile.exists(), isFalse);
      expect(
        (await database.getDownload('song-9', serverId: 11))!.filePath,
        canonical.path,
      );

      final item = await playableItemForSongWithLocalFile(
        service.client,
        service,
        const Song(id: 'song-9', title: 'Legacy'),
      );
      expect(item.streamUrl, Uri.file(canonical.path).toString());
    });

    test('a completed record with a vanished file reports failed', () async {
      await database.upsertDownload(
        songId: 'song-10',
        serverId: 11,
        title: 'Gone',
        artist: null,
        album: null,
        filePath: '${tempDir.path}/never-downloaded.flac',
        coverArtId: null,
        ext: 'flac',
        status: 'completed',
        bytes: 100,
        progress: 1,
      );

      final service = buildService(11, 'https://music.example.test');
      expect(await service.completedPathForSong('song-10'), isNull);
      expect(
        (await database.getDownload('song-10', serverId: 11))!.status,
        'failed',
      );
    });
  });
}
