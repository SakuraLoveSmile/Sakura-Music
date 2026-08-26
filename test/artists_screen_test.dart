import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramusic/core/artwork_palette.dart';
import 'package:sakuramusic/core/providers.dart';
import 'package:sakuramusic/features/artists/artist_details_screen.dart';
import 'package:sakuramusic/features/artists/artists_screen.dart';
import 'package:sakuramusic/features/shared/media_widgets.dart';
import 'package:sakuramusic/l10n/app_localizations.dart';
import 'package:subsonic_api/subsonic_api.dart';

Widget _buildTestApp(Widget child, {List<dynamic> overrides = const []}) {
  return ProviderScope(
    overrides: overrides.cast(),
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('zh'),
      home: child,
    ),
  );
}

void main() {
  group('Artist UI Components', () {
    testWidgets(
      'ArtistAvatar renders fallback initial when no client or image',
      (tester) async {
        const artist = Artist(id: '1', name: 'Taylor Swift', albumCount: 10);
        await tester.pumpWidget(
          _buildTestApp(const Scaffold(body: ArtistAvatar(artist: artist))),
        );
        await tester.pumpAndSettle();

        expect(find.text('T'), findsOneWidget);
      },
    );

    testWidgets('ArtistCard renders name and album count', (tester) async {
      const artist = Artist(id: '1', name: 'Taylor Swift', albumCount: 10);
      await tester.pumpWidget(
        _buildTestApp(
          Scaffold(
            body: SizedBox(
              width: 150,
              height: 200,
              child: ArtistCard(artist: artist, onTap: () {}),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Taylor Swift'), findsOneWidget);
      expect(find.text('10 张专辑'), findsOneWidget);
    });

    testWidgets('ArtistListTile renders name and album count', (tester) async {
      const artist = Artist(id: '1', name: 'Jay Chou', albumCount: 14);
      await tester.pumpWidget(
        _buildTestApp(
          Scaffold(
            body: ArtistListTile(artist: artist, onTap: () {}),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Jay Chou'), findsOneWidget);
      expect(find.text('14 张专辑'), findsOneWidget);
      expect(find.text('J'), findsOneWidget);
    });
  });

  group('ArtistsScreen', () {
    final mockArtists = <Artist>[
      const Artist(id: '1', name: 'Taylor Swift', albumCount: 12),
      const Artist(id: '2', name: 'Jay Chou', albumCount: 15),
      const Artist(id: '3', name: 'Adele', albumCount: 4),
    ];

    testWidgets(
      'ArtistsScreen renders in grid mode and switches to list mode',
      (tester) async {
        await tester.pumpWidget(
          _buildTestApp(
            const ArtistsScreen(),
            overrides: [
              artistsProvider.overrideWith((ref) async => mockArtists),
              activeSubsonicClientProvider.overrideWithValue(null),
            ],
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('艺术家'), findsOneWidget);
        expect(find.text('3'), findsOneWidget);
        expect(find.text('Adele'), findsOneWidget);
        expect(find.text('Jay Chou'), findsOneWidget);
        expect(find.text('Taylor Swift'), findsOneWidget);

        final switchBtn = find.byTooltip('列表视图');
        expect(switchBtn, findsOneWidget);
        await tester.tap(switchBtn);
        await tester.pumpAndSettle();

        expect(find.byTooltip('网格视图'), findsOneWidget);
      },
    );

    testWidgets('ArtistsScreen filters artists via in-page search', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildTestApp(
          const ArtistsScreen(),
          overrides: [
            artistsProvider.overrideWith((ref) async => mockArtists),
            activeSubsonicClientProvider.overrideWithValue(null),
          ],
        ),
      );
      await tester.pumpAndSettle();

      final searchBtn = find.byTooltip('搜索');
      await tester.tap(searchBtn);
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Adele');
      await tester.pumpAndSettle();

      expect(find.widgetWithText(ArtistCard, 'Adele'), findsOneWidget);
      expect(find.widgetWithText(ArtistCard, 'Taylor Swift'), findsNothing);
      expect(find.widgetWithText(ArtistCard, 'Jay Chou'), findsNothing);
    });
  });

  group('ArtistDetailsScreen', () {
    const mockArtist = Artist(
      id: 'art-1',
      name: 'Taylor Swift',
      albumCount: 2,
      albums: [
        Album(
          id: 'alb-1',
          name: '1989',
          year: 2014,
          artist: 'Taylor Swift',
          songs: [
            Song(id: 's-1', title: 'Blank Space', duration: 231),
            Song(id: 's-2', title: 'Style', duration: 231),
          ],
        ),
        Album(
          id: 'alb-2',
          name: 'Midnights',
          year: 2022,
          artist: 'Taylor Swift',
          songs: [Song(id: 's-3', title: 'Anti-Hero', duration: 200)],
        ),
      ],
    );

    const mockInfo = ArtistInfo2(
      artistId: 'art-1',
      name: 'Taylor Swift',
      biography:
          'Taylor Alison Swift is an American singer-songwriter.<br/>Read more on Last.fm',
      similarArtists: [Artist(id: 'art-2', name: 'Olivia Rodrigo')],
    );

    testWidgets(
      'ArtistDetailsScreen renders hero header, songs, albums, and similar artists',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final mockClient = SubsonicClient(
          baseUrl: 'http://localhost:4040',
          username: 'admin',
          password: 'password',
        );

        await tester.pumpWidget(
          _buildTestApp(
            const ArtistDetailsScreen(artistId: 'art-1'),
            overrides: [
              activeSubsonicClientProvider.overrideWithValue(mockClient),
              artistDetailsProvider(
                'art-1',
              ).overrideWith((ref) async => mockArtist),
              artistInfoProvider('art-1').overrideWith((ref) async => mockInfo),
              artworkPaletteProvider.overrideWith(
                (ref, url) async => const ArtworkPalette(
                  vibrant: Color(0xFF1E7BF6),
                  muted: Color(0xFF1B1C23),
                ),
              ),
            ],
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Taylor Swift'), findsAtLeastNWidgets(1));
        expect(find.text('播放全部'), findsOneWidget);
        expect(find.text('随机播放'), findsOneWidget);

        expect(find.text('关于艺术家'), findsOneWidget);
        expect(find.textContaining('Taylor Alison Swift'), findsOneWidget);
        expect(find.textContaining('<br/>'), findsNothing);

        expect(find.text('热门歌曲'), findsOneWidget);
        expect(find.text('Blank Space'), findsOneWidget);
        expect(find.text('Style'), findsOneWidget);
        expect(find.text('Anti-Hero'), findsOneWidget);

        expect(find.text('1989'), findsOneWidget);
        expect(find.text('Midnights'), findsOneWidget);

        expect(find.text('相似艺术家'), findsOneWidget);
        expect(find.text('Olivia Rodrigo'), findsOneWidget);
      },
    );
  });
}
