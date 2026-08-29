import 'package:drift/drift.dart';

class Servers extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get name => text()();

  TextColumn get baseUrl => text()();

  TextColumn get username => text()();

  // MVP storage. Move this field to secure storage before shipping.
  TextColumn get password => text()();

  TextColumn get token => text().nullable()();

  /// Server protocol family. `null` for rows created before this column
  /// existed; those are treated as Subsonic-compatible (Navidrome included).
  TextColumn get type => text().nullable()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

class RecentPlays extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get songId => text()();

  IntColumn get serverId => integer()();

  // Denormalized song metadata so the history can render without a
  // per-song server round trip. Nullable for rows recorded by older builds.
  TextColumn get title => text().nullable()();

  TextColumn get artist => text().nullable()();

  // Extra denormalized metadata so history, top-played and the player can
  // render and navigate (album/artist) without a server round trip.
  TextColumn get album => text().nullable()();

  TextColumn get albumId => text().nullable()();

  TextColumn get artistId => text().nullable()();

  TextColumn get coverArtId => text().nullable()();

  DateTimeColumn get playedAt => dateTime().withDefault(currentDateAndTime)();
}

class PlaybackStates extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get serverId => integer().nullable()();

  TextColumn get queueJson => text()();

  IntColumn get currentIndex => integer()();

  IntColumn get positionMs => integer()();

  TextColumn get loopMode => text().withDefault(const Constant('off'))();

  BoolColumn get shuffle => boolean().withDefault(const Constant(false))();

  RealColumn get volume => real().withDefault(const Constant(1.0))();

  RealColumn get speed => real().withDefault(const Constant(1.0))();

  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

class SearchHistory extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get keyword => text()();

  DateTimeColumn get searchedAt => dateTime().withDefault(currentDateAndTime)();
}

class Settings extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get themeMode => text().withDefault(const Constant('system'))();

  IntColumn get seedColorValue =>
      integer().withDefault(const Constant(0xfff48fb1))();

  BoolColumn get equalizerEnabled =>
      boolean().withDefault(const Constant(false))();

  TextColumn get equalizerGainsJson =>
      text().withDefault(const Constant('[0,0,0,0,0]'))();

  TextColumn get equalizerPreset =>
      text().withDefault(const Constant('flat'))();

  // Sensitive token storage for development. Move credentials to secure
  // platform storage before production distribution.
  TextColumn get listenBrainzToken => text().nullable()();

  BoolColumn get listenBrainzEnabled =>
      boolean().withDefault(const Constant(false))();

  BoolColumn get lyricsOverlayEnabled =>
      boolean().withDefault(const Constant(false))();

  /// When enabled, the currently playing song and its timed lyrics are pushed
  /// to the Lyricon status-bar lyrics center service (requires LSPosed +
  /// Lyricon on the device). Degrades silently when Lyricon is not installed.
  BoolColumn get statusBarLyricsEnabled =>
      boolean().withDefault(const Constant(false))();

  /// When enabled, the Android equalizer `AudioPipeline` is not attached to the
  /// audio player. Used as a diagnostic toggle to rule out the equalizer as the
  /// cause of silent playback on some devices.
  BoolColumn get safeAudioMode => boolean().withDefault(const Constant(true))();

  /// `zh`, `en`, or `system`. Defaults to simplified Chinese.
  TextColumn get localeCode => text().withDefault(const Constant('zh'))();

  BoolColumn get membershipActive =>
      boolean().withDefault(const Constant(false))();

  // null = 未激活；'code' = 激活码；'star' = Star 诚信开关
  TextColumn get membershipMethod => text().nullable()();
}

class Downloads extends Table {
  TextColumn get songId => text()();

  /// Composite key with [songId]: the same song id can exist on several
  /// servers, and their downloads must not overwrite each other.
  @override
  Set<Column> get primaryKey => {serverId, songId};

  IntColumn get serverId => integer()();

  TextColumn get title => text()();

  TextColumn get artist => text().nullable()();

  TextColumn get album => text().nullable()();

  TextColumn get filePath => text()();

  TextColumn get coverArtId => text().nullable()();

  TextColumn get ext => text().withDefault(const Constant('mp3'))();

  IntColumn get bytes => integer().withDefault(const Constant(0))();

  TextColumn get status => text().withDefault(const Constant('downloading'))();

  RealColumn get progress => real().withDefault(const Constant(0.0))();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

class CachedAlbums extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get serverId => integer()();

  TextColumn get albumId => text()();

  TextColumn get payload => text()();

  DateTimeColumn get fetchedAt => dateTime().withDefault(currentDateAndTime)();
}

class CachedArtists extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get serverId => integer()();

  TextColumn get artistId => text()();

  TextColumn get payload => text()();

  DateTimeColumn get fetchedAt => dateTime().withDefault(currentDateAndTime)();
}

/// Per-server daily recommendation cache. One row keyed by `serverId`
/// (primary key) holds the songs recommended for a single calendar date.
/// The next day simply overwrites the previous row.
class DailyRecommends extends Table {
  IntColumn get serverId => integer()();

  TextColumn get date => text()();

  TextColumn get songsJson => text()();

  @override
  Set<Column> get primaryKey => {serverId};
}
