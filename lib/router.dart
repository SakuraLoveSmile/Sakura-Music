import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'data/server_repository.dart';
import 'features/artists/artist_details_screen.dart';
import 'features/artists/artists_screen.dart';
import 'features/albums/album_details_screen.dart';
import 'features/albums/albums_screen.dart';
import 'features/downloads/downloads_screen.dart';
import 'features/home/home_screen.dart';
import 'features/library/library_screen.dart';
import 'features/playlists/playlist_details_screen.dart';
import 'features/playlists/playlists_screen.dart';
import 'features/player/app_shell.dart';
import 'features/player/player_screen.dart';
import 'features/search/search_screen.dart';
import 'features/settings/membership_screen.dart';
import 'features/debug/debug_screen.dart';
import 'features/settings/settings_screen.dart';
import 'features/welcome/add_server_screen.dart';
import 'features/welcome/welcome_screen.dart';

import 'features/genres/genres_screen.dart';
import 'features/radios/radios_screen.dart';
import 'features/songs/songs_screen.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>();

/// The router is a provider so its redirect can observe the same server state
/// as the rest of the application. The refresh listeners make adding or
/// removing the last server take effect without restarting the app.
final appRouterProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/home',
    redirect: (context, state) {
      final path = state.uri.path;
      final serversState = ref.read(serversProvider);
      final hasServer = ref.read(activeServerProvider) != null;
      final isSettings = path == '/settings' || path.startsWith('/settings/');
      final isWelcome = path == '/welcome';

      // Keep the initial home route visible while the local server list is
      // still loading; the refresh listener below will redirect once the
      // answer is known.
      if (!serversState.hasValue && !serversState.hasError && path == '/home') {
        return null;
      }

      if (!hasServer && !isWelcome && !isSettings) {
        return '/welcome';
      }
      if (path == '/' || path == '/library') {
        return hasServer ? '/home' : '/welcome';
      }
      return null;
    },
    routes: <RouteBase>[
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return AppShell(navigationShell: navigationShell);
        },
        branches: <StatefulShellBranch>[
          // 0: 发现 (/home)
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: '/home',
                pageBuilder: (context, state) =>
                    const NoTransitionPage(child: HomeScreen()),
              ),
            ],
          ),
          // 1: 歌曲 (/songs)
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: '/songs',
                pageBuilder: (context, state) =>
                    const NoTransitionPage(child: SongsScreen()),
              ),
            ],
          ),
          // 2: 专辑 (/albums)
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: '/albums',
                pageBuilder: (context, state) =>
                    const NoTransitionPage(child: AlbumsScreen()),
                routes: <RouteBase>[
                  GoRoute(
                    path: ':id',
                    pageBuilder: (context, state) => NoTransitionPage(
                      child: AlbumDetailsScreen(
                        albumId: state.pathParameters['id']!,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          // 3: 艺术家 (/artists)
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: '/artists',
                pageBuilder: (context, state) =>
                    const NoTransitionPage(child: ArtistsScreen()),
                routes: <RouteBase>[
                  GoRoute(
                    path: ':id',
                    pageBuilder: (context, state) => NoTransitionPage(
                      child: ArtistDetailsScreen(
                        artistId: state.pathParameters['id']!,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          // 4: 流派 (/genres)
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: '/genres',
                pageBuilder: (context, state) =>
                    const NoTransitionPage(child: GenresScreen()),
              ),
            ],
          ),
          // 5: 电台 (/radios)
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: '/radios',
                pageBuilder: (context, state) =>
                    const NoTransitionPage(child: RadiosScreen()),
              ),
            ],
          ),
          // 6: 我喜欢的 (/favorites)
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: '/favorites',
                pageBuilder: (context, state) =>
                    const NoTransitionPage(child: LibraryScreen()),
              ),
            ],
          ),
          // 7: 下载管理 (/downloads)
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: '/downloads',
                pageBuilder: (context, state) =>
                    const NoTransitionPage(child: DownloadsScreen()),
              ),
            ],
          ),
          // 8: 我的歌单 (/playlists)
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: '/playlists',
                pageBuilder: (context, state) =>
                    const NoTransitionPage(child: PlaylistsScreen()),
                routes: <RouteBase>[
                  GoRoute(
                    path: ':id',
                    pageBuilder: (context, state) => NoTransitionPage(
                      child: PlaylistDetailsScreen(
                        playlistId: state.pathParameters['id']!,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/search',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) =>
            const NoTransitionPage(child: SearchScreen()),
      ),
      GoRoute(
        path: '/welcome',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) =>
            const NoTransitionPage(child: WelcomeScreen()),
      ),
      GoRoute(
        path: '/membership',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) =>
            const NoTransitionPage(child: MembershipScreen()),
      ),
      GoRoute(
        path: '/settings',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) =>
            const NoTransitionPage(child: SettingsScreen()),
      ),
      GoRoute(
        path: '/debug',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) =>
            const MaterialPage(child: DebugScreen()),
      ),
      GoRoute(
        path: '/add-server',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) =>
            const MaterialPage(child: AddServerScreen()),
      ),
      GoRoute(
        path: '/add-server/config',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) => MaterialPage(
          child: AddServerConfigScreen(
            args: state.extra is AddServerConfigArgs
                ? state.extra as AddServerConfigArgs
                : null,
          ),
        ),
      ),
      // Keep the player above the shell so it has no rail, bottom navigation,
      // or mini-player duplication while it is open.
      GoRoute(
        path: '/player',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) =>
            const MaterialPage(fullscreenDialog: true, child: PlayerScreen()),
      ),
    ],
  );

  ref.listen(serversProvider, (previous, next) => router.refresh());
  ref.listen(selectedServerIdProvider, (previous, next) => router.refresh());
  ref.onDispose(router.dispose);
  return router;
});
