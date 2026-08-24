import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'tables.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    Servers,
    RecentPlays,
    PlaybackStates,
    SearchHistory,
    Settings,
    Downloads,
    CachedAlbums,
    CachedArtists,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
    : super(executor ?? driftDatabase(name: 'sakuramusic'));

  @override
  int get schemaVersion => 10;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.createTable(playbackStates);
      }
      if (from < 3) {
        await m.createTable(searchHistory);
      }
      if (from < 4) {
        await m.createTable(settings);
      }
      if (from < 5) {
        await m.createTable(downloads);
        await m.createTable(cachedAlbums);
        await m.createTable(cachedArtists);
      }
      if (from < 6) {
        // The V1.5 download model changes the primary key from an internal
        // row id to songId and adds server/extension/progress fields. This is
        // development-era storage, so rebuilding this table is safer than a
        // fragile cross-platform primary-key migration.
        await m.deleteTable('downloads');
        await m.createTable(downloads);
      }
      if (from >= 4 && from < 7) {
        await m.addColumn(settings, settings.equalizerEnabled);
        await m.addColumn(settings, settings.equalizerGainsJson);
        await m.addColumn(settings, settings.equalizerPreset);
        await m.addColumn(settings, settings.listenBrainzToken);
        await m.addColumn(settings, settings.listenBrainzEnabled);
      }
      if (from >= 4 && from < 8) {
        // One upgrade adds both v8 columns: the lyrics-overlay switch and the
        // UI locale. Tables created fresh (from < 4) already include them.
        await m.addColumn(settings, settings.lyricsOverlayEnabled);
        await m.addColumn(settings, settings.localeCode);
      }
      if (from < 9) {
        // The V9 history model adds denormalized song metadata. Existing rows
        // only carry opaque server ids, so rebuilding this development-era
        // table is cleaner than rendering unresolvable ids forever.
        await m.deleteTable('recent_plays');
        await m.createTable(recentPlays);
      }
      if (from >= 4 && from < 10) {
        // V10 diagnostic toggle: disables the Android equalizer pipeline.
        await m.addColumn(settings, settings.safeAudioMode);
      }
    },
  );

  Future<List<Server>> getAllServers() => select(servers).get();

  Stream<List<Server>> watchAllServers() => select(servers).watch();

  Future<Server?> getServer(int id) {
    return (select(
      servers,
    )..where((table) => table.id.equals(id))).getSingleOrNull();
  }

  Future<int> insertServer(ServersCompanion server) {
    return into(servers).insert(server);
  }

  Future<bool> updateServer(int id, ServersCompanion server) {
    return (update(servers)..where((table) => table.id.equals(id)))
        .write(server)
        .then((rows) => rows > 0);
  }

  Future<int> deleteServer(int id) {
    return (delete(servers)..where((table) => table.id.equals(id))).go();
  }

  Future<int> addRecentPlay({
    required String songId,
    required int serverId,
    String? title,
    String? artist,
  }) {
    return recordRecentPlay(
      songId: songId,
      serverId: serverId,
      title: title,
      artist: artist,
    );
  }

  Future<int> recordRecentPlay({
    required String songId,
    required int serverId,
    String? title,
    String? artist,
  }) async {
    final now = DateTime.now();
    final cutoff = now.subtract(const Duration(minutes: 5));
    final existing =
        await (select(recentPlays)
              ..where(
                (table) =>
                    table.songId.equals(songId) &
                    table.serverId.equals(serverId) &
                    table.playedAt.isBiggerOrEqualValue(cutoff),
              )
              ..limit(1))
            .getSingleOrNull();
    final id = existing == null
        ? await into(recentPlays).insert(
            RecentPlaysCompanion.insert(songId: songId, serverId: serverId),
          )
        : existing.id;
    if (existing != null) {
      await (update(recentPlays)..where((table) => table.id.equals(id))).write(
        RecentPlaysCompanion(playedAt: Value(now)),
      );
    }
    // Keep the freshest metadata the player has seen for this row.
    if (title != null || artist != null) {
      await (update(recentPlays)..where((table) => table.id.equals(id)))
          .write(
        RecentPlaysCompanion(
          title: title == null ? const Value.absent() : Value(title),
          artist: artist == null ? const Value.absent() : Value(artist),
        ),
      );
    }

    final all =
        await (select(recentPlays)
              ..orderBy(<OrderingTerm Function(RecentPlays)>[
                (table) => OrderingTerm.desc(table.playedAt),
              ]))
            .get();
    if (all.length > 200) {
      final staleIds = all.skip(200).map((play) => play.id).toList();
      await (delete(
        recentPlays,
      )..where((table) => table.id.isIn(staleIds))).go();
    }
    return id;
  }

  Future<List<String>> getRecentPlayIds({int? serverId, int limit = 20}) async {
    final rows = await getRecentPlays(serverId: serverId, limit: limit);
    return rows.map((row) => row.songId).toList(growable: false);
  }

  Future<List<RecentPlay>> getRecentPlays({
    int? serverId,
    int limit = 20,
  }) {
    final query = select(recentPlays)
      ..orderBy(<OrderingTerm Function(RecentPlays)>[
        (table) => OrderingTerm.desc(table.playedAt),
      ])
      ..limit(limit);
    if (serverId != null) {
      query.where((table) => table.serverId.equals(serverId));
    }
    return query.get();
  }

  Future<PlaybackState?> getPlaybackState() {
    return (select(
      playbackStates,
    )..where((table) => table.id.equals(1))).getSingleOrNull();
  }

  Future<void> savePlaybackState({
    required int? serverId,
    required String queueJson,
    required int currentIndex,
    required int positionMs,
    required String loopMode,
    required bool shuffle,
    required double volume,
    required double speed,
  }) async {
    await into(playbackStates).insertOnConflictUpdate(
      PlaybackStatesCompanion.insert(
        id: const Value(1),
        serverId: Value(serverId),
        queueJson: queueJson,
        currentIndex: currentIndex,
        positionMs: positionMs,
        loopMode: Value(loopMode),
        shuffle: Value(shuffle),
        volume: Value(volume),
        speed: Value(speed),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<List<String>> getSearchHistory({int limit = 20}) async {
    final rows =
        await (select(searchHistory)
              ..orderBy(<OrderingTerm Function(SearchHistory)>[
                (table) => OrderingTerm.desc(table.searchedAt),
                (table) => OrderingTerm.desc(table.id),
              ])
              ..limit(limit))
            .get();
    return rows.map((row) => row.keyword).toList(growable: false);
  }

  Future<void> recordSearch(String keyword) async {
    final normalized = keyword.trim();
    if (normalized.isEmpty) {
      return;
    }
    await (delete(
      searchHistory,
    )..where((table) => table.keyword.equals(normalized))).go();
    await into(
      searchHistory,
    ).insert(SearchHistoryCompanion.insert(keyword: normalized));
    final rows =
        await (select(searchHistory)
              ..orderBy(<OrderingTerm Function(SearchHistory)>[
                (table) => OrderingTerm.desc(table.searchedAt),
                (table) => OrderingTerm.desc(table.id),
              ]))
            .get();
    if (rows.length > 20) {
      final staleIds = rows.skip(20).map((row) => row.id).toList();
      await (delete(
        searchHistory,
      )..where((table) => table.id.isIn(staleIds))).go();
    }
  }

  Future<int> clearSearchHistory() {
    return delete(searchHistory).go();
  }

  Future<Setting?> getSettings() {
    return (select(
      settings,
    )..where((table) => table.id.equals(1))).getSingleOrNull();
  }

  Future<void> saveSettings({
    String? themeMode,
    int? seedColorValue,
    bool? equalizerEnabled,
    String? equalizerGainsJson,
    String? equalizerPreset,
    String? listenBrainzToken,
    bool? listenBrainzEnabled,
    bool clearListenBrainzToken = false,
    bool? lyricsOverlayEnabled,
    bool? safeAudioMode,
    String? localeCode,
  }) async {
    final current = await getSettings();
    await into(settings).insertOnConflictUpdate(
      SettingsCompanion.insert(
        id: const Value(1),
        themeMode: Value(themeMode ?? current?.themeMode ?? 'system'),
        seedColorValue: Value(
          seedColorValue ?? current?.seedColorValue ?? 0xfff48fb1,
        ),
        equalizerEnabled: Value(
          equalizerEnabled ?? current?.equalizerEnabled ?? false,
        ),
        equalizerGainsJson: Value(
          equalizerGainsJson ?? current?.equalizerGainsJson ?? '[0,0,0,0,0]',
        ),
        equalizerPreset: Value(
          equalizerPreset ?? current?.equalizerPreset ?? 'flat',
        ),
        listenBrainzToken: Value(
          clearListenBrainzToken
              ? null
              : listenBrainzToken ?? current?.listenBrainzToken,
        ),
        listenBrainzEnabled: Value(
          listenBrainzEnabled ?? current?.listenBrainzEnabled ?? false,
        ),
        lyricsOverlayEnabled: Value(
          lyricsOverlayEnabled ?? current?.lyricsOverlayEnabled ?? false,
        ),
        safeAudioMode: Value(
          safeAudioMode ?? current?.safeAudioMode ?? false,
        ),
        localeCode: Value(localeCode ?? current?.localeCode ?? 'zh'),
      ),
    );
  }

  Stream<List<Download>> watchAllDownloads() {
    return (select(downloads)..orderBy(<OrderingTerm Function(Downloads)>[
          (table) => OrderingTerm.desc(table.createdAt),
        ]))
        .watch();
  }

  Future<Download?> getCompletedDownload(String songId, {int? serverId}) {
    final query = select(downloads)
      ..where(
        (table) =>
            table.songId.equals(songId) & table.status.equals('completed'),
      )
      ..limit(1);
    if (serverId != null) {
      query.where((table) => table.serverId.equals(serverId));
    }
    return query.getSingleOrNull();
  }

  /// Returns completed download paths in one query without touching the file
  /// system. Queue construction can trust these records and validate only the
  /// item that is actually being started.
  Future<Map<String, String>> getCompletedDownloadPaths(int serverId) async {
    final rows =
        await (select(downloads)..where(
              (table) =>
                  table.serverId.equals(serverId) &
                  table.status.equals('completed'),
            ))
            .get();
    return <String, String>{
      for (final row in rows)
        if (row.filePath.isNotEmpty) row.songId: row.filePath,
    };
  }

  Future<void> upsertDownload({
    required String songId,
    required int serverId,
    required String title,
    required String? artist,
    required String? album,
    required String filePath,
    required String? coverArtId,
    required String ext,
    String status = 'downloading',
    int bytes = 0,
    double progress = 0,
  }) async {
    await into(downloads).insertOnConflictUpdate(
      DownloadsCompanion.insert(
        songId: songId,
        serverId: serverId,
        title: title,
        artist: Value(artist),
        album: Value(album),
        filePath: filePath,
        coverArtId: Value(coverArtId),
        ext: Value(ext),
        status: Value(status),
        bytes: Value(bytes),
        progress: Value(progress.clamp(0, 1)),
      ),
    );
  }

  Future<Download?> getDownload(String songId, {int? serverId}) {
    final query = select(downloads)
      ..where((table) => table.songId.equals(songId))
      ..limit(1);
    if (serverId != null) {
      query.where((table) => table.serverId.equals(serverId));
    }
    return query.getSingleOrNull();
  }

  Future<bool> updateDownload({
    required String songId,
    int? bytes,
    double? progress,
    String? status,
  }) async {
    final values = DownloadsCompanion(
      bytes: bytes == null ? const Value.absent() : Value(bytes),
      progress: progress == null
          ? const Value.absent()
          : Value(progress.clamp(0, 1)),
      status: status == null ? const Value.absent() : Value(status),
    );
    final count = await (update(
      downloads,
    )..where((table) => table.songId.equals(songId))).write(values);
    return count > 0;
  }

  Future<int> deleteDownload(String songId) {
    return (delete(
      downloads,
    )..where((table) => table.songId.equals(songId))).go();
  }

  Future<void> cacheAlbum({
    required int serverId,
    required String albumId,
    required String payload,
  }) async {
    await cacheAlbums(
      serverId: serverId,
      payloads: <String, String>{albumId: payload},
    );
  }

  Future<void> cacheAlbums({
    required int serverId,
    required Map<String, String> payloads,
  }) async {
    if (payloads.isEmpty) {
      return;
    }
    final ids = payloads.keys.toList(growable: false);
    await transaction(() async {
      await (delete(cachedAlbums)..where(
            (table) =>
                table.serverId.equals(serverId) & table.albumId.isIn(ids),
          ))
          .go();
      await batch((batch) {
        batch.insertAll(
          cachedAlbums,
          payloads.entries
              .map(
                (entry) => CachedAlbumsCompanion.insert(
                  serverId: serverId,
                  albumId: entry.key,
                  payload: entry.value,
                ),
              )
              .toList(growable: false),
        );
      });
    });
  }

  Future<void> cacheArtist({
    required int serverId,
    required String artistId,
    required String payload,
  }) async {
    await cacheArtists(
      serverId: serverId,
      payloads: <String, String>{artistId: payload},
    );
  }

  Future<void> cacheArtists({
    required int serverId,
    required Map<String, String> payloads,
  }) async {
    if (payloads.isEmpty) {
      return;
    }
    final ids = payloads.keys.toList(growable: false);
    await transaction(() async {
      await (delete(cachedArtists)..where(
            (table) =>
                table.serverId.equals(serverId) & table.artistId.isIn(ids),
          ))
          .go();
      await batch((batch) {
        batch.insertAll(
          cachedArtists,
          payloads.entries
              .map(
                (entry) => CachedArtistsCompanion.insert(
                  serverId: serverId,
                  artistId: entry.key,
                  payload: entry.value,
                ),
              )
              .toList(growable: false),
        );
      });
    });
  }

  Future<List<CachedAlbum>> getCachedAlbums(int serverId) {
    return (select(cachedAlbums)
          ..where((table) => table.serverId.equals(serverId))
          ..orderBy(<OrderingTerm Function(CachedAlbums)>[
            (table) => OrderingTerm.desc(table.fetchedAt),
          ]))
        .get();
  }

  Future<List<CachedArtist>> getCachedArtists(int serverId) {
    return (select(cachedArtists)
          ..where((table) => table.serverId.equals(serverId))
          ..orderBy(<OrderingTerm Function(CachedArtists)>[
            (table) => OrderingTerm.desc(table.fetchedAt),
          ]))
        .get();
  }
}
