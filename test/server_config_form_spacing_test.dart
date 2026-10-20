import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

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

/// The vertical gap the config form must keep between adjacent input rows.
const double _expectedGap = 20;

/// The fixed protocol the full-screen add-server config page renders with.
ServerProtocolItem _webDavProtocol() => serverProtocols.firstWhere(
  (ServerProtocolItem protocol) => protocol.id == 'webdav',
);

/// Pumps the fixed-protocol (full-screen) variant of [ServerConfigForm] inside
/// an app-like localization + Riverpod scope.
Future<void> _pumpFixedProtocolForm(WidgetTester tester) async {
  // Tall surface: the whole form lays out at once, so every field we measure
  // has a real rect even though the page itself scrolls.
  tester.view.physicalSize = const Size(900, 2000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        localizationsDelegates: _delegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('zh'),
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: ServerConfigForm(
              protocols: serverProtocols,
              fixedProtocol: _webDavProtocol(),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'fixed-protocol config page keeps a 20px gap between adjacent input rows',
    (WidgetTester tester) async {
      await _pumpFixedProtocolForm(tester);

      // Exactly one field per row: name, address, port, username, password.
      final Finder fields = find.byType(TextFormField);
      expect(fields, findsNWidgets(5));

      final Rect name = tester.getRect(fields.at(0));
      final Rect address = tester.getRect(fields.at(1));
      final Rect username = tester.getRect(fields.at(3));
      final Rect password = tester.getRect(fields.at(4));

      // Regression guard: name -> address used to have no gap at all (0px).
      expect(address.top - name.bottom, greaterThanOrEqualTo(_expectedGap));
      // Regression guard: username -> password used to be a tighter 14px.
      expect(password.top - username.bottom, greaterThanOrEqualTo(_expectedGap));
    },
  );
}
