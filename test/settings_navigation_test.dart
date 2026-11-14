import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:sakuramusic/audio/audio_player_provider.dart';
import 'package:sakuramusic/audio/audio_player_service.dart';
import 'package:sakuramusic/audio/equalizer_models.dart';
import 'package:sakuramusic/core/providers.dart';
import 'package:sakuramusic/core/security/credential_store.dart';
import 'package:sakuramusic/core/update/update_providers.dart';
import 'package:sakuramusic/data/db/app_database.dart';
import 'package:sakuramusic/data/server_repository.dart';
import 'package:sakuramusic/features/settings/settings_screen.dart';
import 'package:sakuramusic/l10n/app_localizations.dart';
import 'package:sakuramusic/router.dart';
import 'package:subsonic_api/subsonic_api.dart';

/// Regression coverage for the settings page's back behavior.
///
/// Entering settings from the home screen uses `go('/settings')`, which leaves
/// `/settings` as the only route on the Navigator stack. Android's system back
/// (key or gesture) therefore reached the engine's `popRoute`, found nothing to
/// pop, and ran `SystemNavigator.pop()` — the app left to the launcher instead
/// of showing the music home. The page arrow had the right rule
/// (`pop()`/`go('/home')`) but the system back never used it.
///
/// These tests drive the PRODUCTION router (`appRouterProvider`) and the real
/// `SettingsScreen`; only the audio player, the app-version lookup, the
/// credential store and the remote Subsonic boundary are replaced, so every
/// navigation asserted here is the real go_router navigation. System back is
/// simulated with `tester.binding.handlePopRoute()` and `SystemNavigator.pop`
/// is captured on the platform channel to prove the app is never asked to
/// close.
void main() {
  testWidgets('首页设置入口：箭头与系统返回都回到 /home，且不请求退出应用', (WidgetTester tester) async {
    final harness = await _pump(tester, withServer: true);
    expect(harness.location, '/home');

    // The top-left arrow keeps working exactly as before.
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    expect(harness.location, '/settings');
    expect(find.byType(SettingsScreen), findsOneWidget);
    // `go('/settings')` replaced the stack, so there is no history to pop.
    expect(harness.router.canPop(), isFalse);

    await tester.tap(find.byIcon(Icons.chevron_left_rounded));
    await tester.pumpAndSettle();
    expect(harness.location, '/home');

    // System back from the very same entry point must behave identically.
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    expect(harness.location, '/settings');

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(harness.location, '/home', reason: '系统返回必须落在音乐主界面，而不是让应用退到桌面');
    expect(harness.systemPops, isEmpty, reason: '返回被页面消费，不应请求 Android 关闭应用');
  });

  testWidgets('无历史直接进入 /settings：系统返回留在应用内，有服务器回 /home', (
    WidgetTester tester,
  ) async {
    final harness = await _pump(tester, withServer: true);

    // Enter settings with no history at all (a cold `/settings` start).
    harness.router.go('/settings');
    await tester.pumpAndSettle();
    expect(harness.location, '/settings');
    expect(harness.router.canPop(), isFalse);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    // The defect this test guards: with no history the engine was asked to
    // close the app instead of showing the music home.
    expect(harness.systemPops, isEmpty, reason: '系统返回不得请求 Android 关闭应用');
    expect(harness.location, '/home');
  });

  testWidgets('无历史直接进入 /settings：无服务器时系统返回落到 /welcome', (
    WidgetTester tester,
  ) async {
    final harness = await _pump(tester, withServer: false);
    expect(harness.location, '/welcome');

    harness.router.go('/settings');
    await tester.pumpAndSettle();
    expect(harness.location, '/settings');
    expect(harness.router.canPop(), isFalse);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    // `_handleBack` goes to `/home`; router.dart redirects a server-less
    // install to `/welcome`, so the user still stays inside the app.
    expect(harness.location, '/welcome');
    expect(harness.systemPops, isEmpty);
  });

  testWidgets('欢迎页 push 进入设置：返回欢迎页且只弹一次', (WidgetTester tester) async {
    final harness = await _pump(tester, withServer: false);
    expect(harness.location, '/welcome');

    // The welcome page's own settings button uses `push`, so this entry point
    // DOES have history and must pop exactly one route.
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    expect(harness.location, '/settings');
    expect(harness.router.canPop(), isTrue);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(harness.location, '/welcome', reason: '一次返回只弹一层；若回调重复导航就会落到 /home');
    expect(harness.router.canPop(), isFalse);
    expect(find.byType(SettingsScreen), findsNothing);
    expect(harness.systemPops, isEmpty);
  });

  testWidgets('设置弹窗：第一次系统返回只关弹窗，第二次才离开设置页', (WidgetTester tester) async {
    final harness = await _pump(tester, withServer: true);

    harness.router.go('/settings');
    await tester.pumpAndSettle();
    expect(harness.location, '/settings');

    // Open the streaming-quality dialog (a real `showDialog` route).
    await tester.tap(find.byIcon(Icons.graphic_eq_rounded));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(harness.location, '/settings', reason: '第一次返回只关闭弹窗');
    expect(harness.systemPops, isEmpty);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(harness.location, '/home');
    expect(harness.systemPops, isEmpty);
  });
}

/// The app under test plus the boundaries this file replaced.
class _Harness {
  _Harness({
    required this.container,
    required this.router,
    required this.database,
    required this.player,
    required this.client,
    required this.platformCalls,
  });

  final ProviderContainer container;
  final GoRouter router;
  final AppDatabase database;
  final _FakeAudioPlayer player;
  final _StubSubsonicClient client;

  /// Every method call the app made on `SystemChannels.platform`.
  final List<MethodCall> platformCalls;

  /// The visible route: `currentConfiguration.uri` ignores imperative matches,
  /// so a `push`ed page would look like the page below it.
  String get location =>
      router.routerDelegate.currentConfiguration.last.matchedLocation;

  List<MethodCall> get systemPops => platformCalls
      .where((MethodCall call) => call.method == 'SystemNavigator.pop')
      .toList(growable: false);
}

/// Mounts the real router tree: `MaterialApp.router` + `appRouterProvider`,
/// so `HomeScreen`, `WelcomeScreen` and `SettingsScreen` are the production
/// widgets and every navigation runs through go_router.
Future<_Harness> _pump(WidgetTester tester, {required bool withServer}) async {
  // A phone-class viewport (the narrow layout Android runs). It stays above
  // the home header's 380dp row width so no RenderFlex overflows, and it keeps
  // a single settings entry per page (the wide layout adds one to the shell's
  // top action bar).
  tester.view.physicalSize = const Size(460, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final platformCalls = <MethodCall>[];
  final TestDefaultBinaryMessenger messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(SystemChannels.platform, (
    MethodCall call,
  ) async {
    platformCalls.add(call);
    return null;
  });

  final database = AppDatabase(NativeDatabase.memory());
  final player = _FakeAudioPlayer();
  final client = _StubSubsonicClient();
  final server = Server(
    id: 1,
    name: 'Test Library',
    baseUrl: 'http://127.0.0.1:4533',
    username: 'listener',
    password: '',
    createdAt: DateTime(2024),
  );
  final container = ProviderContainer(
    overrides: [
      // Local persistence stays real (in-memory drift); only the boundaries the
      // plan allows to be replaced are overridden.
      databaseProvider.overrideWithValue(database),
      credentialStoreProvider.overrideWithValue(_FakeCredentialStore()),
      serversProvider.overrideWithValue(
        AsyncValue<List<Server>>.data(
          withServer ? <Server>[server] : <Server>[],
        ),
      ),
      if (withServer) activeSubsonicClientProvider.overrideWithValue(client),
      audioPlayerProvider.overrideWithValue(player),
      appVersionProvider.overrideWith(
        (ref) async => PackageInfo(
          appName: 'SakuraMusic',
          packageName: 'test.music',
          version: '0.3.1',
          buildNumber: '1',
        ),
      ),
      // A live drift stream schedules its own teardown timer when the tree is
      // disposed, which would trip the pending-timer invariant.
      recentPlaysProvider.overrideWithValue(
        const AsyncValue<List<RecentPlay>>.data(<RecentPlay>[]),
      ),
    ],
  );

  addTearDown(() async {
    // Unmount the pages, then release the container (which disposes the
    // router), the database and the fakes.
    await tester.pumpWidget(const SizedBox.shrink());
    container.dispose();
    await database.close();
    await player.dispose();
    messenger.setMockMethodCallHandler(SystemChannels.platform, null);
  });

  final router = container.read(appRouterProvider);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        theme: ThemeData.dark(),
        locale: const Locale('zh'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        routerConfig: router,
      ),
    ),
  );
  await tester.pumpAndSettle();

  return _Harness(
    container: container,
    router: router,
    database: database,
    player: player,
    client: client,
    platformCalls: platformCalls,
  );
}

/// Audio boundary: nothing in these tests plays audio, so every command is a
/// no-op and the snapshot stream stays quiet (a getter that re-emits would
/// make the mini player rebuild forever).
class _FakeAudioPlayer implements AudioPlayerService {
  final StreamController<PlayerSnapshot> _controller =
      StreamController<PlayerSnapshot>.broadcast();

  final PlayerSnapshot _snapshot = const PlayerSnapshot();

  @override
  Stream<PlayerSnapshot> get snapshot => _controller.stream;

  @override
  PlayerSnapshot? get currentSnapshot => _snapshot;

  @override
  Future<void> setQueue(List<PlayableItem> items, {int startIndex = 0}) async {}

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
  Future<bool> setPreferredOutputDevice(int? deviceId) async => true;

  @override
  Future<void> setEqualizer(EqualizerSettings settings) async {}

  @override
  Future<void> dispose() async {
    if (!_controller.isClosed) {
      await _controller.close();
    }
  }
}

/// Credential boundary: the platform keystore is unavailable in a widget test.
class _FakeCredentialStore implements CredentialStore {
  final Map<int, String> _passwords = <int, String>{};
  String? _listenBrainzToken;

  @override
  Future<String?> readServerPassword(int serverId) async =>
      _passwords[serverId];

  @override
  Future<void> writeServerPassword(int serverId, String password) async {
    _passwords[serverId] = password;
  }

  @override
  Future<void> deleteServerPassword(int serverId) async {
    _passwords.remove(serverId);
  }

  @override
  String? cachedServerPassword(int serverId) => _passwords[serverId];

  @override
  Future<void> warmUp(Iterable<int> serverIds) async {}

  @override
  Future<String?> readListenBrainzToken() async => _listenBrainzToken;

  @override
  Future<void> writeListenBrainzToken(String? token) async {
    _listenBrainzToken = token;
  }
}

/// Remote-data boundary: answers every read the home screen performs with an
/// empty result, so no socket is opened while the production providers,
/// widgets and navigation stay real.
class _StubSubsonicClient extends SubsonicClient {
  _StubSubsonicClient()
    : super(
        baseUrl: 'http://127.0.0.1:4533',
        username: 'listener',
        password: 'password',
      );

  @override
  Future<List<Song>> getRandomSongs({int size = 10}) async => const <Song>[];

  @override
  Future<List<Album>> getAlbumList({
    String type = 'newest',
    int size = 50,
    int offset = 0,
  }) async => const <Album>[];

  @override
  Future<List<Playlist>> getPlaylists() async => const <Playlist>[];

  @override
  Future<List<Artist>> getArtists() async => const <Artist>[];

  @override
  Future<List<MusicFolder>> getMusicFolders() async => const <MusicFolder>[];

  @override
  Future<Starred2> getStarred2() async => const Starred2();
}
