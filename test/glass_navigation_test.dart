import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sakuramusic/audio/audio_player_provider.dart';
import 'package:sakuramusic/audio/unavailable_audio_player_service.dart';
import 'package:sakuramusic/core/providers.dart';
import 'package:sakuramusic/core/theme.dart';
import 'package:sakuramusic/data/db/app_database.dart';
import 'package:sakuramusic/data/server_repository.dart';
import 'package:sakuramusic/features/player/app_shell.dart';
import 'package:sakuramusic/l10n/app_localizations.dart';
import 'package:subsonic_api/subsonic_api.dart';

void main() {
  testWidgets(
    'glass navigation reaches every destination at 320px and large text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final semantics = tester.ensureSemantics();
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      await database.insertServer(
        ServersCompanion.insert(
          name:
              'A long music library name that must not push controls offscreen',
          baseUrl: 'http://127.0.0.1',
          username: 'test',
          password: '',
        ),
      );
      final servers = await database.getAllServers();
      final player = UnavailableAudioPlayerService();
      addTearDown(player.dispose);
      const paths = [
        '/home',
        '/songs',
        '/albums',
        '/artists',
        '/genres',
        '/radios',
        '/favorites',
        '/downloads',
      ];
      final router = GoRouter(
        initialLocation: '/home',
        routes: [
          StatefulShellRoute.indexedStack(
            builder: (context, state, shell) =>
                AppShell(navigationShell: shell),
            branches: [
              for (final path in paths)
                StatefulShellBranch(
                  routes: [
                    GoRoute(
                      path: path,
                      builder: (context, state) =>
                          Center(child: Text('page:$path')),
                    ),
                  ],
                ),
            ],
          ),
        ],
      );
      addTearDown(router.dispose);

      for (final scale in [1.0, 1.8]) {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              databaseProvider.overrideWithValue(database),
              serversProvider.overrideWithValue(AsyncData(servers)),
              playlistsProvider.overrideWithValue(
                const AsyncData(<Playlist>[]),
              ),
              audioPlayerProvider.overrideWithValue(player),
            ],
            child: MaterialApp.router(
              theme: buildTheme(Brightness.dark),
              locale: const Locale('zh'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              routerConfig: router,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        for (final destination in const [
          (label: '歌曲', path: '/songs'),
          (label: '专辑', path: '/albums'),
          (label: '喜欢', path: '/favorites'),
          (label: '艺术家', path: '/artists'),
          (label: '发现', path: '/home'),
        ]) {
          await tester.tap(find.bySemanticsLabel(destination.label));
          await tester.pumpAndSettle();
          expect(
            router.routeInformationProvider.value.uri.path,
            destination.path,
          );
          expect(find.text('page:${destination.path}'), findsOneWidget);
          expect(
            find.byType(BackdropFilter),
            findsNothing,
            reason: 'Shell chrome has no scrolling detail behind it to blur',
          );
          expect(tester.takeException(), isNull);
        }
      }
      await tester.pumpWidget(const SizedBox.shrink());
      semantics.dispose();
    },
  );
}
