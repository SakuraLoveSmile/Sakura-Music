import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramusic/data/db/app_database.dart';
import 'package:sakuramusic/features/welcome/widgets/add_server_dialog.dart';
import 'package:sakuramusic/features/welcome/widgets/server_config_form.dart';
import 'package:sakuramusic/l10n/app_localizations.dart';

/// Protocols offered to the bare form in these tests. Two entries are enough to
/// exercise the protocol chip and the port default it carries.
const List<ServerProtocolItem> _testProtocols = <ServerProtocolItem>[
  ServerProtocolItem(id: 'Navidrome', name: 'Navidrome', defaultPort: '4533'),
  ServerProtocolItem(id: 'Subsonic', name: 'Subsonic', defaultPort: '4040'),
];

/// Stand-in for the real WebDAV/Subsonic probe: records what was sent, can hang
/// until [release] is called, and then succeeds or fails on demand. This is what
/// makes the in-flight race reproducible without any network access.
class _FakeConnectionTester {
  _FakeConnectionTester({this.hangs = false});

  /// Flipped to false to emulate a probe that fails after an earlier pass.
  bool succeeds = true;
  bool hangs;
  int calls = 0;
  String? lastBaseUrl;
  String? lastUsername;
  String? lastPassword;
  bool? lastIsWebDav;
  Completer<void>? _gate;

  Future<void> call({
    required bool isWebDav,
    required String baseUrl,
    required String username,
    required String password,
  }) async {
    calls += 1;
    lastBaseUrl = baseUrl;
    lastUsername = username;
    lastPassword = password;
    lastIsWebDav = isWebDav;
    if (hangs) {
      _gate ??= Completer<void>();
      await _gate!.future;
    }
    if (!succeeds) {
      throw Exception('probe failed');
    }
  }

  /// Completes the pending probe so the form can process its result.
  void release() {
    final gate = _gate;
    _gate = null;
    gate?.complete();
  }
}

/// Adding a server stays locked until a connection test passes, so the gate is
/// observed through the save button's `onPressed`. Editing an existing server is
/// never gated — that server is already reachable by definition.
void main() {
  /// Fields are addressed by their localized label instead of their position, so
  /// the tests follow the form's meaning rather than its widget order.
  Finder field(String label) => find.widgetWithText(TextFormField, label);

  Future<void> pumpDialog(WidgetTester tester, {Server? serverToEdit}) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('zh'),
          home: Scaffold(body: AddServerDialog(serverToEdit: serverToEdit)),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Pumps the form on its own so a fake [connectionTester] can be injected;
  /// [debugLabel] gives every pump a fresh state instead of reusing the previous
  /// one when the same test pumps the form several times.
  Future<void> pumpForm(
    WidgetTester tester, {
    ServerConnectionTester? connectionTester,
    Server? serverToEdit,
    ServerProtocolItem? fixedProtocol,
    String debugLabel = 'form',
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('zh'),
          home: Scaffold(
            body: SingleChildScrollView(
              child: ServerConfigForm(
                key: ValueKey<String>(debugLabel),
                protocols: _testProtocols,
                fixedProtocol: fixedProtocol,
                serverToEdit: serverToEdit,
                connectionTester:
                    connectionTester ?? defaultServerConnectionTester,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  VoidCallback? saveOnPressed(WidgetTester tester) =>
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed;

  Future<void> tapTestConnection(WidgetTester tester) async {
    final label = find.text('测试连接');
    expect(label, findsOneWidget);
    await tester.ensureVisible(label);
    await tester.pumpAndSettle();
    await tester.tap(label);
  }

  Future<void> fillForm(
    WidgetTester tester, {
    String host = 'music.example.com',
    String port = '4533',
  }) async {
    final fields = find.byType(TextFormField);
    expect(fields, findsNWidgets(5));
    await tester.enterText(field('服务器名称'), '客厅服务器');
    await tester.enterText(field('服务器地址'), host);
    await tester.enterText(field('端口'), port);
    await tester.enterText(field('账号 / 用户名'), 'listener');
    await tester.enterText(field('密码'), 'secret');
    await tester.pumpAndSettle();
  }

  testWidgets('add mode keeps save disabled until a connection test passes', (
    WidgetTester tester,
  ) async {
    await pumpDialog(tester);
    expect(
      saveOnPressed(tester),
      isNull,
      reason: 'a brand new server must not be savable before any test',
    );

    await fillForm(tester);
    expect(
      saveOnPressed(tester),
      isNull,
      reason: 'every field is valid, but no connection test has passed yet',
    );

    // A tap on the disabled button must not fall through to the save path; no
    // repository provider is overridden here, so a write would throw loudly.
    await tester.ensureVisible(find.byType(FilledButton));
    await tester.tap(find.byType(FilledButton), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(saveOnPressed(tester), isNull);
    expect(find.text('客厅服务器'), findsOneWidget);
    // If the disabled button had run the save, the un-overridden repository
    // would surface as a "save failed" banner; the gate must prevent that.
    expect(
      find.byIcon(Icons.error_outline_rounded),
      findsNothing,
      reason: 'a disabled save must not even attempt the write',
    );
  });

  testWidgets('edit mode is never gated by the connection test', (
    WidgetTester tester,
  ) async {
    final server = Server(
      id: 1,
      name: 'Home',
      baseUrl: 'https://music.example.com',
      username: 'listener',
      password: 'secret',
      createdAt: DateTime(2024),
    );

    await pumpDialog(tester, serverToEdit: server);
    expect(
      saveOnPressed(tester),
      isNotNull,
      reason: 'editing an existing server saves without a new connection test',
    );
  });

  testWidgets('a failing default connection test keeps save locked', (
    WidgetTester tester,
  ) async {
    // No fake here: this runs the production probe against the HTTP client that
    // flutter_test installs, which answers every request with an error.
    await pumpForm(tester);
    await fillForm(tester);

    await tapTestConnection(tester);
    await tester.pumpAndSettle();

    expect(
      find.byIcon(Icons.error_outline_rounded),
      findsOneWidget,
      reason: 'the failed test has to be reported to the user',
    );
    expect(
      find.byIcon(Icons.check_circle_outline_rounded),
      findsNothing,
      reason: 'a failed test must never look like a success',
    );
    expect(
      saveOnPressed(tester),
      isNull,
      reason: 'a failed connection test cannot unlock saving',
    );

    await tester.enterText(field('端口'), '4040');
    await tester.pumpAndSettle();
    expect(
      saveOnPressed(tester),
      isNull,
      reason: 'editing a field after a failed test still leaves save locked',
    );
  });

  testWidgets('a passing connection test unlocks save in add mode', (
    WidgetTester tester,
  ) async {
    final fake = _FakeConnectionTester();
    await pumpForm(tester, connectionTester: fake.call);
    await fillForm(tester);
    expect(saveOnPressed(tester), isNull);

    await tapTestConnection(tester);
    await tester.pumpAndSettle();

    expect(fake.calls, 1);
    expect(fake.lastBaseUrl, 'https://music.example.com:4533');
    expect(
      fake.lastIsWebDav,
      isFalse,
      reason: 'Navidrome and Subsonic probes go through the Subsonic client',
    );
    expect(fake.lastUsername, 'listener');
    expect(fake.lastPassword, 'secret');
    expect(find.byIcon(Icons.check_circle_outline_rounded), findsOneWidget);
    expect(
      saveOnPressed(tester),
      isNotNull,
      reason: 'the tested settings are saved, so the gate opens',
    );
  });

  testWidgets('editing any connection field after a pass re-locks save', (
    WidgetTester tester,
  ) async {
    final changes = <String, Future<void> Function(WidgetTester)>{
      '端口': (tester) => tester.enterText(field('端口'), '9999'),
      '用户名': (tester) => tester.enterText(field('账号 / 用户名'), 'someone'),
      '密码': (tester) => tester.enterText(field('密码'), 'another-secret'),
      '主机': (tester) =>
          tester.enterText(field('服务器地址'), 'other.example.com'),
      'scheme': (tester) => tester.tap(find.text('HTTP')),
      '协议': (tester) => tester.tap(find.text('Subsonic')),
    };

    for (final change in changes.entries) {
      final fake = _FakeConnectionTester();
      await pumpForm(
        tester,
        connectionTester: fake.call,
        debugLabel: 'relock-${change.key}',
      );
      // A port that is not the Navidrome default keeps the protocol chip from
      // rewriting the port, so the protocol is the only field that changes.
      await fillForm(tester, port: '8443');
      await tapTestConnection(tester);
      await tester.pumpAndSettle();
      expect(
        saveOnPressed(tester),
        isNotNull,
        reason: 'precondition: the test passed for ${change.key}',
      );

      await change.value(tester);
      await tester.pumpAndSettle();
      expect(
        saveOnPressed(tester),
        isNull,
        reason: 'changing ${change.key} invalidates the passed test',
      );
    }
  });

  testWidgets('renaming after a pass keeps save enabled', (WidgetTester tester) async {
    final fake = _FakeConnectionTester();
    await pumpForm(tester, connectionTester: fake.call);
    await fillForm(tester);
    await tapTestConnection(tester);
    await tester.pumpAndSettle();
    expect(saveOnPressed(tester), isNotNull);

    await tester.enterText(field('服务器名称'), '书房服务器');
    await tester.pumpAndSettle();
    expect(
      saveOnPressed(tester),
      isNotNull,
      reason: 'the server name is not part of the connection signature',
    );
    expect(find.text('书房服务器'), findsOneWidget);
  });

  testWidgets('a failed re-test after a pass re-locks save', (
    WidgetTester tester,
  ) async {
    final fake = _FakeConnectionTester();
    await pumpForm(tester, connectionTester: fake.call);
    await fillForm(tester);
    await tapTestConnection(tester);
    await tester.pumpAndSettle();
    expect(saveOnPressed(tester), isNotNull);

    fake.succeeds = false;
    await tapTestConnection(tester);
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);
    expect(
      saveOnPressed(tester),
      isNull,
      reason: 'a later failing test has to invalidate the earlier pass',
    );
  });

  testWidgets('editing the host while a test is in flight does not unlock save', (
    WidgetTester tester,
  ) async {
    final fake = _FakeConnectionTester(hangs: true);
    await pumpForm(tester, connectionTester: fake.call);
    await fillForm(tester);

    await tapTestConnection(tester);
    await tester.pump();
    expect(fake.calls, 1, reason: 'precondition: the probe is in flight');
    expect(fake.lastBaseUrl, 'https://music.example.com:4533');

    // The user types a new host before the probe answers.
    await tester.enterText(field('服务器地址'), 'other.example.com');
    await tester.pump();

    fake.release();
    await tester.pumpAndSettle();

    expect(
      saveOnPressed(tester),
      isNull,
      reason:
          'the pass belongs to the old host, so the edited form stays locked',
    );
  });

  testWidgets(
    'editing the password while a test is in flight does not unlock save',
    (WidgetTester tester) async {
      final fake = _FakeConnectionTester(hangs: true);
      await pumpForm(tester, connectionTester: fake.call);
      await fillForm(tester);

      await tapTestConnection(tester);
      await tester.pump();
      expect(fake.calls, 1, reason: 'precondition: the probe is in flight');
      expect(
        fake.lastPassword,
        'secret',
        reason: 'the probe in flight was sent the password current at that time',
      );

      await tester.enterText(field('密码'), 'corrected-secret');
      await tester.pump();

      fake.release();
      await tester.pumpAndSettle();

      expect(
        saveOnPressed(tester),
        isNull,
        reason:
            'the pass belongs to the old password, so the edited form stays locked',
      );
    },
  );

  testWidgets('a re-test after an in-flight edit passes for the edited settings', (
    WidgetTester tester,
  ) async {
    final fake = _FakeConnectionTester(hangs: true);
    await pumpForm(tester, connectionTester: fake.call);
    await fillForm(tester);

    await tapTestConnection(tester);
    await tester.pump();
    await tester.enterText(field('服务器地址'), 'other.example.com');
    await tester.pump();
    fake.release();
    await tester.pumpAndSettle();
    expect(saveOnPressed(tester), isNull);

    // Retrying for the settings the form now holds has to unlock save: a
    // mid-flight edit must not lock the form permanently.
    fake.hangs = false;
    await tapTestConnection(tester);
    await tester.pumpAndSettle();

    expect(fake.calls, 2);
    expect(fake.lastBaseUrl, 'https://other.example.com:4533');
    expect(
      saveOnPressed(tester),
      isNotNull,
      reason: 'the second pass covers the edited host, so saving unlocks again',
    );
  });

  testWidgets('the WebDAV protocol drives the probe with the composed URL', (
    WidgetTester tester,
  ) async {
    final fake = _FakeConnectionTester();
    await pumpForm(
      tester,
      connectionTester: fake.call,
      fixedProtocol: const ServerProtocolItem(
        id: 'webdav',
        name: 'WebDAV',
        defaultPort: '80',
      ),
      debugLabel: 'webdav',
    );
    await fillForm(tester, port: '5005');

    await tapTestConnection(tester);
    await tester.pumpAndSettle();

    expect(
      fake.lastIsWebDav,
      isTrue,
      reason: 'the WebDAV protocol probes with a PROPFIND, not a Subsonic ping',
    );
    expect(fake.lastBaseUrl, 'https://music.example.com:5005');
    expect(fake.lastUsername, 'listener');
    expect(fake.lastPassword, 'secret');
    expect(saveOnPressed(tester), isNotNull);
  });
}
