import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramusic/l10n/app_localizations.dart';
import 'package:sakuramusic/audio/audio_player_provider.dart';
import 'package:sakuramusic/audio/audio_player_service.dart';
import 'package:sakuramusic/audio/equalizer_models.dart';
import 'package:sakuramusic/core/providers.dart';
import 'package:sakuramusic/data/db/app_database.dart';
import 'package:sakuramusic/data/server_repository.dart';
import 'package:sakuramusic/features/player/mini_player_bar.dart';
import 'package:sakuramusic/features/player/player_screen.dart';
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

  @override
  Future<void> setQueue(List<PlayableItem> items, {int startIndex = 0}) async {}

  @override
  Future<void> play() async {}

  @override
  Future<void> pause() async {}

  @override
  Future<void> next() async {}

  @override
  Future<void> previous() async {}

  @override
  Future<void> seek(Duration position) async {}

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

      expect(find.text('Test Song Title'), findsOneWidget);
      expect(find.text('Test Artist · Test Album'), findsOneWidget);
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
}

class _FakeStarredNotifier extends StarredNotifier {
  @override
  Future<Starred2> build() async {
    return const Starred2();
  }
}
