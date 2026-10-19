import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramusic/core/update/update_channel.dart';
import 'package:sakuramusic/core/update/update_models.dart';
import 'package:sakuramusic/core/update/update_providers.dart';
import 'package:sakuramusic/core/update/update_service.dart';

class FakeChannel extends UpdateChannelController {
  FakeChannel(this.loaded);
  final Future<UpdateChannel> loaded;
  Completer<void>? saving;
  Object? saveError;
  final saved = <UpdateChannel>[];

  @override
  Future<UpdateChannel> build() => loaded;

  @override
  Future<void> setChannel(UpdateChannel channel) async {
    await future;
    saved.add(channel);
    if (saving != null) await saving!.future;
    if (saveError != null) throw saveError!;
    state = AsyncData(channel);
  }
}

class FakeService extends UpdateService {
  final calls =
      <({UpdateChannel channel, String? platform, String? androidAbi})>[];
  final pending = <Completer<AppRelease?>>[];
  final firstCall = Completer<void>();
  final download = Completer<File>();

  @override
  Future<AppRelease?> checkForUpdate({
    UpdateChannel channel = UpdateChannel.stable,
    String? platform,
    String? androidAbi,
  }) {
    calls.add((channel: channel, platform: platform, androidAbi: androidAbi));
    final result = Completer<AppRelease?>();
    pending.add(result);
    if (!firstCall.isCompleted) firstCall.complete();
    return result.future;
  }

  @override
  Future<File> downloadUpdate(
    AppRelease release,
    ReleaseAsset asset, {
    ProgressCallback? onProgress,
    CancelToken? cancelToken,
  }) => download.future;
}

class SeededController extends UpdateController {
  SeededController(this.initial);
  final UpdateState initial;
  @override
  UpdateState build() {
    super.build();
    return initial;
  }
}

AppRelease release(String tag) => AppRelease(
  version: '2.0.0',
  tagName: tag,
  notes: '',
  pageUrl: Uri.parse('https://example.com/release'),
  publishedAt: null,
  assets: [
    ReleaseAsset(
      name: 'SakuraMusic-macos.zip',
      sizeBytes: 12,
      sha256: 'a' * 64,
      downloadUrl: Uri.parse('https://example.com/asset'),
    ),
  ],
);

Future<void> flush() => Future<void>.delayed(Duration.zero);

void main() {
  ProviderContainer setup(
    FakeChannel channel,
    FakeService service, {
    UpdateState? initial,
  }) {
    final container = ProviderContainer(
      overrides: [
        updateChannelProvider.overrideWith(() => channel),
        updateServiceProvider.overrideWithValue(service),
        if (initial != null)
          updateControllerProvider.overrideWith(
            () => SeededController(initial),
          ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test(
    'normal checks await hydrated preference and pass actual platform',
    () async {
      final loaded = Completer<UpdateChannel>();
      final service = FakeService();
      final container = setup(FakeChannel(loaded.future), service);
      final check = container.read(updateControllerProvider.notifier).check();
      await flush();
      expect(service.calls, isEmpty);
      loaded.complete(UpdateChannel.prerelease);
      await flush();
      expect(service.calls.single.channel, UpdateChannel.prerelease);
      expect(service.calls.single.platform, Platform.operatingSystem);
      service.pending.single.complete(null);
      await check;
      expect(
        container.read(updateControllerProvider).status,
        UpdateStatus.idle,
      );
    },
  );

  test(
    'switch saves before refresh and stale old response cannot overwrite new',
    () async {
      final channel = FakeChannel(Future.value(UpdateChannel.stable));
      final service = FakeService();
      final container = setup(channel, service);
      final controller = container.read(updateControllerProvider.notifier);
      final old = controller.check();
      await flush();
      channel.saving = Completer<void>();
      final switched = controller.setChannel(UpdateChannel.prerelease);
      await flush();
      expect(service.calls.length, 1);
      channel.saving!.complete();
      await flush();
      expect(service.calls.last.channel, UpdateChannel.prerelease);
      service.pending.last.complete(release('new-preview'));
      await switched;
      service.pending.first.complete(release('old-stable'));
      await old;
      expect(
        container.read(updateControllerProvider).release?.tagName,
        'new-preview',
      );
      expect(channel.saved, [UpdateChannel.prerelease]);
    },
  );

  test('switch clears downloaded file and candidate before refresh', () async {
    final directory = await Directory.systemTemp.createTemp('update-switch-');
    addTearDown(() => directory.delete(recursive: true));
    final file = await File(
      '${directory.path}/old.zip',
    ).writeAsString('fixture');
    final channel = FakeChannel(Future.value(UpdateChannel.stable));
    final service = FakeService();
    final container = setup(
      channel,
      service,
      initial: UpdateState(
        status: UpdateStatus.downloaded,
        release: release('old'),
        file: file,
      ),
    );
    final switched = container
        .read(updateControllerProvider.notifier)
        .setChannel(UpdateChannel.prerelease);
    await service.firstCall.future;
    expect(container.read(updateControllerProvider).file, isNull);
    expect(await file.exists(), isFalse);
    service.pending.single.complete(null);
    await switched;
    expect(container.read(updateControllerProvider).release, isNull);
  });

  test('dismiss during save prevents a late automatic refresh', () async {
    final channel = FakeChannel(Future.value(UpdateChannel.stable))
      ..saving = Completer<void>();
    final service = FakeService();
    final container = setup(channel, service);
    final controller = container.read(updateControllerProvider.notifier);
    final switched = controller.setChannel(UpdateChannel.prerelease);
    await flush();
    controller.dismiss();
    channel.saving!.complete();
    await switched;
    expect(service.calls, isEmpty);
    expect(container.read(updateControllerProvider).status, UpdateStatus.idle);
  });

  test(
    'save failure preserves old candidate and propagates the save error',
    () async {
      final channel = FakeChannel(Future.value(UpdateChannel.stable))
        ..saveError = StateError('save failed');
      final service = FakeService();
      final oldRelease = release('stable');
      final container = setup(
        channel,
        service,
        initial: UpdateState(
          status: UpdateStatus.available,
          release: oldRelease,
        ),
      );
      await expectLater(
        container
            .read(updateControllerProvider.notifier)
            .setChannel(UpdateChannel.prerelease),
        throwsStateError,
      );
      expect(
        container.read(updateControllerProvider).release,
        same(oldRelease),
      );
      expect(service.calls, isEmpty);
    },
  );

  test(
    'refresh failure after successful save becomes visible error state',
    () async {
      final channel = FakeChannel(Future.value(UpdateChannel.stable));
      final service = FakeService();
      final container = setup(channel, service);
      final switched = container
          .read(updateControllerProvider.notifier)
          .setChannel(UpdateChannel.prerelease);
      await flush();
      service.pending.single.completeError(
        const UpdateException('preview unavailable'),
      );
      await switched;
      expect(
        container.read(updateChannelProvider).requireValue,
        UpdateChannel.prerelease,
      );
      expect(
        container.read(updateControllerProvider).status,
        UpdateStatus.error,
      );
      expect(
        container.read(updateControllerProvider).errorMessage,
        'preview unavailable',
      );
    },
  );

  for (final status in [UpdateStatus.downloading, UpdateStatus.installing]) {
    test('cannot switch channel during $status', () async {
      final channel = FakeChannel(Future.value(UpdateChannel.stable));
      final service = FakeService();
      final container = setup(
        channel,
        service,
        initial: UpdateState(status: status),
      );
      await expectLater(
        container
            .read(updateControllerProvider.notifier)
            .setChannel(UpdateChannel.prerelease),
        throwsA(isA<UpdateException>()),
      );
      expect(channel.saved, isEmpty);
      expect(service.calls, isEmpty);
      expect(container.read(updateControllerProvider).status, status);
    });
  }

  test(
    'cancelled download cannot restore old candidate after channel switch',
    () async {
      final channel = FakeChannel(Future.value(UpdateChannel.stable));
      final service = FakeService();
      final oldRelease = release('old');
      final container = setup(
        channel,
        service,
        initial: UpdateState(
          status: UpdateStatus.available,
          release: oldRelease,
          asset: oldRelease.assets.single,
        ),
      );
      final controller = container.read(updateControllerProvider.notifier);
      final download = controller.startDownload();
      controller.cancelDownload();
      final switched = controller.setChannel(UpdateChannel.prerelease);
      await flush();
      service.pending.single.complete(release('preview'));
      await switched;
      service.download.completeError(const UpdateException('cancelled'));
      await download;
      expect(
        container.read(updateControllerProvider).release?.tagName,
        'preview',
      );
    },
  );

  for (final dispose in [false, true]) {
    test(
      'stale successful download cleans its own file (dispose=$dispose)',
      () async {
        final directory = await Directory.systemTemp.createTemp(
          'update-stale-',
        );
        addTearDown(() => directory.delete(recursive: true));
        final file = await File(
          '${directory.path}/orphan.zip',
        ).writeAsString('fixture');
        final channel = FakeChannel(Future.value(UpdateChannel.stable));
        final service = FakeService();
        final oldRelease = release('old');
        final container = setup(
          channel,
          service,
          initial: UpdateState(
            status: UpdateStatus.available,
            release: oldRelease,
            asset: oldRelease.assets.single,
          ),
        );
        final controller = container.read(updateControllerProvider.notifier);
        final download = controller.startDownload();
        if (dispose) {
          container.invalidate(updateControllerProvider);
        } else {
          controller.cancelDownload();
        }
        service.download.complete(file);
        await download;
        expect(await file.exists(), isFalse);
        expect(
          container.read(updateControllerProvider).status,
          UpdateStatus.available,
        );
      },
    );
  }

  test('dismiss and disposal invalidate pending checks', () async {
    final service = FakeService();
    final container = setup(
      FakeChannel(Future.value(UpdateChannel.stable)),
      service,
    );
    final controller = container.read(updateControllerProvider.notifier);
    final check = controller.check();
    await flush();
    controller.dismiss();
    service.pending.first.complete(release('stale'));
    await check;
    expect(container.read(updateControllerProvider).status, UpdateStatus.idle);
    final next = controller.check();
    await flush();
    container.invalidate(updateControllerProvider);
    service.pending.last.completeError(const UpdateException('disposed'));
    await next;
    expect(container.read(updateControllerProvider).status, UpdateStatus.idle);
  });
}
