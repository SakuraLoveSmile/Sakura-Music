import 'dart:async';

import 'package:drift/native.dart';
import 'package:feedback_widget/feedback_widget.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramusic/core/feedback/feedback_config.dart';
import 'package:sakuramusic/data/db/app_database.dart';
import 'package:sakuramusic/data/server_repository.dart';
import 'package:sakuramusic/data/settings_repository.dart';

class _GatedSettingsRepository extends SettingsRepository {
  _GatedSettingsRepository(super.database);

  Completer<void>? saveGate;
  bool failSave = false;

  Future<void> _guard() async {
    await saveGate?.future;
    if (failSave) throw StateError('isolated write failure');
  }

  @override
  Future<void> updateFeedbackOrbIdleStyle({required String style}) async {
    await _guard();
    await super.updateFeedbackOrbIdleStyle(style: style);
  }

  @override
  Future<void> updateFeedbackWakeGestures({
    required String gesturesJson,
  }) async {
    await _guard();
    await super.updateFeedbackWakeGestures(gesturesJson: gesturesJson);
  }
}

void main() {
  late AppDatabase database;
  late _GatedSettingsRepository repository;
  late ProviderContainer container;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    repository = _GatedSettingsRepository(database);
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(database),
        settingsRepositoryProvider.overrideWithValue(repository),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await database.close();
  });

  test('codecs are strict and stable', () {
    expect(decodeFeedbackOrbIdleStyle(null), FeedbackOrbIdleStyle.handle);
    expect(decodeFeedbackOrbIdleStyle('bogus'), FeedbackOrbIdleStyle.handle);
    expect(
      decodeFeedbackOrbIdleStyle('hidden'),
      FeedbackOrbIdleStyle.hidden,
    );
    expect(decodeFeedbackWakeGestures(null), isEmpty);
    expect(decodeFeedbackWakeGestures(''), isEmpty);
    expect(decodeFeedbackWakeGestures('not json'), isEmpty);
    expect(decodeFeedbackWakeGestures('{}'), isEmpty);
    final Set<FeedbackWakeGesture> gestures = <FeedbackWakeGesture>{
      FeedbackWakeGesture.twoFingerDoubleTap,
      FeedbackWakeGesture.twoFingerHold,
    };
    expect(
      encodeFeedbackWakeGestures(gestures),
      '["two-finger-hold","two-finger-double-tap"]',
    );
    expect(decodeFeedbackWakeGestures(encodeFeedbackWakeGestures(gestures)),
        gestures);
    expect(decodeFeedbackWakeGestures('["unknown"]'), isEmpty);
  });

  test('new users start with handle and every gesture off', () async {
    expect(
      await container.read(feedbackOrbIdleStyleProvider.future),
      FeedbackOrbIdleStyle.handle,
    );
    expect(await container.read(feedbackWakeGesturesProvider.future), isEmpty);
  });

  test('style and gestures persist across provider recreation', () async {
    await container.read(feedbackOrbIdleStyleProvider.future);
    await container.read(feedbackWakeGesturesProvider.future);

    await container
        .read(feedbackOrbIdleStyleProvider.notifier)
        .setStyle(FeedbackOrbIdleStyle.hidden);
    await container
        .read(feedbackWakeGesturesProvider.notifier)
        .setGestures(<FeedbackWakeGesture>{FeedbackWakeGesture.twoFingerHold});

    final Setting? row = await database.getSettings();
    expect(row!.feedbackOrbIdleStyle, 'hidden');
    expect(row.feedbackWakeGestures, '["two-finger-hold"]');

    container.invalidate(feedbackOrbIdleStyleProvider);
    container.invalidate(feedbackWakeGesturesProvider);
    expect(
      await container.read(feedbackOrbIdleStyleProvider.future),
      FeedbackOrbIdleStyle.hidden,
    );
    expect(
      await container.read(feedbackWakeGesturesProvider.future),
      <FeedbackWakeGesture>{FeedbackWakeGesture.twoFingerHold},
    );

    await container
        .read(feedbackWakeGesturesProvider.notifier)
        .setGestures(<FeedbackWakeGesture>{});
    expect((await database.getSettings())!.feedbackWakeGestures, '[]');
  });

  test('a failed write keeps the previous style and gestures', () async {
    await container.read(feedbackOrbIdleStyleProvider.future);
    await container.read(feedbackWakeGesturesProvider.future);

    repository
      ..failSave = true
      ..saveGate = Completer<void>();
    final Future<void> styleSave = container
        .read(feedbackOrbIdleStyleProvider.notifier)
        .setStyle(FeedbackOrbIdleStyle.edge);
    final Future<void> gestureSave = container
        .read(feedbackWakeGesturesProvider.notifier)
        .setGestures(<FeedbackWakeGesture>{FeedbackWakeGesture.twoFingerHold});
    await Future<void>.delayed(Duration.zero);
    repository.saveGate!.complete();
    await expectLater(styleSave, throwsStateError);
    await expectLater(gestureSave, throwsStateError);

    expect(
      container.read(feedbackOrbIdleStyleProvider).value,
      FeedbackOrbIdleStyle.handle,
      reason: 'the UI must not show a value that would not survive a restart',
    );
    expect(container.read(feedbackWakeGesturesProvider).value, isEmpty);
    final Setting? row = await database.getSettings();
    expect(row?.feedbackOrbIdleStyle ?? 'handle', 'handle');
    expect(row?.feedbackWakeGestures ?? '[]', '[]');
  });
}
