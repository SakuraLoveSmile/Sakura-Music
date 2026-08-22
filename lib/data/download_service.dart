import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:subsonic_api/subsonic_api.dart';

import '../core/providers.dart';
import 'db/app_database.dart';
import 'server_repository.dart';

class DownloadService {
  DownloadService({
    required this.database,
    required this.client,
    required this.serverId,
    Dio? dio,
    this.maxConcurrent = 2,
  }) : _dio = dio ?? Dio();

  final AppDatabase database;
  final SubsonicClient client;
  final int serverId;
  final Dio _dio;
  final int maxConcurrent;

  final List<_DownloadTask> _pending = <_DownloadTask>[];
  final Map<String, _DownloadTask> _active = <String, _DownloadTask>{};
  final Map<String, _DownloadTask> _tasks = <String, _DownloadTask>{};
  bool _disposed = false;
  bool _draining = false;

  /// Adds a song to the queue. At most [maxConcurrent] downloads run at once.
  /// The returned future completes when this song reaches a terminal state.
  Future<void> downloadSong(Song song) {
    if (_disposed) {
      return Future<void>.error(StateError('Download service is disposed'));
    }
    if (song.id.trim().isEmpty) {
      return Future<void>.error(ArgumentError.value(song.id, 'song.id'));
    }
    final existing = _tasks[song.id];
    if (existing != null) {
      return existing.completer.future;
    }
    final task = _DownloadTask(song);
    _tasks[song.id] = task;
    _pending.add(task);
    _drain();
    return task.completer.future;
  }

  /// Cancels a queued or active download. A canceled item is kept as a failed
  /// record until the user deletes it, so the UI can explain what happened.
  Future<void> cancel(String songId) async {
    final task = _tasks[songId];
    if (task == null) {
      return;
    }
    task.cancelled = true;
    if (_pending.remove(task)) {
      await database.updateDownload(songId: songId, status: 'failed');
      _finish(task);
      _drain();
      return;
    }
    task.cancelToken?.cancel('Canceled by user');
  }

  Future<void> delete(String songId) async {
    final existing = await database.getDownload(songId, serverId: serverId);
    final task = _tasks[songId];
    if (task != null) {
      await cancel(songId);
      try {
        await task.completer.future;
      } catch (_) {
        // Deletion should still remove the record after a failed transfer.
      }
    }
    final path = existing?.filePath;
    if (path != null) {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    }
    await database.deleteDownload(songId);
  }

  Future<String?> completedPathForSong(String songId) async {
    final download = await database.getCompletedDownload(
      songId,
      serverId: serverId,
    );
    if (download == null) {
      return null;
    }
    final file = File(download.filePath);
    if (!await file.exists() || await file.length() == 0) {
      await database.updateDownload(songId: songId, status: 'failed');
      return null;
    }
    return file.path;
  }

  Future<Map<String, String>> completedDownloadPaths() {
    return database.getCompletedDownloadPaths(serverId);
  }

  void _drain() {
    if (_draining || _disposed) {
      return;
    }
    _draining = true;
    while (_active.length < maxConcurrent && _pending.isNotEmpty) {
      final task = _pending.removeAt(0);
      _active[task.song.id] = task;
      unawaited(_run(task));
    }
    _draining = false;
  }

  Future<void> _run(_DownloadTask task) async {
    final song = task.song;
    try {
      final directory = await getApplicationDocumentsDirectory();
      final downloadsDirectory = Directory('${directory.path}/downloads');
      await downloadsDirectory.create(recursive: true);
      final ext = _safeSuffix(song.suffix);
      final path =
          '${downloadsDirectory.path}/${Uri.encodeComponent(song.id)}.$ext';
      final file = File(path);
      task.cancelToken = CancelToken();

      if (task.cancelled) {
        _finish(task);
        return;
      }

      await database.upsertDownload(
        songId: song.id,
        serverId: serverId,
        title: song.title,
        artist: song.artist,
        album: song.album,
        filePath: path,
        coverArtId: song.coverArt,
        ext: ext,
        status: 'downloading',
      );

      if (await file.exists() && await file.length() > 0) {
        await database.updateDownload(
          songId: song.id,
          bytes: await file.length(),
          progress: 1,
          status: 'completed',
        );
        _finish(task);
        return;
      }

      var lastUpdate = DateTime.fromMillisecondsSinceEpoch(0);
      await _dio.download(
        client.streamUrl(song.id),
        path,
        cancelToken: task.cancelToken,
        onReceiveProgress: (received, total) {
          final now = DateTime.now();
          if (now.difference(lastUpdate) < const Duration(milliseconds: 200)) {
            return;
          }
          lastUpdate = now;
          final progress = total > 0
              ? (received / total).clamp(0, 1).toDouble()
              : 0.0;
          unawaited(
            database.updateDownload(
              songId: song.id,
              bytes: received,
              progress: progress,
              status: 'downloading',
            ),
          );
        },
      );
      if (task.cancelled) {
        await database.updateDownload(songId: song.id, status: 'failed');
      } else {
        await database.updateDownload(
          songId: song.id,
          bytes: await file.length(),
          progress: 1,
          status: 'completed',
        );
      }
      _finish(task);
    } catch (error, stackTrace) {
      await database.updateDownload(songId: song.id, status: 'failed');
      if (task.cancelled || _isCanceled(error)) {
        _finish(task);
      } else {
        _finish(task, error: error, stackTrace: stackTrace);
      }
    }
  }

  void _finish(_DownloadTask task, {Object? error, StackTrace? stackTrace}) {
    _active.remove(task.song.id);
    _tasks.remove(task.song.id);
    if (task.completer.isCompleted) {
      return;
    }
    if (error == null) {
      task.completer.complete();
    } else {
      task.completer.completeError(error, stackTrace);
    }
    _drain();
  }

  static bool _isCanceled(Object error) {
    return error is DioException && error.type == DioExceptionType.cancel;
  }

  static String _safeSuffix(String? suffix) {
    final value = suffix?.trim().toLowerCase();
    if (value == null || !RegExp(r'^[a-z0-9]{1,8}$').hasMatch(value)) {
      return 'mp3';
    }
    return value;
  }

  void dispose() {
    _disposed = true;
    for (final task in _pending.toList(growable: false)) {
      task.cancelled = true;
      _finish(task);
    }
    _pending.clear();
    for (final task in _active.values) {
      task.cancelled = true;
      task.cancelToken?.cancel('Service disposed');
    }
  }
}

class _DownloadTask {
  _DownloadTask(this.song);

  final Song song;
  final Completer<void> completer = Completer<void>();
  CancelToken? cancelToken;
  bool cancelled = false;
}

final downloadServiceProvider = Provider<DownloadService?>((ref) {
  final client = ref.watch(activeSubsonicClientProvider);
  final server = ref.watch(activeServerProvider);
  if (client == null || server == null) {
    return null;
  }
  final service = DownloadService(
    database: ref.watch(databaseProvider),
    client: client,
    serverId: server.id,
  );
  ref.onDispose(service.dispose);
  return service;
});

final downloadManagerProvider = downloadServiceProvider;

final downloadsProvider = StreamProvider<List<Download>>((ref) {
  return ref.watch(databaseProvider).watchAllDownloads();
});
