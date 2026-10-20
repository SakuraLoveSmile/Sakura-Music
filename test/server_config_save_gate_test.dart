import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramusic/data/db/app_database.dart';
import 'package:sakuramusic/features/welcome/widgets/add_server_dialog.dart';
import 'package:sakuramusic/l10n/app_localizations.dart';

/// Adding a server stays locked until a connection test passes, so the gate is
/// observed through the save button's `onPressed`. Editing an existing server is
/// never gated — that server is already reachable by definition.
void main() {
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

  VoidCallback? saveOnPressed(WidgetTester tester) =>
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed;

  Future<void> fillAddForm(WidgetTester tester) async {
    final fields = find.byType(TextFormField);
    expect(fields, findsNWidgets(5));
    await tester.enterText(fields.at(0), '客厅服务器');
    await tester.enterText(fields.at(1), 'music.example.com');
    await tester.enterText(fields.at(2), '4533');
    await tester.enterText(fields.at(3), 'listener');
    await tester.enterText(fields.at(4), 'secret');
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

    await fillAddForm(tester);
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
}
