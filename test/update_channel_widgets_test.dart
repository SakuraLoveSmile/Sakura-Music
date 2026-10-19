import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:sakuramusic/core/update/update_channel.dart';
import 'package:sakuramusic/core/update/update_models.dart';
import 'package:sakuramusic/core/update/update_providers.dart';
import 'package:sakuramusic/data/db/app_database.dart';
import 'package:sakuramusic/data/server_repository.dart';
import 'package:sakuramusic/data/settings_repository.dart';
import 'package:sakuramusic/features/settings/settings_screen.dart';
import 'package:sakuramusic/features/settings/widgets/update_dialog.dart';
import 'package:sakuramusic/l10n/app_localizations.dart';

class _Settings extends SettingsRepository {
  _Settings(super.database);
  Completer<void>? loadGate;
  Completer<void>? saveGate;
  bool failSave = false;

  @override
  Future<Setting?> read() async {
    await loadGate?.future;
    return super.read();
  }

  @override
  Future<void> updateUpdateChannel({required String updateChannel}) async {
    await saveGate?.future;
    if (failSave) throw StateError('isolated failure');
    await super.updateUpdateChannel(updateChannel: updateChannel);
  }
}

class _Updates extends UpdateController {
  _Updates([this.initial = const UpdateState()]);
  final UpdateState initial;
  final channels = <UpdateChannel>[];

  @override
  UpdateState build() => initial;

  void showState(UpdateState value) => state = value;

  @override
  Future<void> setChannel(UpdateChannel channel) async {
    channels.add(channel);
    await ref.read(updateChannelProvider.notifier).setChannel(channel);
  }
}

void main() {
  late AppDatabase database;
  late _Settings settings;
  late _Updates updates;
  late ProviderContainer container;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    settings = _Settings(database);
    updates = _Updates();
  });

  Future<void> mount(
    WidgetTester tester, {
    Locale locale = const Locale('zh'),
    Widget? home,
  }) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(database),
        settingsRepositoryProvider.overrideWithValue(settings),
        activeServerProvider.overrideWithValue(null),
        serversProvider.overrideWithValue(const AsyncData(<Server>[])),
        appVersionProvider.overrideWith(
          (ref) async => PackageInfo(
            appName: 'Isolated test',
            packageName: 'test.music',
            version: '0.3.1',
            buildNumber: '1792423078',
          ),
        ),
        updateControllerProvider.overrideWith(() => updates),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await database.close();
    });
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: home ?? const SettingsScreen(),
        ),
      ),
    );
    await tester.pump();
  }

  Future<void> revealChannel(WidgetTester tester, String label) async {
    await tester.scrollUntilVisible(find.text(label), 400);
    await tester.pump();
  }

  InkWell channelTile(WidgetTester tester, String label) =>
      tester.widget<InkWell>(
        find
            .ancestor(of: find.text(label), matching: find.byType(InkWell))
            .first,
      );

  testWidgets(
    'selection persists through the update controller and locks while saving',
    (tester) async {
      await mount(tester);
      await tester.pumpAndSettle();
      await revealChannel(tester, '更新渠道');
      double chevronX(String label) {
        final tile = find
            .ancestor(of: find.text(label), matching: find.byType(InkWell))
            .first;
        return tester
            .getCenter(
              find.descendant(
                of: tile,
                matching: find.byIcon(Icons.chevron_right_rounded),
              ),
            )
            .dx;
      }

      expect(chevronX('更新渠道'), chevronX('当前版本'));
      expect(chevronX('语言'), chevronX('当前版本'));
      await tester.tap(find.text('更新渠道'));
      await tester.pumpAndSettle();
      expect(find.text('仅接收稳定版本'), findsOneWidget);
      expect(find.text('接收正式版和测试版本'), findsOneWidget);
      expect(find.byIcon(Icons.check), findsOneWidget);
      settings.saveGate = Completer<void>();
      await tester.tap(find.text('测试版'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(updates.channels, [UpdateChannel.prerelease]);
      expect(channelTile(tester, '更新渠道').onTap, isNull);
      expect(container.read(updateChannelProvider).value, UpdateChannel.stable);
      settings.saveGate!.complete();
      await tester.pumpAndSettle();
      expect((await database.getSettings())!.updateChannel, 'prerelease');
      expect(find.text('测试版'), findsOneWidget);
      expect(channelTile(tester, '更新渠道').onTap, isNotNull);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('failed save keeps stable and displays localized feedback', (
    tester,
  ) async {
    settings.failSave = true;
    await mount(tester, locale: const Locale('en'));
    await tester.pumpAndSettle();
    await revealChannel(tester, 'Update Channel');
    await tester.tap(find.text('Update Channel'));
    await tester.pumpAndSettle();
    expect(find.text('Receive stable releases only'), findsOneWidget);
    expect(find.text('Receive stable and preview releases'), findsOneWidget);
    await tester.tap(find.text('Preview'));
    await tester.pumpAndSettle();
    expect(
      find.text('Could not save the update channel. Please try again.'),
      findsOneWidget,
    );
    expect(find.text('Stable'), findsOneWidget);
    expect(await database.getSettings(), isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('channel is disabled until preferences finish loading', (
    tester,
  ) async {
    settings.loadGate = Completer<void>();
    await mount(tester);
    await revealChannel(tester, '更新渠道');
    expect(channelTile(tester, '更新渠道').onTap, isNull);
    settings.loadGate!.complete();
    await tester.pumpAndSettle();
    expect(channelTile(tester, '更新渠道').onTap, isNotNull);
  });

  for (final status in [
    UpdateStatus.downloading,
    UpdateStatus.installing,
    UpdateStatus.checking,
  ]) {
    testWidgets('channel interaction follows $status lifecycle', (
      tester,
    ) async {
      updates = _Updates(UpdateState(status: status));
      await mount(tester);
      await tester.pump(const Duration(milliseconds: 300));
      await revealChannel(tester, '更新渠道');
      expect(
        channelTile(tester, '更新渠道').onTap != null,
        status == UpdateStatus.checking,
      );
    });
  }

  testWidgets(
    'preview dialog shows long release tag, notes, error and cancel flow at 320px',
    (tester) async {
      const tag = 'pilot-0.4.0-alpha.20261019-1234567890';
      final release = AppRelease(
        version: '0.4.0',
        tagName: tag,
        notes: '测试版说明：这个版本用于验证渠道。\nPreview notes remain readable.',
        pageUrl: Uri.parse('https://example.invalid/release'),
        publishedAt: null,
        assets: const [],
        isPrerelease: true,
      );
      updates = _Updates(
        UpdateState(
          status: UpdateStatus.downloading,
          release: release,
          receivedBytes: 5,
          totalBytes: 10,
          progress: 0.5,
        ),
      );
      await mount(tester, home: const Scaffold(body: UpdateDialog()));
      await tester.pump();
      expect(find.text(tag), findsOneWidget);
      expect(find.text('测试版'), findsOneWidget);
      expect(find.text('取消下载'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('取消下载'));
      await tester.pump();
      expect(
        container.read(updateControllerProvider).status,
        UpdateStatus.available,
      );
      expect(find.text('取消下载'), findsNothing);
      updates.showState(
        UpdateState(
          status: UpdateStatus.error,
          release: release,
          errorMessage: 'Isolated download failed',
        ),
      );
      await tester.pump();
      expect(find.text('Isolated download failed'), findsOneWidget);
      expect(find.text('前往下载页'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
