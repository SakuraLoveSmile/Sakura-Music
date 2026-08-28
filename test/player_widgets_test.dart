import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramusic/audio/audio_player_provider.dart';
import 'package:sakuramusic/audio/audio_player_service.dart';
import 'package:sakuramusic/audio/equalizer_models.dart';
import 'package:sakuramusic/audio/playable_item_builder.dart';
import 'package:sakuramusic/core/providers.dart';
import 'package:sakuramusic/data/db/app_database.dart';
import 'package:sakuramusic/data/server_repository.dart';
import 'package:sakuramusic/features/player/audio_stream_inspector_sheet.dart';
import 'package:sakuramusic/features/player/lyrics/lyrics_parser.dart';
import 'package:sakuramusic/features/player/lyrics/lyrics_service.dart';
import 'package:sakuramusic/features/player/lyrics/lyrics_share_dialog.dart';
import 'package:sakuramusic/features/player/lyrics/lyrics_view.dart';
import 'package:sakuramusic/features/player/lyrics/oled_lyrics_stage.dart';
import 'package:sakuramusic/features/player/mini_player_bar.dart';
import 'package:sakuramusic/features/player/player_screen.dart';
import 'package:sakuramusic/features/player/quick_add_to_playlist_sheet.dart';
import 'package:sakuramusic/features/shared/media_widgets.dart';
import 'package:sakuramusic/l10n/app_localizations.dart';
import 'package:subsonic_api/subsonic_api.dart';

class _TestAudioPlayerService implements AudioPlayerService {
  _TestAudioPlayerService();

  final _controller = StreamController<PlayerSnapshot>.broadcast();

  @override
  Stream<PlayerSnapshot> get snapshot => _controller.stream;

  @override
  PlayerSnapshot? get currentSnapshot => null;

  void emit(PlayerSnapshot state) {
    _controller.add(state);
  }

  int playCount = 0;
  int pauseCount = 0;
  int nextCount = 0;
  int prevCount = 0;
  Duration? lastSeek;

  @override
  Future<void> setQueue(List<PlayableItem> items, {int startIndex = 0}) async {}

  @override
  Future<void> play() async {
    playCount++;
  }

  @override
  Future<void> pause() async {
    pauseCount++;
  }

  @override
  Future<void> next() async {
    nextCount++;
  }

  @override
  Future<void> previous() async {
    prevCount++;
  }

  @override
  Future<void> seek(Duration position) async {
    lastSeek = position;
  }

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
  Future<bool> setPreferredOutputDevice(int? deviceId) async => false;

  @override
  Future<void> setEqualizer(EqualizerSettings settings) async {}

  @override
  Future<void> dispose() async {
    await _controller.close();
  }
}

void main() {
  const sampleItem = PlayableItem(
    id: 'song-1',
    title: 'Test Song Title',
    artist: 'Test Artist',
    album: 'Test Album',
    streamUrl: 'http://localhost/stream',
    duration: Duration(minutes: 3, seconds: 45),
  );

  testWidgets('MiniPlayerBar renders item information and controls', (
    WidgetTester tester,
  ) async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final service = _TestAudioPlayerService();
    addTearDown(service.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(database),
          serversProvider.overrideWithValue(const AsyncValue.data(<Server>[])),
          starredProvider.overrideWith(() => _FakeStarredNotifier()),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('zh'),
          home: Scaffold(body: MiniPlayerBar(service: service)),
        ),
      ),
    );

    service.emit(
      const PlayerSnapshot(
        status: PlayerStatus.ready,
        playing: true,
        currentItem: sampleItem,
        position: Duration(minutes: 1),
        duration: Duration(minutes: 3, seconds: 45),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Test Song Title'), findsOneWidget);
    expect(find.text('Test Artist'), findsOneWidget);
    expect(find.byIcon(Icons.pause_rounded), findsOneWidget);
    expect(find.byIcon(Icons.skip_next_rounded), findsOneWidget);
    expect(find.byIcon(Icons.queue_music_rounded), findsOneWidget);
  });

  testWidgets(
    'MiniPlayerBar stays compact without queue controls on narrow widths',
    (WidgetTester tester) async {
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final service = _TestAudioPlayerService();
      addTearDown(service.dispose);

      for (final width in <double>[320, 360]) {
        tester.view.physicalSize = Size(width, 800);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              databaseProvider.overrideWithValue(database),
              serversProvider.overrideWithValue(
                const AsyncValue.data(<Server>[]),
              ),
              starredProvider.overrideWith(() => _FakeStarredNotifier()),
            ],
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              locale: const Locale('zh'),
              home: Scaffold(body: MiniPlayerBar(service: service)),
            ),
          ),
        );
        service.emit(
          const PlayerSnapshot(
            status: PlayerStatus.ready,
            currentItem: sampleItem,
            duration: Duration(minutes: 3, seconds: 45),
          ),
        );
        await tester.pump();

        expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
        expect(find.byIcon(Icons.skip_next_rounded), findsOneWidget);
        expect(find.byIcon(Icons.queue_music_rounded), findsNothing);
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets(
    'PlayerScreen renders close button, shuffle, and loop mode buttons',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final service = _TestAudioPlayerService();
      addTearDown(service.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            audioPlayerProvider.overrideWithValue(service),
            databaseProvider.overrideWithValue(database),
            serversProvider.overrideWithValue(
              const AsyncValue.data(<Server>[]),
            ),
            starredProvider.overrideWith(() => _FakeStarredNotifier()),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('zh'),
            home: const Scaffold(body: PlayerScreen()),
          ),
        ),
      );

      service.emit(
        const PlayerSnapshot(
          status: PlayerStatus.ready,
          playing: true,
          currentItem: sampleItem,
          position: Duration(minutes: 1),
          duration: Duration(minutes: 3, seconds: 45),
          shuffle: true,
          loopMode: AppLoopMode.all,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Test Song Title'), findsAtLeastNWidgets(1));
      expect(find.text('Test Artist · Test Album'), findsAtLeastNWidgets(1));
      expect(find.byIcon(Icons.keyboard_arrow_down_rounded), findsOneWidget);
      expect(find.byIcon(Icons.shuffle_rounded), findsOneWidget);
      expect(find.byIcon(Icons.skip_previous_rounded), findsOneWidget);
      expect(find.byIcon(Icons.pause_rounded), findsOneWidget);
      expect(find.byIcon(Icons.skip_next_rounded), findsOneWidget);
      expect(find.byIcon(Icons.repeat_rounded), findsOneWidget);
    },
  );

  testWidgets(
    'PlayerScreen fits narrow mobile widths and exposes secondary controls',
    (WidgetTester tester) async {
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final service = _TestAudioPlayerService();
      addTearDown(service.dispose);

      for (final width in <double>[360, 390, 430]) {
        tester.view.physicalSize = Size(width, 800);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              audioPlayerProvider.overrideWithValue(service),
              databaseProvider.overrideWithValue(database),
              serversProvider.overrideWithValue(
                const AsyncValue.data(<Server>[]),
              ),
              starredProvider.overrideWith(() => _FakeStarredNotifier()),
            ],
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              locale: const Locale('zh'),
              home: const PlayerScreen(),
            ),
          ),
        );
        service.emit(
          const PlayerSnapshot(
            status: PlayerStatus.ready,
            playing: true,
            currentItem: sampleItem,
            position: Duration(minutes: 1),
            duration: Duration(minutes: 3, seconds: 45),
            shuffle: true,
            loopMode: AppLoopMode.all,
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.byIcon(Icons.shuffle_rounded), findsOneWidget);
        expect(find.byIcon(Icons.repeat_rounded), findsOneWidget);
        expect(find.byIcon(Icons.queue_music_rounded), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets(
    'PlayerScreen toggles between Cover View and Lyrics View and opens speed modal',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final service = _TestAudioPlayerService();
      addTearDown(service.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            audioPlayerProvider.overrideWithValue(service),
            databaseProvider.overrideWithValue(database),
            serversProvider.overrideWithValue(
              const AsyncValue.data(<Server>[]),
            ),
            starredProvider.overrideWith(() => _FakeStarredNotifier()),
          ],
          child: MaterialApp(
            theme: ThemeData(platform: TargetPlatform.android),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('zh'),
            home: const Scaffold(body: PlayerScreen()),
          ),
        ),
      );

      service.emit(
        const PlayerSnapshot(
          status: PlayerStatus.ready,
          playing: true,
          currentItem: sampleItem,
          position: Duration(minutes: 1),
          duration: Duration(minutes: 3, seconds: 45),
          speed: 1.0,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Check default cover view switcher entries
      expect(find.text('封面'), findsOneWidget);
      expect(find.text('歌词'), findsOneWidget);
      expect(find.byType(OledLyricsStage), findsNothing);

      // Tap Lyrics Mode
      await tester.tap(find.text('歌词'));
      await tester.pumpAndSettle();

      // Tap speed selector in mobile bottom bar
      expect(find.text('1.0x'), findsOneWidget);
      await tester.tap(find.text('1.0x'));
      await tester.pumpAndSettle();

      // Expect speed modal
      expect(find.text('播放速度'), findsOneWidget);
      expect(find.text('1.0x (标准)'), findsOneWidget);
      expect(find.text('1.25x'), findsOneWidget);
    },
  );

  testWidgets(
    'Mobile (Android) narrow player defaults to cover and exposes the three mode entries',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final service = _TestAudioPlayerService();
      addTearDown(service.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            audioPlayerProvider.overrideWithValue(service),
            databaseProvider.overrideWithValue(database),
            serversProvider.overrideWithValue(
              const AsyncValue.data(<Server>[]),
            ),
            starredProvider.overrideWith(() => _FakeStarredNotifier()),
          ],
          child: MaterialApp(
            theme: ThemeData(platform: TargetPlatform.android),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('zh'),
            home: const Scaffold(body: PlayerScreen()),
          ),
        ),
      );

      service.emit(
        const PlayerSnapshot(
          status: PlayerStatus.ready,
          playing: true,
          currentItem: sampleItem,
          position: Duration(minutes: 1),
          duration: Duration(minutes: 3, seconds: 45),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Default is cover mode: no OLED stage, no lyrics view.
      expect(find.text('封面'), findsOneWidget);
      expect(find.text('歌词'), findsOneWidget);
      expect(find.text('纯黑歌词'), findsOneWidget);
      expect(find.byType(OledLyricsStage), findsNothing);
      expect(find.byType(LyricsView), findsNothing);
    },
  );

  testWidgets('Tapping lyrics mode shows only the ordinary lyrics stage', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final service = _TestAudioPlayerService();
    addTearDown(service.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          audioPlayerProvider.overrideWithValue(service),
          databaseProvider.overrideWithValue(database),
          serversProvider.overrideWithValue(const AsyncValue.data(<Server>[])),
          starredProvider.overrideWith(() => _FakeStarredNotifier()),
        ],
        child: MaterialApp(
          theme: ThemeData(platform: TargetPlatform.android),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('zh'),
          home: const Scaffold(body: PlayerScreen()),
        ),
      ),
    );

    service.emit(
      const PlayerSnapshot(
        status: PlayerStatus.ready,
        playing: true,
        currentItem: sampleItem,
        position: Duration(minutes: 1),
        duration: Duration(minutes: 3, seconds: 45),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.text('歌词'));
    await tester.pumpAndSettle();

    expect(find.byType(LyricsView), findsOneWidget);
    expect(find.byType(OledLyricsStage), findsNothing);
  });

  testWidgets(
    'Tapping OLED lyrics shows the OLED stage with a pure black root and no bottom dock',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final service = _TestAudioPlayerService();
      addTearDown(service.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            audioPlayerProvider.overrideWithValue(service),
            databaseProvider.overrideWithValue(database),
            serversProvider.overrideWithValue(
              const AsyncValue.data(<Server>[]),
            ),
            starredProvider.overrideWith(() => _FakeStarredNotifier()),
          ],
          child: MaterialApp(
            theme: ThemeData(platform: TargetPlatform.android),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('zh'),
            home: const Scaffold(body: PlayerScreen()),
          ),
        ),
      );

      service.emit(
        const PlayerSnapshot(
          status: PlayerStatus.ready,
          playing: true,
          currentItem: sampleItem,
          position: Duration(minutes: 1),
          duration: Duration(minutes: 3, seconds: 45),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.text('纯黑歌词'));
      await tester.pumpAndSettle();

      // OLED stage is present.
      expect(find.byType(OledLyricsStage), findsOneWidget);

      // Root background is strictly black.
      expect(
        find.byWidgetPredicate(
          (widget) => widget is Container && widget.color == Colors.black,
        ),
        findsWidgets,
      );

      // The ordinary bottom dock (shuffle / queue) is not drawn.
      expect(find.byIcon(Icons.shuffle_rounded), findsNothing);
      expect(find.byIcon(Icons.queue_music_rounded), findsNothing);
      expect(find.byIcon(Icons.repeat_rounded), findsNothing);
    },
  );

  testWidgets('OLED exit button returns the player to cover mode', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final service = _TestAudioPlayerService();
    addTearDown(service.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          audioPlayerProvider.overrideWithValue(service),
          databaseProvider.overrideWithValue(database),
          serversProvider.overrideWithValue(const AsyncValue.data(<Server>[])),
          starredProvider.overrideWith(() => _FakeStarredNotifier()),
        ],
        child: MaterialApp(
          theme: ThemeData(platform: TargetPlatform.android),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('zh'),
          home: const Scaffold(body: PlayerScreen()),
        ),
      ),
    );

    service.emit(
      const PlayerSnapshot(
        status: PlayerStatus.ready,
        playing: true,
        currentItem: sampleItem,
        position: Duration(minutes: 1),
        duration: Duration(minutes: 3, seconds: 45),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.text('纯黑歌词'));
    await tester.pumpAndSettle();
    expect(find.byType(OledLyricsStage), findsOneWidget);

    // Tap screen to reveal HUD overlay, then tap back button
    await tester.tap(find.byType(OledLyricsStage));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await tester.pumpAndSettle();

    expect(find.byType(OledLyricsStage), findsNothing);
    expect(find.byType(LyricsView), findsNothing);
    // The switcher is available again in cover mode.
    expect(find.text('封面'), findsOneWidget);
  });

  testWidgets('Wide player screen does not expose the OLED mode entry', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final service = _TestAudioPlayerService();
    addTearDown(service.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          audioPlayerProvider.overrideWithValue(service),
          databaseProvider.overrideWithValue(database),
          serversProvider.overrideWithValue(const AsyncValue.data(<Server>[])),
          starredProvider.overrideWith(() => _FakeStarredNotifier()),
        ],
        child: MaterialApp(
          theme: ThemeData(platform: TargetPlatform.android),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('zh'),
          home: const Scaffold(body: PlayerScreen()),
        ),
      ),
    );

    service.emit(
      const PlayerSnapshot(
        status: PlayerStatus.ready,
        playing: true,
        currentItem: sampleItem,
        position: Duration(minutes: 1),
        duration: Duration(minutes: 3, seconds: 45),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('纯黑歌词'), findsNothing);
    expect(find.byType(OledLyricsStage), findsNothing);
  });

  testWidgets(
    'Desktop platform does not expose the OLED mode entry even on narrow widths',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final service = _TestAudioPlayerService();
      addTearDown(service.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            audioPlayerProvider.overrideWithValue(service),
            databaseProvider.overrideWithValue(database),
            serversProvider.overrideWithValue(
              const AsyncValue.data(<Server>[]),
            ),
            starredProvider.overrideWith(() => _FakeStarredNotifier()),
          ],
          child: MaterialApp(
            theme: ThemeData(platform: TargetPlatform.macOS),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('zh'),
            home: const Scaffold(body: PlayerScreen()),
          ),
        ),
      );

      service.emit(
        const PlayerSnapshot(
          status: PlayerStatus.ready,
          playing: true,
          currentItem: sampleItem,
          position: Duration(minutes: 1),
          duration: Duration(minutes: 3, seconds: 45),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('纯黑歌词'), findsNothing);
      expect(find.text('封面'), findsNothing);
      expect(find.byType(OledLyricsStage), findsNothing);
    },
  );

  testWidgets('OledLyricsStage toggles play/pause on double tap', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(844, 390);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final service = _TestAudioPlayerService();
    addTearDown(service.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          lyricsProvider.overrideWith(
            (ref, query) async => const <ParsedLyricsLine>[],
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('zh'),
          home: Scaffold(
            body: OledLyricsStage(
              service: service,
              item: sampleItem,
              playing: true,
              duration: const Duration(minutes: 3, seconds: 45),
              onExit: () {},
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Double tap on OLED stage to pause
    await tester.tap(find.byType(OledLyricsStage));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.byType(OledLyricsStage));
    await tester.pumpAndSettle();

    expect(service.pauseCount, 1);
  });

  testWidgets(
    'OledLyricsStage toggles HUD visibility on single tap and auto-hides after 3.5s',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(844, 390);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final service = _TestAudioPlayerService();
      addTearDown(service.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            lyricsProvider.overrideWith(
              (ref, query) async => const <ParsedLyricsLine>[],
            ),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('zh'),
            home: Scaffold(
              body: OledLyricsStage(
                service: service,
                item: sampleItem,
                playing: false,
                duration: const Duration(minutes: 3, seconds: 45),
                onExit: () {},
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Initially, controls overlay is opacity 0
      final animatedOpacityFinder = find.byWidgetPredicate(
        (widget) =>
            widget is AnimatedOpacity &&
            widget.duration == const Duration(milliseconds: 250),
      );
      expect(animatedOpacityFinder, findsOneWidget);
      final initialOpacity = tester
          .widget<AnimatedOpacity>(animatedOpacityFinder)
          .opacity;
      expect(initialOpacity, 0.0);

      // Single tap reveals HUD overlay
      await tester.tap(find.byType(OledLyricsStage));
      await tester.pump(const Duration(milliseconds: 300));

      final visibleOpacity = tester
          .widget<AnimatedOpacity>(animatedOpacityFinder)
          .opacity;
      expect(visibleOpacity, 1.0);

      // Wait 3.5 seconds for auto-hide
      await tester.pump(const Duration(milliseconds: 3600));
      await tester.pump(const Duration(milliseconds: 300));

      final hiddenOpacity = tester
          .widget<AnimatedOpacity>(animatedOpacityFinder)
          .opacity;
      expect(hiddenOpacity, 0.0);
    },
  );

  testWidgets(
    'OledLyricsStage renders synced lyrics with translation, highlights active line, and seeks on tap',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(844, 390);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final service = _TestAudioPlayerService();
      addTearDown(service.dispose);

      const parsedLyrics = <ParsedLyricsLine>[
        ParsedLyricsLine(timeMs: 0, text: 'First Line'),
        ParsedLyricsLine(
          timeMs: 5000,
          text: 'Second Line\nSecond Line Translation',
        ),
        ParsedLyricsLine(timeMs: 10000, text: 'Third Line'),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            lyricsProvider.overrideWith((ref, query) async => parsedLyrics),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('zh'),
            home: Scaffold(
              body: OledLyricsStage(
                service: service,
                item: sampleItem,
                playing: true,
                duration: const Duration(minutes: 3, seconds: 45),
                onExit: () {},
              ),
            ),
          ),
        ),
      );

      service.emit(
        const PlayerSnapshot(
          status: PlayerStatus.ready,
          playing: true,
          currentItem: sampleItem,
          position: Duration(milliseconds: 5500),
          duration: Duration(minutes: 3, seconds: 45),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('First Line'), findsOneWidget);
      expect(find.text('Second Line'), findsOneWidget);
      expect(find.text('Second Line Translation'), findsOneWidget);
      expect(find.text('Third Line'), findsOneWidget);

      // Tap on the third lyric line to seek to 10000ms
      await tester.tap(find.text('Third Line'));
      await tester.pump(const Duration(milliseconds: 400));

      expect(service.lastSeek, const Duration(milliseconds: 10000));
    },
  );

  testWidgets(
    'OledLyricsStage PopScope triggers onExit callback on system pop',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(844, 390);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final service = _TestAudioPlayerService();
      addTearDown(service.dispose);

      var exitCalled = false;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            lyricsProvider.overrideWith(
              (ref, query) async => const <ParsedLyricsLine>[],
            ),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('zh'),
            home: Scaffold(
              body: OledLyricsStage(
                service: service,
                item: sampleItem,
                playing: false,
                duration: const Duration(minutes: 3, seconds: 45),
                onExit: () => exitCalled = true,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Trigger pop via PopScope
      final popScopeFinder = find.byWidgetPredicate((w) => w is PopScope);
      expect(popScopeFinder, findsOneWidget);
      final dynamic popScopeWidget = tester.widget(popScopeFinder);
      popScopeWidget.onPopInvokedWithResult(false, null);

      expect(exitCalled, isTrue);
    },
  );

  group('Song cover art resolution and widgets', () {
    final client = SubsonicClient(
      baseUrl: 'https://music.example.com',
      username: 'user',
      password: 'pwd',
    );

    test(
      'resolveSongCoverArtId prioritizes explicit coverArt, then albumId, then song.id',
      () {
        const songWithAll = Song(
          id: 's-1',
          title: 'Song 1',
          coverArt: 'cover-100',
          albumId: 'alb-200',
        );
        expect(resolveSongCoverArtId(songWithAll), 'cover-100');

        const songWithAlbumId = Song(
          id: 's-1',
          title: 'Song 1',
          albumId: 'alb-200',
        );
        expect(resolveSongCoverArtId(songWithAlbumId), 'alb-200');

        const songWithIdOnly = Song(id: 's-1', title: 'Song 1');
        expect(resolveSongCoverArtId(songWithIdOnly), 's-1');

        const emptySong = Song(id: '', title: '');
        expect(resolveSongCoverArtId(emptySong), isNull);
      },
    );

    test('resolveSongCoverUrl returns full URL with coverId', () {
      const song = Song(id: 's-1', title: 'Song 1', albumId: 'alb-200');
      final url = resolveSongCoverUrl(song: song, client: client, size: 120);
      expect(url, isNotNull);
      expect(url, contains('getCoverArt'));
      expect(url, contains('id=alb-200'));
      expect(url, contains('size=120'));
    });

    test(
      'playableItemForSong falls back to albumId and songId for artwork',
      () {
        const song = Song(id: 's-99', title: 'Track', albumId: 'alb-99');
        final item = playableItemForSong(client, song);
        expect(item.artworkUrl, contains('id=alb-99'));
        expect(item.artworkCacheKey, 'cover_alb-99_600');
      },
    );

    testWidgets('SongGridTile displays cover from albumId fallback', (
      tester,
    ) async {
      const song = Song(
        id: 's-1',
        title: 'Recent Song',
        artist: 'Artist',
        album: 'Album',
        albumId: 'alb-1',
      );

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('zh'),
          home: Scaffold(
            body: SongGridTile(song: song, client: client, onTap: () {}),
          ),
        ),
      );

      final imageFinder = find.byType(CachedNetworkImage);
      expect(imageFinder, findsOneWidget);
      final cachedImage = tester.widget<CachedNetworkImage>(imageFinder);
      expect(cachedImage.imageUrl, contains('id=alb-1'));
      expect(cachedImage.cacheKey, 'cover_alb-1_120');
      expect(find.text('Recent Song'), findsOneWidget);
    });

    testWidgets('SongListTile displays cover from song.id fallback', (
      tester,
    ) async {
      const song = Song(id: 's-42', title: 'Top Song', artist: 'Artist');

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('zh'),
          home: Scaffold(
            body: SongListTile(song: song, client: client, onTap: () {}),
          ),
        ),
      );

      final imageFinder = find.byType(CachedNetworkImage);
      expect(imageFinder, findsOneWidget);
      final cachedImage = tester.widget<CachedNetworkImage>(imageFinder);
      expect(cachedImage.imageUrl, contains('id=s-42'));
      expect(cachedImage.cacheKey, 'cover_s-42_96');
      expect(find.text('Top Song'), findsOneWidget);
    });

    test('AudioQualityInfo calculates correct tiers and specs', () {
      // 1. Hi-Res FLAC
      const itemHiRes = PlayableItem(
        id: 's-1',
        title: 'Song 1',
        streamUrl: 'http://example.com/stream/s-1.flac',
      );
      const songHiRes = Song(id: 's-1', title: 'Song 1', suffix: 'FLAC', bitRate: 1107);
      final infoHiRes = AudioQualityInfo.fromItem(itemHiRes, song: songHiRes);
      expect(infoHiRes.tier, AudioQualityTier.hiRes);
      expect(infoHiRes.codec, 'FLAC');
      expect(infoHiRes.badgeLabel, contains('Hi-Res'));
      expect(infoHiRes.badgeLabel, contains('FLAC'));
      expect(infoHiRes.badgeLabel, contains('1107k'));

      // 2. Standard Lossless (16bit / 44.1k)
      const songLossless = Song(id: 's-2', title: 'Song 2', suffix: 'ALAC', bitRate: 750);
      final infoLossless = AudioQualityInfo.fromItem(itemHiRes, song: songLossless);
      expect(infoLossless.tier, AudioQualityTier.lossless);
      expect(infoLossless.codec, 'ALAC');

      // 3. Lossy Standard
      const songMp3 = Song(id: 's-3', title: 'Song 3', suffix: 'MP3', bitRate: 192);
      final infoMp3 = AudioQualityInfo.fromItem(itemHiRes, song: songMp3);
      expect(infoMp3.tier, AudioQualityTier.standard);
      expect(infoMp3.codec, 'MP3');
    });

    testWidgets('AudioStreamQualityBadge renders and opens inspector modal', (
      tester,
    ) async {
      const item = PlayableItem(
        id: 's-hires',
        title: 'Hi-Res Symphony',
        artist: 'Master Artist',
        streamUrl: 'http://example.com/stream/hires.flac',
      );
      const song = Song(
        id: 's-hires',
        title: 'Hi-Res Symphony',
        artist: 'Master Artist',
        suffix: 'FLAC',
        bitRate: 1411,
      );

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('zh'),
          home: const Scaffold(
            body: Center(
              child: AudioStreamQualityBadge(item: item, song: song),
            ),
          ),
        ),
      );

      expect(find.textContaining('Hi-Res'), findsOneWidget);
      expect(find.textContaining('FLAC'), findsOneWidget);

      // Tap badge to open Audio Stream Inspector
      await tester.tap(find.byType(AudioStreamQualityBadge));
      await tester.pumpAndSettle();

      expect(find.text('音频流参数'), findsOneWidget);
      expect(find.text('Hi-Res Symphony'), findsOneWidget);
      expect(find.text('编码格式'), findsOneWidget);
      expect(find.text('FLAC'), findsOneWidget);
      expect(find.text('1411 kbps'), findsOneWidget);
    });

    testWidgets('LyricsShareDialog renders preview and switches card themes', (
      tester,
    ) async {
      const item = PlayableItem(
        id: 's-song',
        title: 'Sakura Song',
        artist: 'Sakura Artist',
        streamUrl: 'http://example.com/s.mp3',
      );
      final lines = <ParsedLyricsLine>[
        const ParsedLyricsLine(timeMs: 1000, text: 'First line of poem'),
        const ParsedLyricsLine(timeMs: 5000, text: 'Second line with emotion'),
        const ParsedLyricsLine(timeMs: 9000, text: 'Third line reaches chorus'),
      ];

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('zh'),
          home: Scaffold(
            body: LyricsShareDialog(
              item: item,
              lines: lines,
              initialIndex: 0,
            ),
          ),
        ),
      );

      expect(find.text('歌词海报'), findsOneWidget);
      expect(find.text('Sakura Song'), findsOneWidget);
      expect(find.text('First line of poem'), findsOneWidget);
      expect(find.text('复制歌词'), findsOneWidget);
      expect(find.text('保存海报'), findsOneWidget);

      // Switch theme to Frosted Glass
      await tester.tap(find.text('磨砂玻璃'));
      await tester.pumpAndSettle();
      expect(find.text('磨砂玻璃'), findsOneWidget);

      // Toggle line 2
      await tester.tap(find.text('L2'));
      await tester.pumpAndSettle();
      expect(find.text('Second line with emotion'), findsOneWidget);
    });

    testWidgets('QuickAddToPlaylistSheet renders playlist options', (
      tester,
    ) async {
      const item = PlayableItem(
        id: 's-track',
        title: 'Dream Track',
        artist: 'Dreamer',
        streamUrl: 'http://example.com/stream/track.mp3',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            playlistsProvider.overrideWith((ref) async => const <Playlist>[
                  Playlist(id: 'pl-1', name: 'My Favorites', songCount: 12),
                  Playlist(id: 'pl-2', name: 'Anime OST', songCount: 45),
                ]),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('zh'),
            home: const Scaffold(
              body: QuickAddToPlaylistSheet(item: item),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('选择歌单'), findsOneWidget);
      expect(find.text('新建歌单并添加'), findsOneWidget);
      expect(find.text('My Favorites'), findsOneWidget);
      expect(find.text('Anime OST'), findsOneWidget);
    });
  });
}

class _FakeStarredNotifier extends StarredNotifier {
  @override
  Future<Starred2> build() async {
    return const Starred2();
  }
}
