import 'package:feedback_widget/feedback_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sakuramusic/core/feedback/feedback_config.dart';
import 'package:sakuramusic/core/feedback/feedback_layer.dart';
import 'package:sakuramusic/core/feedback/feedback_logs.dart';
import 'package:sakuramusic/features/welcome/widgets/server_config_form.dart';
import 'package:sakuramusic/l10n/app_localizations.dart';

/// Localizations delegate set used by the app; mirrored here so widgets that
/// call `context.l10n` render under test.
const List<LocalizationsDelegate<Object>> _delegates =
    <LocalizationsDelegate<Object>>[
  AppLocalizations.delegate,
  GlobalMaterialLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
];

FeedbackServiceConfig _testService() => const FeedbackServiceConfig(
  apiBase: 'http://localhost:8787',
  appId: 'sakuramusic.test',
);

void main() {
  group('page label sanitization (T3: no ids / query / server address)', () {
    test('reduces a route to its coarse category', () {
      expect(feedbackPageLabelFromUri(Uri.parse('/home')), 'home');
      expect(feedbackPageLabelFromUri(Uri.parse('/settings')), 'settings');
      expect(feedbackPageLabelFromUri(Uri.parse('/player')), 'player');
    });

    test('drops detail ids and sub-paths', () {
      expect(feedbackPageLabelFromUri(Uri.parse('/albums/123')), 'albums');
      expect(feedbackPageLabelFromUri(Uri.parse('/artists/abc-9')), 'artists');
      expect(feedbackPageLabelFromUri(Uri.parse('/playlists/42')), 'playlists');
      expect(
        feedbackPageLabelFromUri(Uri.parse('/add-server/config')),
        'add-server',
      );
    });

    test('never leaks search terms or query parameters', () {
      final String label = feedbackPageLabelFromUri(
        Uri.parse('/search?q=secret%20song&server=https://music.example.com'),
      );
      expect(label, 'search');
      expect(label.contains('secret'), isFalse);
      expect(label.contains('example.com'), isFalse);
      expect(label.contains('q='), isFalse);
    });

    test('root falls back to home and unknown routes collapse to other', () {
      expect(feedbackPageLabelFromUri(Uri.parse('/')), 'home');
      expect(feedbackPageLabelFromUri(Uri.parse('/something-new/7')), 'other');
    });
  });

  group('feedback config (T2: orb + viewport + dark; auto diagnostics logs)',
      () {
    test('fixes orb launcher, viewport capture, dark theme, right side', () {
      final FeedbackConfig config = buildFeedbackConfig(
        service: _testService(),
        pageLabel: 'home',
        appVersion: '1.2.3+4',
      );
      expect(config.apiBase, 'http://localhost:8787');
      expect(config.appId, 'sakuramusic.test');
      expect(config.appName, isNull);
      expect(config.launcherMode, FeedbackLauncherMode.orb);
      expect(config.captureMode, FeedbackCaptureMode.viewport);
      expect(config.theme, FeedbackThemeMode.dark);
      expect(config.side, FeedbackSide.right);
      expect(config.pageLabel, 'home');
      expect(config.appVersion, '1.2.3+4');
    });

    test('reports the app display name when the service provides one', () {
      // Feedback 0.4.0: optional appName, adopted by the service only while
      // the admin has not set a name for the appId.
      final FeedbackConfig config = buildFeedbackConfig(
        service: const FeedbackServiceConfig(
          apiBase: 'http://localhost:8787',
          appId: 'sakuramusic.test',
          appName: 'SakuraMusic',
        ),
        pageLabel: 'home',
      );
      expect(config.appName, 'SakuraMusic');
    });

    test('wires the host diagnostics log provider by default', () {
      final FeedbackConfig config = buildFeedbackConfig(
        service: _testService(),
        pageLabel: 'settings',
      );
      // The host explicitly attaches its own redacted diagnostics; the
      // component still never grabs host info on its own.
      expect(config.logProvider, collectFeedbackLogs);
      expect(config.appVersion, isNull);
    });

    test('a caller can override or disable the log provider', () {
      Future<List<FeedbackLogFile>> none() async => const <FeedbackLogFile>[];
      expect(
        buildFeedbackConfig(
          service: _testService(),
          pageLabel: 'settings',
          logProvider: none,
        ).logProvider,
        none,
      );
      expect(
        buildFeedbackConfig(
          service: _testService(),
          pageLabel: 'settings',
          logProvider: null,
        ).logProvider,
        isNull,
      );
    });
  });

  group('feedback diagnostics logs (redacted + shaped for the component)', () {
    test('redacts credentials and emits playback.log', () {
      final List<FeedbackLogFile> files = buildFeedbackLogFiles(
        playbackText: 'GET https://music.example.com/rest/stream'
            '?id=42&u=alice&p=hunter2&t=abc123&s=salt',
      );
      expect(files, hasLength(1));
      expect(files.single.filename, 'playback.log');
      expect(files.single.source, 'auto');
      final String text = files.single.text;
      expect(text.contains('hunter2'), isFalse);
      expect(text.contains('abc123'), isFalse);
      expect(text.contains('<redacted>'), isTrue);
      // The host/path/id are kept — that is what debugging needs.
      expect(text.contains('music.example.com'), isTrue);
    });

    test('adds crash.log only when a crash tail exists', () {
      expect(buildFeedbackLogFiles(playbackText: 'buffering'), hasLength(1));
      final List<FeedbackLogFile> both = buildFeedbackLogFiles(
        playbackText: 'buffering',
        crashTail: 'CRASH: boom',
      );
      expect(
        both.map((FeedbackLogFile f) => f.filename),
        <String>['playback.log', 'crash.log'],
      );
    });

    test('blank sources attach nothing', () {
      expect(buildFeedbackLogFiles(playbackText: '   '), isEmpty);
      expect(buildFeedbackLogFiles(playbackText: '', crashTail: '\n '), isEmpty);
    });

    test('filenames are allow-listed .log and stay under the 1 MiB cap', () {
      final List<FeedbackLogFile> files = buildFeedbackLogFiles(
        playbackText: 'a' * 1000,
        crashTail: 'b' * 1000,
      );
      for (final FeedbackLogFile file in files) {
        expect(file.filename, endsWith('.log'));
        expect(file.byteSize, lessThan(1024 * 1024));
      }
    });
  });

  group('enablement + test injection (T1: off in debug, overridable)', () {
    test('disabled by default under flutter test (debug mode)', () {
      final ProviderContainer container = ProviderContainer();
      addTearDown(container.dispose);
      expect(container.read(feedbackServiceConfigProvider), isNull);
    });

    test('a test can inject an isolated service address', () {
      final ProviderContainer container = ProviderContainer(
        overrides: [
          feedbackServiceConfigProvider.overrideWithValue(_testService()),
        ],
      );
      addTearDown(container.dispose);
      final FeedbackServiceConfig? config =
          container.read(feedbackServiceConfigProvider);
      expect(config?.apiBase, 'http://localhost:8787');
      expect(config?.appId, 'sakuramusic.test');
    });

    test('the root controller is a single shared, disposed instance', () {
      final ProviderContainer container = ProviderContainer();
      addTearDown(container.dispose);
      final FeedbackController a = container.read(feedbackControllerProvider);
      final FeedbackController b = container.read(feedbackControllerProvider);
      expect(identical(a, b), isTrue);
    });
  });

  group('credential isolation (T3: feedback uses its own storage key)', () {
    test('feedback token key never collides with Music credential keys', () {
      final String key = feedbackTokenStorageKey(
        FeedbackConfig('https://feedback.example', 'sakuramusic'),
      );
      expect(key, startsWith('feedback_widget.bearer_token.'));
      // Music stores server passwords / third-party tokens under sakuramusic.*
      expect(key.contains('sakuramusic.server.password'), isFalse);
      expect(key.contains('sakuramusic.listenbrainz'), isFalse);
    });

    test('different service identities occupy different slots', () {
      final String prod = feedbackTokenStorageKey(
        FeedbackConfig('https://feedback.example', 'sakuramusic'),
      );
      final String test = feedbackTokenStorageKey(
        FeedbackConfig('http://localhost:8787', 'sakuramusic'),
      );
      expect(prod, isNot(test));
    });
  });

  group('global entry (T2: mounted above the router, survives navigation)', () {
    testWidgets('orb is present and the layer is not rebuilt on navigation',
        (WidgetTester tester) async {
      final FeedbackController controller = FeedbackController();
      addTearDown(controller.dispose);
      final GlobalKey<NavigatorState> hostKey = GlobalKey<NavigatorState>();
      final GlobalKey<NavigatorState> feedbackKey = GlobalKey<NavigatorState>();

      await tester.pumpWidget(
        MaterialApp(
          home: FeedbackOverlay(
            controller: controller,
            navigatorKey: feedbackKey,
            config: buildFeedbackConfig(
              service: _testService(),
              pageLabel: 'home',
            ),
            child: Navigator(
              key: hostKey,
              initialRoute: '/a',
              onGenerateRoute: (RouteSettings settings) =>
                  MaterialPageRoute<void>(
                settings: settings,
                builder: (BuildContext context) =>
                    Scaffold(body: Center(child: Text('page ${settings.name}'))),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('feedback-orb')), findsOneWidget);
      final State<FeedbackWidget> before =
          tester.state<State<FeedbackWidget>>(find.byType(FeedbackWidget));

      // Host pushes a new route underneath the feedback layer.
      hostKey.currentState!.push(
        MaterialPageRoute<void>(
          builder: (BuildContext context) =>
              const Scaffold(body: Center(child: Text('page b'))),
        ),
      );
      await tester.pumpAndSettle();

      final State<FeedbackWidget> after =
          tester.state<State<FeedbackWidget>>(find.byType(FeedbackWidget));
      expect(
        identical(before, after),
        isTrue,
        reason: 'the feedback layer must survive host navigation so the panel '
            'state (draft + login token) is never rebuilt away',
      );
      expect(find.byKey(const Key('feedback-orb')), findsOneWidget);
    });
  });

  group('android back handling (T2: close preview / panel before navigation)',
      () {
    Future<GlobalKey<NavigatorState>> pumpOuterNavigator(
      WidgetTester tester,
    ) async {
      final GlobalKey<NavigatorState> navKey = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(
          home: Navigator(
            key: navKey,
            onGenerateRoute: (RouteSettings settings) =>
                MaterialPageRoute<void>(
              settings: settings,
              builder: (BuildContext context) => const SizedBox.shrink(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return navKey;
    }

    testWidgets('closes the open panel and consumes the event',
        (WidgetTester tester) async {
      final GlobalKey<NavigatorState> navKey = await pumpOuterNavigator(tester);
      final FeedbackController controller = FeedbackController();
      addTearDown(controller.dispose);
      controller.open();
      expect(controller.isOpen, isTrue);

      final bool consumed = handleFeedbackBackPop(
        navigatorKey: navKey,
        controller: controller,
      );
      expect(consumed, isTrue);
      expect(controller.isOpen, isFalse);
    });

    testWidgets('dismisses a preview dialog on the outer navigator first',
        (WidgetTester tester) async {
      final GlobalKey<NavigatorState> navKey = await pumpOuterNavigator(tester);
      final FeedbackController controller = FeedbackController();
      addTearDown(controller.dispose);

      navKey.currentState!.push(
        MaterialPageRoute<void>(
          builder: (BuildContext context) => const Text('preview'),
        ),
      );
      await tester.pumpAndSettle();
      expect(navKey.currentState!.canPop(), isTrue);

      final bool consumed = handleFeedbackBackPop(
        navigatorKey: navKey,
        controller: controller,
      );
      expect(consumed, isTrue);
      await tester.pumpAndSettle();
      // The dialog is gone; the panel was never open so it stays closed.
      expect(navKey.currentState!.canPop(), isFalse);
      expect(controller.isOpen, isFalse);
    });

    testWidgets('falls through to normal navigation when nothing is open',
        (WidgetTester tester) async {
      final GlobalKey<NavigatorState> navKey = await pumpOuterNavigator(tester);
      final FeedbackController controller = FeedbackController();
      addTearDown(controller.dispose);

      expect(
        handleFeedbackBackPop(navigatorKey: navKey, controller: controller),
        isFalse,
      );
    });
  });

  group('screenshot masking (T3: sensitive fields are declared)', () {
    testWidgets('server config form masks address, username and password',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            localizationsDelegates: _delegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(
              body: SingleChildScrollView(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: ServerConfigForm(protocols: serverProtocols),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // host + username + password are wrapped; the server name and port are
      // not (they are not credentials).
      expect(find.byType(FeedbackCaptureMask), findsNWidgets(3));
    });
  });
}
