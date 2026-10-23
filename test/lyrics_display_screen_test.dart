import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramusic/data/db/app_database.dart';
import 'package:sakuramusic/data/server_repository.dart';
import 'package:sakuramusic/data/settings_repository.dart';
import 'package:sakuramusic/features/lyrics_overlay/lyrics_overlay_channel.dart';
import 'package:sakuramusic/features/lyrics_overlay/lyrics_overlay_config.dart';
import 'package:sakuramusic/features/lyrics_overlay/lyrics_overlay_controller.dart';
import 'package:sakuramusic/features/settings/lyrics_display_screen.dart';
import 'package:sakuramusic/l10n/app_localizations.dart';

/// Stable keys the screen exposes for its appearance controls.
const Key _fontScaleSliderKey = Key('lyricsOverlayFontScaleSlider');
const Key _opacitySliderKey = Key('lyricsOverlayOpacitySlider');
const Key _cornerRadiusSliderKey = Key('lyricsOverlayCornerRadiusSlider');
const Key _nextLineSwitchKey = Key('lyricsOverlayShowNextLineSwitch');
const Key _closeButtonSwitchKey = Key('lyricsOverlayShowCloseButtonSwitch');
const Key _resetButtonKey = Key('lyricsOverlayResetButton');

/// The second (black) colour preset dot.
const Key _blackDotKey = ValueKey<String>('lyricsOverlayTextColor-0xff000000');

const Key _topChipKey = ValueKey<String>('lyricsOverlayPosition-top');
const Key _centerChipKey = ValueKey<String>('lyricsOverlayPosition-center');
const Key _bottomChipKey = ValueKey<String>('lyricsOverlayPosition-bottom');

/// Localisation fragments the Lyricon card must render, in this order.
const String _statusBarDescSnippet = '将当前播放的歌曲与歌词同步到状态栏';
const String _lyriconNoteSnippet = '状态栏歌词的外观由 Lyricon 应用自身的设置决定';

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

/// Counts appearance writes so the slider debounce is observable.
class _CountingSettingsRepository extends SettingsRepository {
  _CountingSettingsRepository(super.database);

  int configWrites = 0;
  final List<String> written = <String>[];

  @override
  Future<void> updateLyricsOverlayConfig({required String configJson}) {
    configWrites++;
    written.add(configJson);
    return super.updateLyricsOverlayConfig(configJson: configJson);
  }
}

/// Overlay reported as visible, so every appearance change is pushed to native.
class _OverlayOnController extends LyricsOverlayController {
  @override
  bool build() => true;
}

/// Never resolves: keeps the appearance section in its loading state.
class _PendingConfigController extends LyricsOverlayConfigController {
  final Completer<LyricsOverlayConfig> _completer =
      Completer<LyricsOverlayConfig>();

  @override
  Future<LyricsOverlayConfig> build() => _completer.future;
}

Future<AppDatabase> _newDatabase() async {
  final database = AppDatabase(NativeDatabase.memory());
  addTearDown(database.close);
  return database;
}

/// Mounts the screen on a tall surface so the whole `ListView` lays out and
/// every control is hit-testable.
Future<void> _pumpScreen(
  WidgetTester tester, {
  required AppDatabase database,
  _FakeOverlayChannel? channel,
  SettingsRepository? repository,
  bool overlayOn = false,
  LyricsOverlayConfigController Function()? configController,
}) async {
  tester.view.physicalSize = const Size(1000, 2600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  // Type is inferred: `Override` is not exported by flutter_riverpod 3.x.
  final overrides = [
    databaseProvider.overrideWithValue(database),
    lyricsOverlayChannelProvider.overrideWithValue(
      channel ?? _FakeOverlayChannel(),
    ),
    // Widget tests run on a desktop host: force the Android-only sections on.
    isAndroidPlatformProvider.overrideWithValue(true),
  ];
  if (repository != null) {
    overrides.add(settingsRepositoryProvider.overrideWithValue(repository));
  }
  if (overlayOn) {
    overrides.add(
      lyricsOverlayControllerProvider.overrideWith(_OverlayOnController.new),
    );
  }
  if (configController != null) {
    overrides.add(lyricsOverlayConfigProvider.overrideWith(configController));
  }

  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('zh'),
        home: const LyricsDisplayScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

ProviderContainer _containerOf(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(LyricsDisplayScreen)));

LyricsOverlayConfig _currentConfig(WidgetTester tester) =>
    _containerOf(tester).read(lyricsOverlayConfigProvider).value!;

Slider _slider(WidgetTester tester, Key key) =>
    tester.widget<Slider>(find.byKey(key));

Switch _switch(WidgetTester tester, Key key) =>
    tester.widget<Switch>(find.byKey(key));

ChoiceChip _chip(WidgetTester tester, Key key) =>
    tester.widget<ChoiceChip>(find.byKey(key));

/// Lets a pending 150ms persistence debounce fire so no timer outlives a test.
Future<void> _flushDebounce(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 200));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('默认外观：滑块初值/范围/分段、开关、位置 chip、重置按钮禁用', (tester) async {
    final database = await _newDatabase();
    await _pumpScreen(tester, database: database);

    // The Android-only appearance section really is on screen.
    expect(find.text('悬浮歌词外观'), findsOneWidget);

    final fontScale = _slider(tester, _fontScaleSliderKey);
    expect(fontScale.value, 1.0);
    expect(fontScale.divisions, 20);
    expect(fontScale.min, 0.6);
    expect(fontScale.max, 1.6);

    final opacity = _slider(tester, _opacitySliderKey);
    expect(opacity.value, 184.0);
    expect(opacity.divisions, 51);
    expect(opacity.min, 0.0);
    expect(opacity.max, 255.0);

    final cornerRadius = _slider(tester, _cornerRadiusSliderKey);
    expect(cornerRadius.value, 18.0);
    expect(cornerRadius.divisions, 32);
    expect(cornerRadius.min, 0.0);
    expect(cornerRadius.max, 32.0);

    expect(_switch(tester, _nextLineSwitchKey).value, isTrue);
    expect(_switch(tester, _closeButtonSwitchKey).value, isTrue);

    expect(_chip(tester, _topChipKey).selected, isTrue);
    expect(_chip(tester, _centerChipKey).selected, isFalse);
    expect(_chip(tester, _bottomChipKey).selected, isFalse);

    // Nothing to restore while the appearance already matches the defaults.
    expect(
      tester.widget<TextButton>(find.byKey(_resetButtonKey)).onPressed,
      isNull,
    );
  });

  testWidgets('字号滑块 onChanged(1.25) 立即把字号的 state 更新为 1.25', (tester) async {
    final database = await _newDatabase();
    await _pumpScreen(tester, database: database);

    _slider(tester, _fontScaleSliderKey).onChanged!(1.25);
    await tester.pump();

    expect(_currentConfig(tester).fontScale, 1.25);
    // The rebuilt slider mirrors the new value.
    expect(_slider(tester, _fontScaleSliderKey).value, 1.25);

    await _flushDebounce(tester);
  });

  testWidgets('圆角滑块 onChanged(8) 与不透明度滑块 onChanged(60) 各自生效', (tester) async {
    final database = await _newDatabase();
    await _pumpScreen(tester, database: database);

    _slider(tester, _cornerRadiusSliderKey).onChanged!(8);
    await tester.pump();
    expect(_currentConfig(tester).cornerRadiusDp, 8);
    expect(_slider(tester, _cornerRadiusSliderKey).value, 8.0);

    await tester.pump(const Duration(milliseconds: 10));

    _slider(tester, _opacitySliderKey).onChanged!(60);
    await tester.pump();
    final config = _currentConfig(tester);
    expect(config.backgroundOpacity, 60);
    // A later edit must not roll the earlier one back.
    expect(config.cornerRadiusDp, 8);
    expect(_slider(tester, _opacitySliderKey).value, 60.0);

    await _flushDebounce(tester);
  });

  testWidgets('点击黑色颜色点把 textColor 设为 0xFF000000', (tester) async {
    final database = await _newDatabase();
    await _pumpScreen(tester, database: database);

    expect(find.byKey(_blackDotKey), findsOneWidget);
    await tester.tap(find.byKey(_blackDotKey));
    await tester.pump();

    expect(_currentConfig(tester).textColor, 0xFF000000);
  });

  testWidgets('点击「底部」位置 chip 把 position 设为 bottom', (tester) async {
    final database = await _newDatabase();
    await _pumpScreen(tester, database: database);

    expect(_chip(tester, _bottomChipKey).selected, isFalse);
    await tester.tap(find.byKey(_bottomChipKey));
    await tester.pump();

    expect(_currentConfig(tester).position, LyricsOverlayPosition.bottom);
    expect(_chip(tester, _bottomChipKey).selected, isTrue);
    expect(_chip(tester, _topChipKey).selected, isFalse);
  });

  testWidgets('关闭两个开关分别把 showNextLine / showCloseButton 设为 false', (
    tester,
  ) async {
    final database = await _newDatabase();
    await _pumpScreen(tester, database: database);

    await tester.tap(find.byKey(_nextLineSwitchKey));
    await tester.pump();
    expect(_currentConfig(tester).showNextLine, isFalse);
    expect(_switch(tester, _nextLineSwitchKey).value, isFalse);
    expect(_currentConfig(tester).showCloseButton, isTrue);

    await tester.tap(find.byKey(_closeButtonSwitchKey));
    await tester.pump();
    final config = _currentConfig(tester);
    expect(config.showCloseButton, isFalse);
    expect(config.showNextLine, isFalse);
    expect(_switch(tester, _closeButtonSwitchKey).value, isFalse);
  });

  testWidgets('非默认配置下重置按钮可点，点击后配置恢复默认', (tester) async {
    final database = await _newDatabase();
    const custom = LyricsOverlayConfig(
      fontScale: 1.3,
      textColor: 0xFFFFD1DC,
      backgroundOpacity: 60,
      cornerRadiusDp: 8,
      showNextLine: false,
      showCloseButton: false,
      position: LyricsOverlayPosition.center,
    );
    await database.saveSettings(lyricsOverlayConfig: custom.encode());
    await _pumpScreen(tester, database: database);

    expect(_currentConfig(tester), custom);
    final reset = tester.widget<TextButton>(find.byKey(_resetButtonKey));
    expect(reset.onPressed, isNotNull);

    await tester.tap(find.byKey(_resetButtonKey));
    await tester.pumpAndSettle();

    expect(_currentConfig(tester), LyricsOverlayConfig.defaults());
    expect(_currentConfig(tester).fontScale, 1.0);
    expect(_currentConfig(tester).backgroundOpacity, 184);
    expect(_currentConfig(tester).cornerRadiusDp, 18.0);
    expect(_currentConfig(tester).position, LyricsOverlayPosition.top);
    // Back to the defaults: nothing left to restore.
    expect(
      tester.widget<TextButton>(find.byKey(_resetButtonKey)).onPressed,
      isNull,
    );
  });

  testWidgets('默认配置下重置按钮的 onPressed 为 null', (tester) async {
    final database = await _newDatabase();
    await _pumpScreen(tester, database: database);

    expect(_currentConfig(tester), LyricsOverlayConfig.defaults());
    expect(
      tester.widget<TextButton>(find.byKey(_resetButtonKey)).onPressed,
      isNull,
    );
  });

  testWidgets('Lyricon 卡片先渲染状态栏说明，再渲染外观说明', (tester) async {
    final database = await _newDatabase();
    await _pumpScreen(tester, database: database);

    final desc = find.textContaining(_statusBarDescSnippet);
    final note = find.textContaining(_lyriconNoteSnippet);
    expect(desc, findsOneWidget);
    expect(note, findsOneWidget);

    expect(tester.getTopLeft(desc).dy, lessThan(tester.getTopLeft(note).dy));
  });

  testWidgets('外观配置加载中时全部控件被禁用', (tester) async {
    final database = await _newDatabase();
    await _pumpScreen(
      tester,
      database: database,
      configController: _PendingConfigController.new,
    );

    expect(
      _containerOf(tester).read(lyricsOverlayConfigProvider).isLoading,
      isTrue,
    );

    expect(_slider(tester, _fontScaleSliderKey).onChanged, isNull);
    expect(_slider(tester, _opacitySliderKey).onChanged, isNull);
    expect(_slider(tester, _cornerRadiusSliderKey).onChanged, isNull);

    expect(_switch(tester, _nextLineSwitchKey).onChanged, isNull);
    expect(_switch(tester, _closeButtonSwitchKey).onChanged, isNull);

    expect(
      tester.widget<GestureDetector>(find.byKey(_blackDotKey)).onTap,
      isNull,
    );

    expect(_chip(tester, _topChipKey).onSelected, isNull);
    expect(_chip(tester, _centerChipKey).onSelected, isNull);
    expect(_chip(tester, _bottomChipKey).onSelected, isNull);

    expect(
      tester.widget<TextButton>(find.byKey(_resetButtonKey)).onPressed,
      isNull,
    );
  });

  testWidgets('外观配置加载完成后全部控件恢复可操作', (tester) async {
    final database = await _newDatabase();
    await _pumpScreen(tester, database: database);

    expect(
      _containerOf(tester).read(lyricsOverlayConfigProvider).isLoading,
      isFalse,
    );

    expect(_slider(tester, _fontScaleSliderKey).onChanged, isNotNull);
    expect(_slider(tester, _opacitySliderKey).onChanged, isNotNull);
    expect(_slider(tester, _cornerRadiusSliderKey).onChanged, isNotNull);
    expect(_switch(tester, _nextLineSwitchKey).onChanged, isNotNull);
    expect(_switch(tester, _closeButtonSwitchKey).onChanged, isNotNull);
    expect(
      tester.widget<GestureDetector>(find.byKey(_blackDotKey)).onTap,
      isNotNull,
    );
    expect(_chip(tester, _topChipKey).onSelected, isNotNull);
    expect(_chip(tester, _centerChipKey).onSelected, isNotNull);
    expect(_chip(tester, _bottomChipKey).onSelected, isNotNull);
    expect(tester.widget<TextButton>(find.byKey(_resetButtonKey)), isNotNull);
  });

  testWidgets('浮窗开启时字号滑块连续三次改动只写库一次且三次都下发原生', (tester) async {
    final database = await _newDatabase();
    final repository = _CountingSettingsRepository(database);
    final channel = _FakeOverlayChannel();
    await _pumpScreen(
      tester,
      database: database,
      channel: channel,
      repository: repository,
      overlayOn: true,
    );

    expect(repository.configWrites, 0);
    channel.configs.clear();

    // Three changes inside one 150ms debounce window (3 x 10ms < 150ms).
    for (final value in <double>[1.05, 1.15, 1.25]) {
      _slider(tester, _fontScaleSliderKey).onChanged!(value);
      await tester.pump(const Duration(milliseconds: 10));
    }

    // Still inside the quiet window: nothing written yet, three native pushes.
    expect(repository.configWrites, 0);
    expect(channel.configs, hasLength(3));
    expect(channel.configs.map((c) => c.fontScale).toList(), <double>[
      1.05,
      1.15,
      1.25,
    ]);
    expect(_currentConfig(tester).fontScale, 1.25);

    // Only the last value survives the debounce and reaches the database.
    await tester.pump(const Duration(milliseconds: 160));
    await tester.pumpAndSettle();

    expect(repository.configWrites, 1);
    expect(repository.written, hasLength(1));
    expect(repository.written.single, contains('"fontScale":1.25'));
    expect(_currentConfig(tester).fontScale, 1.25);
    expect(
      (await database.getSettings())!.lyricsOverlayConfig,
      contains('"fontScale":1.25'),
    );
  });
}
