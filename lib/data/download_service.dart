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
    Future<Directory>? downloadsRoot,
  }) : _dio = dio ?? Dio(),
       _downloadsRootOverride = downloadsRoot {
    // .part files left behind by an interrupted transfer are never valid;
    // this instance owns the server directory now, so clear them.
    unawaited(_cleanupStaleParts());
  }

  final AppDatabase database;
  final SubsonicClient client;
  final int serverId;
  final Dio _dio;
  final int maxConcurrent;
  final Future<Directory>? _downloadsRootOverride;

  final List<_DownloadTask> _pending = <_DownloadTask>[];
  final Map<String, _DownloadTask> _active = <String, _DownloadTask>{};
  final Map<String, _DownloadTask> _tasks = <String, _DownloadTask>{};
  bool _disposed = false;
  bool _draining = false;

  /// Root of the on-disk download area. Tests inject a temporary directory;
  /// production uses the application documents directory.
  Future<Directory> _downloadsRoot() async {
    final override = _downloadsRootOverride;
    if (override != null) {
      return override;
    }
    final directory = await getApplicationDocumentsDirectory();
    return Directory('${directory.path}/downloads');
  }

  /// Canonical, server-isolated location of a finished download:
  /// `<downloads-root>/<serverId>/<songId>.<ext>`.
  File _finalFile(String songId, String ext, Directory root) {
    final serverDirectory = Directory('${root.path}/$serverId');
    return File('${serverDirectory.path}/${Uri.encodeComponent(songId)}.$ext');
  }

  static bool _isValidLength(File file) {
    try {
      return file.existsSync() && file.lengthSync() > 0;
    } on FileSystemException {
      return false;
    }
  }

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

  /// Cancels a queued or active download. A canceled item is kept as a
  /// `cancelled` record until the user deletes it, so the UI can explain what
  /// happened.
  Future<void> cancel(String songId) async {
    final task = _tasks[songId];
    if (task == null) {
      return;
    }
    task.cancelled = true;
    if (_pending.remove(task)) {
      await database.updateDownload(
        songId: songId,
        serverId: serverId,
        status: 'cancelled',
      );
      _finish(task);
      _drain();
      return;
    }
    task.cancelToken?.cancel('Canceled by user');
  }

  /// Deletes the record and file. Pass [serverId] explicitly when deleting a
  /// row that belongs to another server (the downloads screen lists every
  /// server); it defaults to this service's server.
  Future<void> delete(String songId, {int? serverId}) async {
    final effectiveServerId = serverId ?? this.serverId;
    final existing = await database.getDownload(
      songId,
      serverId: effectiveServerId,
    );
    final task = _tasks[songId];
    if (task != null && this.serverId == effectiveServerId) {
      await cancel(songId);
      try {
        await task.completer.future;
      } catch (_) {
        // Deletion should still remove the record after a failed transfer.
      }
    }
    final paths = <String?>[
      existing?.filePath,
      if (existing?.filePath != null) '${existing!.filePath}.part',
    ];
    for (final path in paths) {
      if (path == null) {
        continue;
      }
      try {
        final file = File(path);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (_) {
        // A locked file must not block removing the record.
      }
    }
    await database.deleteDownload(songId, serverId: effectiveServerId);
  }

  Future<String?> completedPathForSong(String songId) async {
    final download = await database.getCompletedDownload(
      songId,
      serverId: serverId,
    );
    if (download == null) {
      return null;
    }
    final resolved = await _resolveCompletedFile(download);
    if (resolved == null) {
      await database.updateDownload(
        songId: songId,
        serverId: serverId,
        status: 'failed',
      );
      return null;
    }
    return resolved;
  }

  Future<Map<String, String>> completedDownloadPaths() {
    return database.getCompletedDownloadPaths(serverId);
  }

  /// Locates a usable file for a completed record:
  ///
  /// 1. the canonical server-scoped path,
  /// 2. the recorded path from before the per-server layout existed, which is
  ///    then migrated into the canonical location,
  /// 3. nothing — the caller marks the record failed.
  Future<String?> _resolveCompletedFile(Download download) async {
    final root = await _downloadsRoot();
    final canonical = _finalFile(download.songId, download.ext, root);
    if (_isValidLength(canonical)) {
      if (download.filePath != canonical.path) {
        await database.updateDownload(
          songId: download.songId,
          serverId: serverId,
          filePath: canonical.path,
        );
      }
      return canonical.path;
    }
    final recorded = File(download.filePath);
    if (_isValidLength(recorded)) {
      if (await _migrateLegacyFile(
        legacy: recorded,
        canonical: canonical,
        songId: download.songId,
      )) {
        return canonical.path;
      }
      return recorded.path;
    }
    return null;
  }

  /// Moves a pre-v14 flat-layout file into the server-scoped directory.
  /// Returns false when the move failed; the recorded location stays valid.
  Future<bool> _migrateLegacyFile({
    required File legacy,
    required File canonical,
    required String songId,
  }) async {
    try {
      await canonical.parent.create(recursive: true);
      try {
        await legacy.rename(canonical.path);
      } on FileSystemException {
        // Different volumes: fall back to a copy + delete.
        await legacy.copy(canonical.path);
        await legacy.delete();
      }
      await database.updateDownload(
        songId: songId,
        serverId: serverId,
        filePath: canonical.path,
      );
      return true;
    } catch (_) {
      return false;
    }
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
    File? partFile;
    try {
      final root = await _downloadsRoot();
      final ext = _safeSuffix(song.suffix);
      final finalFile = _finalFile(song.id, ext, root);
      partFile = File('${finalFile.path}.part');

      // Resume shortcut: only a record already marked completed together with
      // a valid file counts as done. A stray file without a completed record
      // may be a partial transfer from an interrupted run and is discarded.
      final existing = await database.getDownload(song.id, serverId: serverId);
      if (existing?.status == 'completed') {
        if (_isValidLength(finalFile)) {
          await database.updateDownload(
            songId: song.id,
            serverId: serverId,
            bytes: await finalFile.length(),
            progress: 1,
            status: 'completed',
          );
          _finish(task);
          return;
        }
        final legacy = File(existing!.filePath);
        if (existing.filePath != finalFile.path && _isValidLength(legacy)) {
          // Pre-v14 layout: migrate the finished file instead of re-downloading.
          if (await _migrateLegacyFile(
            legacy: legacy,
            canonical: finalFile,
            songId: song.id,
          )) {
            await database.updateDownload(
              songId: song.id,
              serverId: serverId,
              bytes: await finalFile.length(),
              progress: 1,
              status: 'completed',
            );
            _finish(task);
            return;
          }
        }
      }

      if (task.cancelled) {
        await database.updateDownload(
          songId: song.id,
          serverId: serverId,
          status: 'cancelled',
        );
        _finish(task);
        return;
      }

      await finalFile.parent.create(recursive: true);
      if (await partFile.exists()) {
        await partFile.delete();
      }

      await database.upsertDownload(
        songId: song.id,
        serverId: serverId,
        title: song.title,
        artist: song.artist,
        album: song.album,
        filePath: finalFile.path,
        coverArtId: song.coverArt,
        ext: ext,
        status: 'downloading',
      );

      task.cancelToken = CancelToken();
      // Content-Length reported by the server; null when the server streams
      // without a length, in which case the transfer is accepted as-is.
      int? expectedLength;
      var lastUpdate = DateTime.fromMillisecondsSinceEpoch(0);
      await _dio.download(
        client.streamUrl(song.id),
        partFile.path,
        cancelToken: task.cancelToken,
        onReceiveProgress: (received, total) {
          if (total > 0) {
            expectedLength = total;
          }
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
              serverId: serverId,
              bytes: received,
              progress: progress,
              status: 'downloading',
            ),
          );
        },
      );

      final downloadedLength = await partFile.length();
      if (task.cancelled) {
        await _discardPart(partFile);
        await database.updateDownload(
          songId: song.id,
          serverId: serverId,
          status: 'cancelled',
        );
        _finish(task);
        return;
      }
      if (expectedLength != null && downloadedLength != expectedLength) {
        await _discardPart(partFile);
        await database.updateDownload(
          songId: song.id,
          serverId: serverId,
          bytes: downloadedLength,
          status: 'failed',
        );
        _finish(
          task,
          error: StateError(
            'downloaded length $downloadedLength does not match '
            'Content-Length $expectedLength',
          ),
        );
        return;
      }
      // Move the validated .part into place; only now is the download
      // complete.
      await partFile.rename(finalFile.path);
      await database.updateDownload(
        songId: song.id,
        serverId: serverId,
        bytes: downloadedLength,
        progress: 1,
        status: 'completed',
      );
      _finish(task);
    } catch (error, stackTrace) {
      if (partFile != null) {
        await _discardPart(partFile);
      }
      final cancelled = task.cancelled || _isCanceled(error);
      await database.updateDownload(
        songId: song.id,
        serverId: serverId,
        status: cancelled ? 'cancelled' : 'failed',
      );
      if (cancelled) {
        _finish(task);
      } else {
        _finish(task, error: error, stackTrace: stackTrace);
      }
    }
  }

  Future<void> _discardPart(File partFile) async {
    try {
      if (await partFile.exists()) {
        await partFile.delete();
      }
    } catch (_) {
      // A leftover .part is cleaned up on the next start.
    }
  }

  Future<void> _cleanupStaleParts() async {
    try {
      final root = await _downloadsRoot();
      final directory = Directory('${root.path}/$serverId');
      if (!await directory.exists()) {
        return;
      }
      await for (final entity in directory.list()) {
        if (entity is File && entity.path.endsWith('.part')) {
          await entity.delete().catchError((_) => entity);
        }
      }
    } catch (_) {
      // Diagnostics cleanup only; never affects downloads.
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
