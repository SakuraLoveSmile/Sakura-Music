// Isolated UI preview. This entry point never calls the production bootstrap,
// opens the application database/keychain, or starts an audio engine.
//
// flutter run -d macos -t tool/glasmio_preview.dart
//   --dart-define=GLASS_PREVIEW_WIDTH=390
//   --dart-define=GLASS_PREVIEW_HEIGHT=844
//   --dart-define=GLASS_PREVIEW_MOBILE=true
// Optional: GLASS_PREVIEW_ROUTE=/player, GLASS_PREVIEW_EMPTY=true.
// Desktop shortcuts: Cmd+1/2/3/4 = desktop/mobile/small/compact desktop;
// Cmd+0 = home, Cmd+5 = player. These exist only in this preview entry point.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:subsonic_api/subsonic_api.dart';
import 'package:window_manager/window_manager.dart';

import 'package:sakuramusic/audio/audio_player_provider.dart';
import 'package:sakuramusic/audio/audio_player_service.dart';
import 'package:sakuramusic/audio/equalizer_models.dart';
import 'package:sakuramusic/audio/playable_item_builder.dart';
import 'package:sakuramusic/core/feedback/feedback_config.dart';
import 'package:sakuramusic/core/providers.dart';
import 'package:sakuramusic/core/security/credential_store.dart';
import 'package:sakuramusic/core/theme.dart';
import 'package:sakuramusic/core/update/update_providers.dart';
import 'package:sakuramusic/data/db/app_database.dart';
import 'package:sakuramusic/data/download_service.dart';
import 'package:sakuramusic/data/server_repository.dart';
import 'package:sakuramusic/l10n/app_localizations.dart';
import 'package:sakuramusic/router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final database = AppDatabase(NativeDatabase.memory());
  final library = _PreviewLibrary();
  final localServer = await library.start();
  final baseUrl = 'http://127.0.0.1:${localServer.port}';
  final client = SubsonicClient(
    baseUrl: baseUrl,
    username: 'preview',
    password: 'not-a-real-credential',
  );
  const empty = bool.fromEnvironment('GLASS_PREVIEW_EMPTY');
  if (!empty) {
    await database.insertServer(
      ServersCompanion.insert(
        name: '玻璃实验室 · 演示音乐',
        baseUrl: baseUrl,
        username: 'preview',
        password: '',
      ),
    );
  }
  final player = _PreviewPlayer(playableItemsForSongs(client, library.songs));

  if (Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
    await windowManager.ensureInitialized();
    final width =
        double.tryParse(const String.fromEnvironment('GLASS_PREVIEW_WIDTH')) ??
        1280;
    final height =
        double.tryParse(const String.fromEnvironment('GLASS_PREVIEW_HEIGHT')) ??
        800;
    await windowManager.waitUntilReadyToShow(
      WindowOptions(
        size: Size(width, height),
        minimumSize: const Size(320, 600),
        center: true,
        title: 'SakuraMusic · Glass Preview',
      ),
      () async {
        await windowManager.show();
        await windowManager.focus();
      },
    );
  }

  runApp(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWith((ref) {
          ref.onDispose(database.close);
          return database;
        }),
        credentialStoreProvider.overrideWithValue(_PreviewCredentials()),
        activeSubsonicClientProvider.overrideWith((ref) {
          ref.onDispose(() => unawaited(localServer.close(force: true)));
          return empty ? null : client;
        }),
        audioPlayerProvider.overrideWith((ref) {
          ref.onDispose(player.dispose);
          return player;
        }),
        // Downloads and update actions must not touch application files or
        // external services, even if their controls are opened in this demo.
        downloadServiceProvider.overrideWithValue(null),
        updateControllerProvider.overrideWith(_PreviewUpdateController.new),
        feedbackServiceConfigProvider.overrideWithValue(null),
        appVersionProvider.overrideWith(
          (ref) async => PackageInfo(
            appName: 'SakuraMusic Glass Preview',
            packageName: 'local.sakuramusic.glass-preview',
            version: '0.0.0-preview',
            buildNumber: '0',
          ),
        ),
      ],
      child: const _PreviewApp(),
    ),
  );
}

class _PreviewApp extends ConsumerStatefulWidget {
  const _PreviewApp();

  @override
  ConsumerState<_PreviewApp> createState() => _PreviewAppState();
}

class _PreviewAppState extends ConsumerState<_PreviewApp> {
  bool _mobilePlatform = const bool.fromEnvironment('GLASS_PREVIEW_MOBILE');
  late final SemanticsHandle _semanticsHandle;

  @override
  void initState() {
    super.initState();
    // Keep route semantics available while inspecting this standalone demo,
    // even when the platform stops requesting them between route transitions.
    _semanticsHandle = WidgetsBinding.instance.ensureSemantics();
    const route = String.fromEnvironment('GLASS_PREVIEW_ROUTE');
    const empty = bool.fromEnvironment('GLASS_PREVIEW_EMPTY');
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ref.read(serversProvider.future);
      if (!mounted) return;
      ref
          .read(appRouterProvider)
          .go(
            route.isNotEmpty
                ? route
                : empty
                ? '/welcome'
                : '/home',
          );
    });
  }

  @override
  void dispose() {
    _semanticsHandle.dispose();
    super.dispose();
  }

  Future<void> _resizePreview(Size size, {required bool mobile}) async {
    setState(() => _mobilePlatform = mobile);
    await windowManager.setSize(size);
    await windowManager.center();
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop =
        Platform.isMacOS || Platform.isWindows || Platform.isLinux;
    final baseTheme = buildTheme(Brightness.dark);
    final theme = isDesktop
        ? baseTheme.copyWith(
            platform: _mobilePlatform
                ? TargetPlatform.android
                : TargetPlatform.macOS,
          )
        : baseTheme;
    final app = MaterialApp.router(
      title: 'SakuraMusic · Glass Preview',
      debugShowCheckedModeBanner: false,
      theme: theme,
      darkTheme: theme,
      themeMode: ThemeMode.dark,
      locale: const Locale('zh'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: ref.watch(appRouterProvider),
    );
    if (!isDesktop) {
      return app;
    }
    final shortcuts = CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.digit1, meta: true): () =>
            unawaited(_resizePreview(const Size(1280, 800), mobile: false)),
        const SingleActivator(LogicalKeyboardKey.digit2, meta: true): () =>
            unawaited(_resizePreview(const Size(390, 844), mobile: true)),
        const SingleActivator(LogicalKeyboardKey.digit3, meta: true): () =>
            unawaited(_resizePreview(const Size(320, 740), mobile: true)),
        const SingleActivator(LogicalKeyboardKey.digit4, meta: true): () =>
            unawaited(_resizePreview(const Size(960, 640), mobile: false)),
        const SingleActivator(LogicalKeyboardKey.digit0, meta: true): () =>
            ref.read(appRouterProvider).go('/home'),
        const SingleActivator(LogicalKeyboardKey.digit5, meta: true): () =>
            ref.read(appRouterProvider).go('/player'),
      },
      child: Focus(autofocus: true, child: app),
    );
    if (!Platform.isMacOS) return shortcuts;
    // Native menu shortcuts also work when a route or a text field owns focus.
    // This menu exists only in this isolated developer entry point.
    return PlatformMenuBar(
      menus: [
        const PlatformMenu(
          label: 'SakuraMusic',
          menus: [
            PlatformProvidedMenuItem(type: PlatformProvidedMenuItemType.quit),
          ],
        ),
        PlatformMenu(
          label: '预览',
          menus: [
            for (final preset in [
              (
                label: '桌面 1280 × 800',
                size: const Size(1280, 800),
                key: LogicalKeyboardKey.digit1,
                mobile: false,
              ),
              (
                label: '手机 390 × 844',
                size: const Size(390, 844),
                key: LogicalKeyboardKey.digit2,
                mobile: true,
              ),
              (
                label: '手机 320 × 740',
                size: const Size(320, 740),
                key: LogicalKeyboardKey.digit3,
                mobile: true,
              ),
              (
                label: '桌面 960 × 640',
                size: const Size(960, 640),
                key: LogicalKeyboardKey.digit4,
                mobile: false,
              ),
            ])
              PlatformMenuItem(
                label: preset.label,
                shortcut: SingleActivator(preset.key, meta: true),
                onSelected: () => unawaited(
                  _resizePreview(preset.size, mobile: preset.mobile),
                ),
              ),
            PlatformMenuItem(
              label: '发现页',
              shortcut: const SingleActivator(
                LogicalKeyboardKey.digit0,
                meta: true,
              ),
              onSelected: () => ref.read(appRouterProvider).go('/home'),
            ),
            PlatformMenuItem(
              label: '播放器',
              shortcut: const SingleActivator(
                LogicalKeyboardKey.digit5,
                meta: true,
              ),
              onSelected: () => ref.read(appRouterProvider).go('/player'),
            ),
          ],
        ),
      ],
      child: shortcuts,
    );
  }
}

class _PreviewCredentials implements CredentialStore {
  final _passwords = <int, String>{};
  String? _token;

  @override
  String? cachedServerPassword(int serverId) =>
      _passwords[serverId] ?? 'not-a-real-credential';
  @override
  Future<String?> readServerPassword(int serverId) async =>
      cachedServerPassword(serverId);
  @override
  Future<void> writeServerPassword(int serverId, String password) async {
    _passwords[serverId] = password;
  }

  @override
  Future<void> deleteServerPassword(int serverId) async {
    _passwords.remove(serverId);
  }

  @override
  Future<String?> readListenBrainzToken() async => _token;
  @override
  Future<void> writeListenBrainzToken(String? token) async => _token = token;
  @override
  Future<void> warmUp(Iterable<int> serverIds) async {}
}

class _PreviewUpdateController extends UpdateController {
  @override
  Future<void> check({bool silent = false}) async {
    state = const UpdateState(
      status: UpdateStatus.error,
      errorMessage: '演示预览不连接更新服务。',
    );
  }

  @override
  Future<void> startDownload() async => check();
  @override
  Future<void> retryDownload() async => check();
  @override
  Future<void> install() async => check();
  @override
  Future<void> openReleasePage() async => check();
}

/// Only loopback requests reach this synthetic music library. Its original
/// geometric artwork is generated in memory; no third-party media is used.
class _PreviewLibrary {
  static const _titles = [
    '沿着月光慢慢走',
    '海面上的最后一束光',
    'Stay a Little Longer',
    'Blue Hour',
    '微风经过你的窗口',
    'City of Stars',
    'Letters to Tomorrow',
    '听见森林',
    'After the Rain',
    'A Very Long Song Title for the Smallest Window',
    '潮汐之间',
    'Warm Light',
  ];
  static const _albumNames = [
    'Midnight Tides',
    '海与远方',
    'Velvet Skies',
    'Quiet Hours',
    'Afterglow',
    '山间来信',
    'The Blue Room',
    'Slow Motion',
  ];
  static const _artistNames = ['星河回声', '岛屿来信', 'Luna Harbor', 'Soft Focus'];
  late final songs = List<Song>.generate(
    24,
    (i) => Song(
      id: 'glass-preview-song-$i',
      title: _titles[i % _titles.length],
      artist: _artistNames[(i ~/ 3) % _artistNames.length],
      artistId: 'glass-preview-artist-${(i ~/ 3) % 4}',
      album: _albumNames[i ~/ 3],
      albumId: 'glass-preview-album-${i ~/ 3}',
      coverArt: 'glass-preview-cover-${i ~/ 3}',
      duration: 214 + i * 3,
      track: i % 3 + 1,
      genre: i.isEven ? 'Ambient' : 'Indie Pop',
      year: 2026,
      suffix: 'flac',
      bitRate: 960,
    ),
  );
  late final albums = List<Album>.generate(
    8,
    (i) => Album(
      id: 'glass-preview-album-$i',
      name: _albumNames[i],
      artist: _artistNames[i % 4],
      artistId: 'glass-preview-artist-${i % 4}',
      coverArt: 'glass-preview-cover-$i',
      songCount: 3,
      duration: 690,
      year: 2026,
      genre: i.isEven ? 'Ambient' : 'Indie Pop',
      songs: songs.skip(i * 3).take(3).toList(),
    ),
  );
  late final artists = List<Artist>.generate(
    4,
    (i) => Artist(
      id: 'glass-preview-artist-$i',
      name: _artistNames[i],
      coverArt: 'glass-preview-cover-$i',
      albumCount: 2,
      albums: albums
          .where((album) => album.artistId == 'glass-preview-artist-$i')
          .toList(),
    ),
  );
  late final _playlists = List<Map<String, Object?>>.generate(
    3,
    (i) => {
      'id': 'glass-preview-playlist-$i',
      'name': ['给夜晚的歌', '慢慢醒来', '一路向海'][i],
      'songCount': 8,
      'duration': 1840,
      'coverArt': 'glass-preview-cover-${i + 3}',
      'owner': 'preview',
      'changed': '2026-11-04T00:00:00',
      'entry': songs.skip(i * 8).take(8).map((s) => s.toJson()).toList(),
    },
  );
  final _starredSongs = <String>{
    'glass-preview-song-1',
    'glass-preview-song-4',
  };
  final _starredAlbums = <String>{'glass-preview-album-2'};
  final _starredArtists = <String>{'glass-preview-artist-0'};
  final _artwork = <Uint8List>[];
  int _randomOffset = 0;

  Future<HttpServer> start() async {
    for (var i = 0; i < 8; i++) {
      _artwork.add(await _paintCover(i));
    }
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      try {
        final endpoint = request.uri.pathSegments.last;
        final query = request.uri.queryParameters;
        if (endpoint == 'getCoverArt') {
          final index = int.tryParse(query['id']?.split('-').last ?? '') ?? 0;
          request.response.headers.contentType = ContentType('image', 'png');
          request.response.add(_artwork[index % _artwork.length]);
        } else {
          request.response.headers.contentType = ContentType.json;
          request.response.write(
            jsonEncode({
              'subsonic-response': {
                'status': 'ok',
                'version': '1.16.1',
                ..._response(endpoint, query),
              },
            }),
          );
        }
      } catch (error) {
        request.response.statusCode = HttpStatus.internalServerError;
        request.response.write('Preview fixture error: $error');
      } finally {
        await request.response.close();
      }
    });
    return server;
  }

  Map<String, Object?> _response(String endpoint, Map<String, String> query) {
    final id = query['id'];
    switch (endpoint) {
      case 'ping':
      case 'scrobble':
        return {};
      case 'getRandomSongs':
        final count = int.tryParse(query['size'] ?? '') ?? 12;
        final batch = List<Song>.generate(
          math.min(count, songs.length),
          (i) => songs[(i + _randomOffset) % songs.length],
        );
        _randomOffset = (_randomOffset + 3) % songs.length;
        return {
          'randomSongs': {'song': batch.map((s) => s.toJson()).toList()},
        };
      case 'getAlbumList':
        final offset = int.tryParse(query['offset'] ?? '') ?? 0;
        final size = int.tryParse(query['size'] ?? '') ?? 50;
        return {
          'albumList': {
            'album': albums
                .skip(offset)
                .take(size)
                .map((a) => a.toJson())
                .toList(),
          },
        };
      case 'getAlbum':
        return {'album': albums.firstWhere((a) => a.id == id).toJson()};
      case 'getArtists':
        return {
          'artists': {
            'index': [
              {'name': '演示', 'artist': artists.map((a) => a.toJson()).toList()},
            ],
          },
        };
      case 'getArtist':
        return {'artist': artists.firstWhere((a) => a.id == id).toJson()};
      case 'getArtistInfo2':
        return {
          'artistInfo2': {
            'biography': '这里是用于界面预览的虚构音乐人。',
            'similarArtist': artists.map((a) => a.toJson()).toList(),
          },
        };
      case 'getSimilarSongs2':
        return {
          'similarSongs2': {
            'song': songs.take(6).map((s) => s.toJson()).toList(),
          },
        };
      case 'getGenres':
        return {
          'genres': {
            'genre': [
              {'value': 'Ambient', 'songCount': 12, 'albumCount': 4},
              {'value': 'Indie Pop', 'songCount': 12, 'albumCount': 4},
            ],
          },
        };
      case 'getSongsByGenre':
        return {
          'songsByGenre': {
            'song': songs
                .where((s) => s.genre == query['genre'])
                .map((s) => s.toJson())
                .toList(),
          },
        };
      case 'getMusicFolders':
        return {
          'musicFolders': {
            'musicFolder': [
              {'id': 1, 'name': '演示音乐'},
            ],
          },
        };
      case 'getPlaylists':
        return {
          'playlists': {'playlist': _playlists},
        };
      case 'getPlaylist':
        return {'playlist': _playlists.firstWhere((p) => p['id'] == id)};
      case 'search3':
        final needle = (query['query'] ?? '').toLowerCase();
        return {
          'searchResult3': {
            'song': songs
                .where(
                  (s) => '${s.title} ${s.artist} ${s.album}'
                      .toLowerCase()
                      .contains(needle),
                )
                .map((s) => s.toJson())
                .toList(),
            'album': albums
                .where((a) => a.name.toLowerCase().contains(needle))
                .map((a) => a.toJson())
                .toList(),
            'artist': artists
                .where((a) => a.name.toLowerCase().contains(needle))
                .map((a) => a.toJson())
                .toList(),
          },
        };
      case 'getStarred2':
        return {
          'starred2': {
            'song': songs
                .where((s) => _starredSongs.contains(s.id))
                .map((s) => s.toJson())
                .toList(),
            'album': albums
                .where((a) => _starredAlbums.contains(a.id))
                .map((a) => a.toJson())
                .toList(),
            'artist': artists
                .where((a) => _starredArtists.contains(a.id))
                .map((a) => a.toJson())
                .toList(),
          },
        };
      case 'star':
      case 'unstar':
        for (final pair in [
          (query['id'], _starredSongs),
          (query['albumId'], _starredAlbums),
          (query['artistId'], _starredArtists),
        ]) {
          final key = pair.$1;
          if (key != null) {
            if (endpoint == 'star') {
              pair.$2.add(key);
            } else {
              pair.$2.remove(key);
            }
          }
        }
        return {};
      case 'getLyricsBySongId':
        return {
          'lyricsList': {
            'structuredLyrics': [
              {
                'lang': 'zh',
                'synced': true,
                'line': List.generate(
                  14,
                  (i) => {
                    'start': i * 15000,
                    'value': [
                      '沿着月光慢慢走',
                      '把城市留在身后',
                      '潮汐带来温柔的风',
                      '让每个音符自由',
                    ][i % 4],
                  },
                ),
              },
            ],
          },
        };
      default:
        return {
          'status': 'failed',
          'error': {'code': 0, 'message': '此操作未包含在隔离预览中。'},
        };
    }
  }

  Future<Uint8List> _paintCover(int index) async {
    const palettes = [
      [Color(0xFF15344F), Color(0xFFD9A3A7)],
      [Color(0xFF006C82), Color(0xFFABE2D0)],
      [Color(0xFF392358), Color(0xFFCC90C2)],
      [Color(0xFF803E38), Color(0xFFF0BD80)],
      [Color(0xFF2C295D), Color(0xFFFFA68D)],
      [Color(0xFF1D534A), Color(0xFFBBD8B4)],
      [Color(0xFF175591), Color(0xFF94C8F7)],
      [Color(0xFF61503B), Color(0xFFE9DBC3)],
    ];
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final colors = palettes[index];
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, 600, 600),
      Paint()
        ..shader = ui.Gradient.linear(
          const Offset(40, 0),
          const Offset(550, 600),
          colors,
        ),
    );
    canvas.drawCircle(
      Offset(365 - index * 12, 180 + index * 5),
      92,
      Paint()..color = colors.last.withValues(alpha: 0.7),
    );
    for (var i = 0; i < 7; i++) {
      final path = Path()
        ..moveTo(-60, 340 + i * 44.0)
        ..cubicTo(190, 180 + i * 50.0, 330, 610 - i * 13.0, 670, 280 + i * 50.0)
        ..lineTo(670, 640)
        ..lineTo(-60, 640)
        ..close();
      canvas.drawPath(
        path,
        Paint()..color = colors.first.withValues(alpha: 0.2 + i * 0.09),
      );
    }
    final paragraph =
        (ui.ParagraphBuilder(
                ui.ParagraphStyle(fontSize: 18, fontWeight: FontWeight.w500),
              )
              ..pushStyle(
                ui.TextStyle(
                  color: Colors.white.withValues(alpha: 0.8),
                  letterSpacing: 4,
                ),
              )
              ..addText('SAKURA / ${index.toString().padLeft(2, '0')}'))
            .build()
          ..layout(const ui.ParagraphConstraints(width: 520));
    canvas.drawParagraph(paragraph, const Offset(40, 44));
    final picture = recorder.endRecording();
    final image = await picture.toImage(600, 600);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final result = Uint8List.fromList(bytes!.buffer.asUint8List());
    image.dispose();
    picture.dispose();
    return result;
  }
}

/// Stateful transport simulation: controls and queue editing emit the same
/// snapshots as the real player, but no stream URL is ever opened.
class _PreviewPlayer implements AudioPlayerService {
  _PreviewPlayer(List<PlayableItem> items) : _queue = List.of(items) {
    _timer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (!_playing || _queue.isEmpty) return;
      _position += Duration(milliseconds: (500 * _speed).round());
      if (_position >= (_item?.duration ?? const Duration(minutes: 4))) {
        if (_loopMode == AppLoopMode.one) {
          _position = Duration.zero;
        } else {
          unawaited(next());
        }
      }
      _emit();
    });
  }
  final _events = StreamController<PlayerSnapshot>.broadcast();
  List<PlayableItem> _queue;
  int _index = 0;
  bool _playing = false;
  bool _shuffle = false;
  AppLoopMode _loopMode = AppLoopMode.off;
  Duration _position = const Duration(seconds: 43);
  double _volume = 0.72;
  double _speed = 1;
  late final Timer _timer;
  PlayableItem? get _item => _queue.isEmpty ? null : _queue[_index];
  @override
  Stream<PlayerSnapshot> get snapshot => _events.stream;
  @override
  PlayerSnapshot get currentSnapshot => PlayerSnapshot(
    status: _item == null ? PlayerStatus.idle : PlayerStatus.ready,
    playing: _playing,
    position: _position,
    duration: _item?.duration,
    currentIndex: _item == null ? null : _index,
    currentItem: _item,
    queue: List.unmodifiable(_queue),
    loopMode: _loopMode,
    shuffle: _shuffle,
    volume: _volume,
    speed: _speed,
  );
  void _emit() => _events.add(currentSnapshot);
  @override
  Future<void> setQueue(List<PlayableItem> items, {int startIndex = 0}) async {
    _queue = List.of(items);
    _index = items.isEmpty ? 0 : startIndex.clamp(0, items.length - 1);
    _position = Duration.zero;
    _emit();
  }

  @override
  Future<void> play() async {
    _playing = _item != null;
    _emit();
  }

  @override
  Future<void> pause() async {
    _playing = false;
    _emit();
  }

  @override
  Future<void> next() async {
    if (_queue.isEmpty) return;
    _index = (_index + 1) % _queue.length;
    _position = Duration.zero;
    _emit();
  }

  @override
  Future<void> previous() async {
    if (_queue.isEmpty) return;
    _index = (_index - 1) % _queue.length;
    _position = Duration.zero;
    _emit();
  }

  @override
  Future<void> seek(Duration position) async {
    _position = Duration(
      milliseconds: position.inMilliseconds.clamp(
        0,
        _item?.duration?.inMilliseconds ?? 0,
      ),
    );
    _emit();
  }

  @override
  Future<void> setLoopMode(AppLoopMode mode) async {
    _loopMode = mode;
    _emit();
  }

  @override
  Future<void> setShuffle(bool enabled) async {
    _shuffle = enabled;
    _emit();
  }

  @override
  Future<void> playAt(int index) async {
    if (index < 0 || index >= _queue.length) return;
    _index = index;
    _position = Duration.zero;
    _playing = true;
    _emit();
  }

  @override
  Future<void> insertNext(PlayableItem item) async {
    _queue.insert(_queue.isEmpty ? 0 : _index + 1, item);
    _emit();
  }

  @override
  Future<void> removeAt(int index) async {
    if (index < 0 || index >= _queue.length) return;
    final current = _item;
    _queue.removeAt(index);
    final oldIndex = current == null ? -1 : _queue.indexOf(current);
    _index = _queue.isEmpty
        ? 0
        : oldIndex >= 0
        ? oldIndex
        : index.clamp(0, _queue.length - 1);
    if (_queue.isEmpty) _playing = false;
    _emit();
  }

  @override
  Future<void> moveItem(int from, int to) async {
    if (from < 0 || from >= _queue.length || to < 0 || to >= _queue.length) {
      return;
    }
    final current = _item;
    _queue.insert(to, _queue.removeAt(from));
    if (current != null) _index = _queue.indexOf(current);
    _emit();
  }

  @override
  Future<void> setVolume(double value) async {
    _volume = value.clamp(0, 1);
    _emit();
  }

  @override
  Future<void> setSpeed(double value) async {
    _speed = value;
    _emit();
  }

  @override
  Future<bool> setPreferredOutputDevice(int? deviceId) async => false;
  @override
  Future<void> setEqualizer(EqualizerSettings settings) async {}
  @override
  Future<void> dispose() async {
    _timer.cancel();
    await _events.close();
  }
}
