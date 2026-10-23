import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramusic/audio/audio_player_provider.dart';
import 'package:sakuramusic/audio/audio_player_service.dart';
import 'package:sakuramusic/audio/equalizer_models.dart';
import 'package:sakuramusic/data/db/app_database.dart';
import 'package:sakuramusic/data/server_repository.dart';
import 'package:sakuramusic/features/lyrics_overlay/lyrics_overlay_channel.dart';
import 'package:sakuramusic/features/lyrics_overlay/lyrics_overlay_config.dart';
import 'package:sakuramusic/features/lyrics_overlay/lyrics_overlay_controller.dart';

class _FakeOverlayChannel implements LyricsOverlayChannel {
  final List<LyricsOverlayConfig> configs = <LyricsOverlayConfig>[];
  int showCalls = 0;
  int hideCalls = 0;
  void Function()? closedHandler;

  @override
  Future<bool> checkPermission() async => true;

  @override
  Future<void> requestPermission() async {}

  @override
  Future<void> show() async {
    showCalls++;
  }

  @override
  Future<void> hide() async {
    hideCalls++;
  }

  @override
  Future<void> updateLyrics({
    required String current,
    required String next,
    required bool isPlaying,
  }) async {}

  @override
  Future<void> applyConfig(LyricsOverlayConfig config) async {
    configs.add(config);
  }

  @override
  void setOverlayClosedHandler(void Function() handler) {
    closedHandler = handler;
  }
}

class _FakePlayerService implements AudioPlayerService {
  @override
  Stream<PlayerSnapshot> get snapshot => const Stream<PlayerSnapshot>.empty();

  @override
  PlayerSnapshot? get currentSnapshot => null;

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
  Future<bool> setPreferredOutputDevice(int? deviceId) async => false;

  @override
  Future<void> setEqualizer(EqualizerSettings settings) async {}

  @override
  Future<void> dispose() async {}
}

const LyricsOverlayConfig _custom = LyricsOverlayConfig(
  fontScale: 1.3,
  textColor: 0xFFFFD1DC,
  backgroundOpacity: 60,
  cornerRadiusDp: 8,
  showNextLine: false,
  showCloseButton: false,
  position: LyricsOverlayPosition.center,
);

ProviderContainer _container(_FakeOverlayChannel channel, AppDatabase db) {
  return ProviderContainer(
    overrides: [
      lyricsOverlayChannelProvider.overrideWithValue(channel),
      audioPlayerProvider.overrideWithValue(_FakePlayerService()),
      databaseProvider.overrideWithValue(db),
    ],
  );
}

void main() {
  test('an empty column loads the defaults', () async {
    final channel = _FakeOverlayChannel();
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final container = _container(channel, database);
    addTearDown(container.dispose);

    expect(
      await container.read(lyricsOverlayConfigProvider.future),
      LyricsOverlayConfig.defaults(),
    );
  });

  test('a stored appearance is restored on start', () async {
    final channel = _FakeOverlayChannel();
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    await database.saveSettings(lyricsOverlayConfig: _custom.encode());
    final container = _container(channel, database);
    addTearDown(container.dispose);

    expect(await container.read(lyricsOverlayConfigProvider.future), _custom);
    expect(channel.configs, isEmpty);
  });

  test('malformed stored JSON falls back to the defaults', () async {
    final channel = _FakeOverlayChannel();
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    await database.saveSettings(lyricsOverlayConfig: 'not json');
    final container = _container(channel, database);
    addTearDown(container.dispose);

    expect(
      await container.read(lyricsOverlayConfigProvider.future),
      LyricsOverlayConfig.defaults(),
    );
  });

  test(
    'editing while the overlay is off persists but stays off native',
    () async {
      final channel = _FakeOverlayChannel();
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final container = _container(channel, database);
      addTearDown(container.dispose);

      await container.read(lyricsOverlayConfigProvider.future);
      expect(container.read(lyricsOverlayControllerProvider), isFalse);

      await container.read(lyricsOverlayConfigProvider.notifier).apply(_custom);

      expect(channel.configs, isEmpty);
      expect(container.read(lyricsOverlayConfigProvider).value, _custom);
      expect(
        (await database.getSettings())!.lyricsOverlayConfig,
        _custom.encode(),
      );
    },
  );

  test('editing while the overlay is on pushes the live appearance', () async {
    final channel = _FakeOverlayChannel();
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final container = _container(channel, database);
    addTearDown(container.dispose);

    await container
        .read(lyricsOverlayControllerProvider.notifier)
        .setEnabled(true);
    // Enabling the window pushes the stored appearance first, so the native
    // side never starts from a stale look.
    expect(channel.configs, <LyricsOverlayConfig>[
      LyricsOverlayConfig.defaults(),
    ]);

    await container.read(lyricsOverlayConfigProvider.notifier).apply(_custom);

    expect(channel.configs, hasLength(2));
    expect(channel.configs.last, _custom);
    expect(
      (await database.getSettings())!.lyricsOverlayConfig,
      _custom.encode(),
    );
  });

  test('an unchanged appearance is neither pushed nor rewritten', () async {
    final channel = _FakeOverlayChannel();
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final container = _container(channel, database);
    addTearDown(container.dispose);

    await container.read(lyricsOverlayConfigProvider.future);
    await container
        .read(lyricsOverlayConfigProvider.notifier)
        .apply(LyricsOverlayConfig.defaults());

    expect(channel.configs, isEmpty);
  });

  test('reset restores the defaults and persists them', () async {
    final channel = _FakeOverlayChannel();
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    await database.saveSettings(lyricsOverlayConfig: _custom.encode());
    final container = _container(channel, database);
    addTearDown(container.dispose);

    await container.read(lyricsOverlayConfigProvider.future);
    await container.read(lyricsOverlayConfigProvider.notifier).reset();

    expect(
      container.read(lyricsOverlayConfigProvider).value,
      LyricsOverlayConfig.defaults(),
    );
    expect(
      (await database.getSettings())!.lyricsOverlayConfig,
      LyricsOverlayConfig.defaults().encode(),
    );
    expect(channel.configs, isEmpty);
  });
}
