import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramusic/l10n/app_localizations.dart';
import 'package:sakuramusic/app.dart';
import 'package:sakuramusic/audio/audio_player_provider.dart';
import 'package:sakuramusic/audio/audio_player_service.dart';
import 'package:sakuramusic/audio/equalizer_models.dart';
import 'package:sakuramusic/data/db/app_database.dart';
import 'package:sakuramusic/data/server_repository.dart';
import 'package:sakuramusic/features/welcome/widgets/add_server_dialog.dart';
import 'package:sakuramusic/features/welcome/widgets/privacy_policy_dialog.dart';

class _FakeAudioPlayerService implements AudioPlayerService {
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
  Future<void> setEqualizer(EqualizerSettings settings) async {}

  @override
  Future<void> dispose() async {}
}

void main() {
  testWidgets(
    'renders the replicated Welcome and Server Selection page on startup',
    (WidgetTester tester) async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            audioPlayerProvider.overrideWithValue(_FakeAudioPlayerService()),
            databaseProvider.overrideWithValue(database),
            serversProvider.overrideWithValue(
              const AsyncValue.data(<Server>[]),
            ),
          ],
          child: const SakuraMusicApp(),
        ),
      );
      await tester.pumpAndSettle();

      // Verify WelcomeScreen branding and cards
      expect(find.text('音流'), findsWidgets);
      expect(find.text('连接你的音乐'), findsOneWidget);
      expect(find.text('多源支持'), findsOneWidget);
      expect(find.text('无损播放'), findsOneWidget);
      expect(find.text('原生体验'), findsOneWidget);
      expect(find.text('全平台支持'), findsOneWidget);
      expect(find.text('新增服务器'), findsWidgets);
      expect(find.text('隐私政策'), findsOneWidget);
    },
  );

  testWidgets('renders and interacts with AddServerDialog', (
    WidgetTester tester,
  ) async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          audioPlayerProvider.overrideWithValue(_FakeAudioPlayerService()),
          databaseProvider.overrideWithValue(database),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('zh'),
          home: const Scaffold(body: AddServerDialog()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('新增服务器'), findsOneWidget);
    expect(find.text('服务器类型'), findsOneWidget);
    expect(find.text('Navidrome'), findsOneWidget);
    expect(find.text('Subsonic'), findsOneWidget);
    expect(find.text('测试连接'), findsOneWidget);
    expect(find.text('保存并连接'), findsOneWidget);

    // Tap test connection without required fields should trigger form validation
    await tester.ensureVisible(find.text('测试连接'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('测试连接'));
    await tester.pumpAndSettle();
    expect(find.text('请输入服务器名称'), findsOneWidget);
  });

  testWidgets('renders PrivacyPolicyDialog properly', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('zh'),
        home: const Scaffold(body: PrivacyPolicyDialog()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('隐私政策与条款'), findsOneWidget);
    expect(find.text('我知道了'), findsOneWidget);
  });
}
