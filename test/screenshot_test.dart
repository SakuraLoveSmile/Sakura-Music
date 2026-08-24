import 'dart:io';
import 'dart:ui' as ui;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramusic/core/theme.dart';
import 'package:sakuramusic/data/db/app_database.dart';
import 'package:sakuramusic/data/server_repository.dart';
import 'package:sakuramusic/features/welcome/welcome_screen.dart';
import 'package:sakuramusic/l10n/app_localizations.dart';

void main() {
  testWidgets('capture welcome screen preview', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.runAsync(() async {
      final iconFile = File(
        '/Users/sakurasep/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
      );
      if (await iconFile.exists()) {
        final iconBytes = await iconFile.readAsBytes();
        final iconLoader = FontLoader('MaterialIcons')
          ..addFont(Future<ByteData>.value(ByteData.sublistView(iconBytes)));
        await iconLoader.load();
      }

      final fontFile =
          File('/System/Library/Fonts/Supplemental/NISC18030.ttf');
      if (await fontFile.exists()) {
        final fontBytes = await fontFile.readAsBytes();
        final fontLoader = FontLoader('ChineseFont')
          ..addFont(Future<ByteData>.value(ByteData.sublistView(fontBytes)));
        await fontLoader.load();
      }
    });

    final repaintKey = GlobalKey();
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    final theme = buildTheme(Brightness.dark).copyWith(
      textTheme: const TextTheme().apply(
        fontFamily: 'ChineseFont',
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(database),
          serversProvider.overrideWithValue(const AsyncValue.data(<Server>[])),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('zh'),
          debugShowCheckedModeBanner: false,
          theme: theme,
          darkTheme: theme,
          themeMode: ThemeMode.dark,
          home: RepaintBoundary(
            key: repaintKey,
            child: const WelcomeScreen(),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await tester.runAsync(() async {
      final boundary =
          repaintKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final pngBytes = byteData!.buffer.asUint8List();

      // Machine-local preview capture: skip when the target directory does
      // not exist (e.g. CI runners), and allow redirecting via env var.
      final previewPath =
          Platform.environment['WELCOME_SCREEN_PREVIEW_PATH'] ??
          '/Users/sakurasep/.gemini/antigravity/brain/9b0b0156-553f-4357-808e-a6fc7c6e5eb5/welcome_screen_preview.png';
      final file = File(previewPath);
      if (await file.parent.exists()) {
        await file.writeAsBytes(pngBytes);
      }
    });
  });
}
