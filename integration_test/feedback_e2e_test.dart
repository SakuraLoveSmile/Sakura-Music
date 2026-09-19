import 'dart:convert';
import 'dart:io';

import 'package:feedback_widget/feedback_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:sakuramusic/core/feedback/feedback_config.dart';

/// Real end-to-end test for the feedback component against a live Feedback
/// service. Unlike `test/feedback_integration_test.dart` (no network), this
/// drives the actual UI — orb, viewport capture, in-panel login, submit —
/// over real HTTP against a running server, then verifies the record landed
/// server-side via the admin API.
///
/// The token store is swapped for [MemoryTokenStore]: the platform keychain is
/// not writable from a test-launched process (the component itself reports
/// "无法保存登录状态" in that case). Everything else — capture, login request,
/// multipart submit, waiting-state UI — runs the real code path.
///
/// Requires a reachable server plus a submitter and an admin account, supplied
/// via dart-defines (the test self-skips when unset). Credentials only ever
/// enter via `--dart-define` — never source, logs, or build artifacts.
///
/// The dedicated `sakuramusic.e2e` appId stays admin-unconfigured on purpose:
/// the submission must land in `waiting_configuration`, and the test leaves
/// the record in place for the manual lifecycle (it prints the feedback id).
///
/// ```sh
/// flutter test integration_test/feedback_e2e_test.dart -d macos \
///   --dart-define=FEEDBACK_E2E_API_BASE=https://feedback.xn--fhqths51enha.cn \
///   --dart-define=FEEDBACK_E2E_APP_ID=sakuramusic.e2e \
///   --dart-define=FEEDBACK_E2E_USER=<submitter> \
///   --dart-define=FEEDBACK_E2E_PASSWORD=<submitter-password> \
///   --dart-define=FEEDBACK_E2E_ADMIN_USER=<admin> \
///   --dart-define=FEEDBACK_E2E_ADMIN_PASSWORD=<admin-password>
/// ```
const String _apiBase = String.fromEnvironment('FEEDBACK_E2E_API_BASE');
const String _appId = String.fromEnvironment(
  'FEEDBACK_E2E_APP_ID',
  defaultValue: 'sakuramusic.e2e',
);
const String _user = String.fromEnvironment('FEEDBACK_E2E_USER');
const String _password = String.fromEnvironment('FEEDBACK_E2E_PASSWORD');
const String _adminUser = String.fromEnvironment('FEEDBACK_E2E_ADMIN_USER');
const String _adminPassword =
    String.fromEnvironment('FEEDBACK_E2E_ADMIN_PASSWORD');

bool get _configured =>
    _apiBase.isNotEmpty &&
    _user.isNotEmpty &&
    _password.isNotEmpty &&
    _adminUser.isNotEmpty &&
    _adminPassword.isNotEmpty;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'orb → capture → login → submit is stored server-side in a waiting state',
    skip: !_configured,
    (WidgetTester tester) async {
      final FeedbackController controller = FeedbackController();
      addTearDown(controller.dispose);

      final String marker = 'e2e-${DateTime.now().millisecondsSinceEpoch}';

      // Same mounting shape as app.dart: the component wraps the host page
      // inside a MaterialApp so the panel has Navigator/Overlay ancestors.
      await tester.pumpWidget(
        MaterialApp(
          home: FeedbackWidget(
            controller: controller,
            tokenStore: MemoryTokenStore(),
            config: buildFeedbackConfig(
              service: FeedbackServiceConfig(
                apiBase: _apiBase,
                appId: _appId,
                appName: 'SakuraMusic',
              ),
              pageLabel: 'home',
              appVersion: '0.0.0-e2e',
              // Exactly one deterministic, already-sanitized attachment so the
              // server-side logCount assertion is stable.
              logProvider: () async => <FeedbackLogFile>[
                FeedbackLogFile(
                  filename: 'e2e-diagnostics.log',
                  bytes: utf8.encode(
                    'e2e deterministic diagnostics marker=$marker\n',
                  ),
                  source: 'auto',
                ),
              ],
            ),
            child: const Scaffold(body: Center(child: Text('host page'))),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('feedback-orb')), findsOneWidget);

      // Orb tap → viewport capture → panel opens on the compose view.
      await tester.tap(find.byKey(const Key('feedback-orb')));
      await _pumpUntil(tester, find.byKey(const Key('feedback-input')));

      await tester.enterText(
        find.byKey(const Key('feedback-input')),
        'E2E feedback submit from integration test $marker',
      );
      await tester.pump();

      // Not signed in: submit expands the inline login form, then the panel
      // auto-submits once login succeeds.
      await tester.tap(find.byKey(const Key('feedback-submit')));
      await _pumpUntil(
        tester,
        find.byKey(const Key('feedback-login-username')),
      );

      await tester.enterText(
        find.byKey(const Key('feedback-login-username')),
        _user,
      );
      await tester.enterText(
        find.byKey(const Key('feedback-login-password')),
        _password,
      );
      await tester.tap(find.byKey(const Key('feedback-login-submit')));

      // Login + real multipart submit + server persist take real time.
      await _pumpUntil(
        tester,
        find.byKey(const Key('feedback-refresh-status')),
        timeout: const Duration(seconds: 30),
      );

      // Feedback 0.4.0: an auto-discovered (unconfigured) app reports
      // collectionState=waiting_configuration — the panel must show the
      // '已保存' waiting notice with a manual refresh action and must NOT
      // keep polling.
      expect(find.textContaining('已保存'), findsWidgets);
      expect(
        find.textContaining('等待管理员配置该软件'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('feedback-continue')), findsOneWidget);

      // Server-side truth: the record exists, carries our identity, and sits
      // in the waiting-for-configuration collection state (sakuramusic.e2e is
      // intentionally left unconfigured by the admin).
      final _AdminApi admin = await _AdminApi.login(
        _apiBase,
        _adminUser,
        _adminPassword,
      );
      final Map<String, Object?> record = await admin.findFeedbackByTitle(
        appId: _appId,
        titleContains: marker,
      );
      expect(record['username'], _user);
      expect(record['collectionState'], 'waiting_configuration');
      expect(record['hasScreenshot'], isTrue);
      expect(record['logCount'], 1);

      // The record intentionally stays on production for the manual lifecycle;
      // surface its id so a human can locate it later.
      // ignore: avoid_print
      print('E2E feedback id: ${record['id']} (marker: $marker)');

      // appName adoption: the auto-discovered app shows the reported display
      // name until an admin overrides it.
      final Map<String, Object?> app = await admin.findApp(_appId);
      expect(app['name'], 'SakuraMusic');
    },
  );
}

/// Pumps until [finder] matches or [timeout] elapses — real network latency
/// makes a fixed `pumpAndSettle` unreliable here.
Future<void> _pumpUntil(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 15),
}) async {
  final DateTime deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 200));
    if (finder.evaluate().isNotEmpty) {
      await tester.pumpAndSettle();
      return;
    }
  }
  await tester.pumpAndSettle();
  expect(finder, findsWidgets, reason: 'timed out waiting for $finder');
}

/// Minimal admin-API client for server-side assertions (dart:io only — the
/// app itself does not depend on package:http).
class _AdminApi {
  _AdminApi._(this._apiBase, this._client, this._cookie);

  final String _apiBase;
  final HttpClient _client;
  final String _cookie;

  static Future<_AdminApi> login(
    String apiBase,
    String username,
    String password,
  ) async {
    final HttpClient client = HttpClient();
    final HttpClientRequest req =
        await client.postUrl(Uri.parse('$apiBase/api/auth/login'));
    req.headers.contentType = ContentType.json;
    req.write(jsonEncode(<String, String>{
      'username': username,
      'password': password,
    }));
    final HttpClientResponse res = await req.close();
    final String body = await res.transform(utf8.decoder).join();
    if (res.statusCode != 200) {
      throw StateError('admin login failed: ${res.statusCode} $body');
    }
    final String cookie = res.headers.value('set-cookie')?.split(';').first ??
        '';
    if (cookie.isEmpty) {
      throw StateError('admin login returned no session cookie');
    }
    return _AdminApi._(apiBase, client, cookie);
  }

  Future<Map<String, Object?>> _get(String path) async {
    final HttpClientRequest req =
        await _client.getUrl(Uri.parse('$_apiBase$path'));
    req.headers.set(HttpHeaders.cookieHeader, _cookie);
    final HttpClientResponse res = await req.close();
    final String body = await res.transform(utf8.decoder).join();
    if (res.statusCode != 200) {
      throw StateError('GET $path failed: ${res.statusCode} $body');
    }
    return jsonDecode(body) as Map<String, Object?>;
  }

  Future<Map<String, Object?>> findFeedbackByTitle({
    required String appId,
    required String titleContains,
  }) async {
    final Map<String, Object?> page =
        await _get('/api/admin/feedback?appId=$appId&limit=50');
    final List<Object?> items = page['items'] as List<Object?>;
    for (final Object? item in items) {
      final Map<String, Object?> record = item! as Map<String, Object?>;
      if ((record['title'] as String? ?? '').contains(titleContains)) {
        return record;
      }
    }
    throw StateError(
      'no feedback titled like "$titleContains" for appId=$appId; '
      'got ${items.length} items',
    );
  }

  Future<Map<String, Object?>> findApp(String appId) async {
    final Map<String, Object?> page = await _get('/api/admin/apps');
    final List<Object?> apps = page['apps'] as List<Object?>;
    for (final Object? item in apps) {
      final Map<String, Object?> app = item! as Map<String, Object?>;
      if (app['appId'] == appId) return app;
    }
    throw StateError('app $appId not found; got ${apps.length} apps');
  }
}
