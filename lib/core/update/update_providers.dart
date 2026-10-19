import 'dart:async';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../audio/audio_player_provider.dart';
import 'update_channel.dart';
import 'update_installer.dart';
import 'update_models.dart';
import 'update_service.dart';

enum UpdateStatus {
  idle,
  checking,
  available,
  downloading,
  downloaded,
  installing,
  error,
}

class UpdateState {
  const UpdateState({
    this.status = UpdateStatus.idle,
    this.release,
    this.asset,
    this.file,
    this.progress = 0,
    this.receivedBytes = 0,
    this.totalBytes = 0,
    this.errorMessage,
  });

  final UpdateStatus status;
  final AppRelease? release;
  final ReleaseAsset? asset;
  final File? file;
  final double progress;
  final int receivedBytes;
  final int totalBytes;
  final String? errorMessage;
}

final appVersionProvider = FutureProvider<PackageInfo>(
  (ref) => PackageInfo.fromPlatform(),
);

final updateServiceProvider = Provider<UpdateService>((ref) {
  // No Dio override: UpdateService's own default client carries the request
  // timeouts. Injecting a bare Dio() silently removed them.
  return UpdateService(
    packageInfoLoader: () => ref.read(appVersionProvider.future),
  );
});

final updateInstallerProvider = Provider<UpdateInstaller>(
  (ref) => UpdateInstaller(),
);

class UpdateController extends Notifier<UpdateState> {
  CancelToken? _cancelToken;
  int _generation = 0;
  bool _savingChannel = false;

  @override
  UpdateState build() {
    ref.onDispose(() {
      _generation++;
      _cancelToken?.cancel();
    });
    return const UpdateState();
  }

  Future<void> setChannel(UpdateChannel channel) async {
    if (_savingChannel ||
        state.status == UpdateStatus.downloading ||
        state.status == UpdateStatus.installing) {
      throw const UpdateException('下载或安装期间无法切换更新渠道');
    }
    final previous = state;
    _savingChannel = true;
    final generation = ++_generation;
    try {
      await ref.read(updateChannelProvider.notifier).setChannel(channel);
    } catch (_) {
      if (_isCurrent(generation)) {
        state = previous.status == UpdateStatus.checking
            ? const UpdateState()
            : previous;
      }
      rethrow;
    } finally {
      _savingChannel = false;
    }
    if (!_isCurrent(generation)) return;
    state = const UpdateState();
    try {
      final file = previous.file;
      if (file != null && await file.exists()) await file.delete();
    } on FileSystemException catch (error) {
      if (_isCurrent(generation)) {
        state = UpdateState(
          status: UpdateStatus.error,
          errorMessage: _errorMessage(error),
        );
      }
      return;
    }
    if (!_isCurrent(generation)) return;
    await check();
  }

  Future<void> check({bool silent = false}) async {
    if (_savingChannel ||
        state.status == UpdateStatus.checking ||
        state.status == UpdateStatus.downloading ||
        state.status == UpdateStatus.installing) {
      return;
    }

    final generation = ++_generation;
    state = const UpdateState(status: UpdateStatus.checking);
    try {
      final channel = await ref.read(updateChannelProvider.future);
      if (!_isCurrent(generation)) return;
      final platform = Platform.operatingSystem;
      String? androidAbi;
      if (Platform.isAndroid) {
        final info = await DeviceInfoPlugin().androidInfo;
        if (!_isCurrent(generation)) return;
        androidAbi = info.supportedAbis.isEmpty
            ? null
            : info.supportedAbis.first;
      }
      final release = await ref
          .read(updateServiceProvider)
          .checkForUpdate(
            channel: channel,
            platform: platform,
            androidAbi: androidAbi,
          );
      if (!_isCurrent(generation)) return;
      if (release == null) {
        state = const UpdateState();
        return;
      }
      final asset = pickAsset(
        release.assets,
        platform: platform,
        androidAbi: androidAbi,
      );
      state = UpdateState(
        status: UpdateStatus.available,
        release: release,
        asset: asset,
      );
    } catch (error) {
      if (!_isCurrent(generation)) return;
      state = silent
          ? const UpdateState()
          : UpdateState(
              status: UpdateStatus.error,
              errorMessage: _errorMessage(error),
            );
    }
  }

  bool _isCurrent(int generation) => ref.mounted && generation == _generation;

  Future<void> startDownload() async {
    if (_savingChannel) return;
    final current = state;
    if (current.status != UpdateStatus.available ||
        current.release == null ||
        current.asset == null) {
      if (current.release != null && current.asset == null) {
        state = UpdateState(
          status: UpdateStatus.error,
          release: current.release,
          errorMessage: '当前平台没有匹配的安装包',
        );
      }
      return;
    }

    final generation = ++_generation;
    final release = current.release!;
    final asset = current.asset!;
    final cancelToken = CancelToken();
    _cancelToken = cancelToken;
    state = UpdateState(
      status: UpdateStatus.downloading,
      release: release,
      asset: asset,
      totalBytes: asset.sizeBytes,
    );

    try {
      final file = await ref
          .read(updateServiceProvider)
          .downloadUpdate(
            release,
            asset,
            cancelToken: cancelToken,
            onProgress: (received, total) {
              if (cancelToken.isCancelled || !_isCurrent(generation)) return;
              final effectiveTotal = total > 0 ? total : asset.sizeBytes;
              state = UpdateState(
                status: UpdateStatus.downloading,
                release: release,
                asset: asset,
                receivedBytes: received,
                totalBytes: effectiveTotal,
                progress: effectiveTotal > 0 ? received / effectiveTotal : 0,
              );
            },
          );
      if (!_isCurrent(generation)) {
        if (await file.exists()) await file.delete();
        return;
      }
      state = UpdateState(
        status: UpdateStatus.downloaded,
        release: release,
        asset: asset,
        file: file,
        progress: 1,
        receivedBytes: asset.sizeBytes,
        totalBytes: asset.sizeBytes,
      );
    } catch (error) {
      if (!_isCurrent(generation)) return;
      if (cancelToken.isCancelled) {
        state = UpdateState(
          status: UpdateStatus.available,
          release: release,
          asset: asset,
        );
      } else {
        state = UpdateState(
          status: UpdateStatus.error,
          release: release,
          asset: asset,
          errorMessage: _errorMessage(error),
        );
      }
    } finally {
      if (identical(_cancelToken, cancelToken)) {
        _cancelToken = null;
      }
    }
  }

  void cancelDownload() {
    if (state.status != UpdateStatus.downloading) return;
    _generation++;
    _cancelToken?.cancel('用户取消下载');
    state = UpdateState(
      status: UpdateStatus.available,
      release: state.release,
      asset: state.asset,
    );
  }

  Future<void> retryDownload() async {
    final current = state;
    if (current.status != UpdateStatus.error || current.release == null) {
      return;
    }
    state = UpdateState(
      status: UpdateStatus.available,
      release: current.release,
      asset: current.asset,
    );
    await startDownload();
  }

  Future<void> install() async {
    if (_savingChannel) return;
    final generation = ++_generation;
    final current = state;
    final release = current.release;
    if (release == null) return;

    if (current.file == null) {
      await openReleasePage();
      return;
    }

    state = UpdateState(
      status: UpdateStatus.installing,
      release: release,
      asset: current.asset,
      file: current.file,
    );
    try {
      await ref.read(audioPlayerProvider).pause();
      if (!_isCurrent(generation)) return;
      await ref
          .read(updateInstallerProvider)
          .installUpdate(current.file!, release);
      if (!_isCurrent(generation)) return;
      if (Platform.isAndroid) {
        state = const UpdateState();
      }
    } catch (error) {
      if (!_isCurrent(generation)) return;
      state = UpdateState(
        status: UpdateStatus.error,
        release: release,
        asset: current.asset,
        file: current.file,
        errorMessage: _errorMessage(error),
      );
    }
  }

  Future<void> openReleasePage() async {
    final release = state.release;
    if (release == null) return;
    await ref.read(updateInstallerProvider).openReleasePage(release);
  }

  void dismiss() {
    _generation++;
    _cancelToken?.cancel();
    final file = state.file;
    if (file != null) {
      unawaited(
        file.exists().then((exists) async {
          if (exists) await file.delete();
        }),
      );
    }
    state = const UpdateState();
  }

  String _errorMessage(Object error) {
    if (error is UpdateException) return error.message;
    if (error is DioException) {
      if (error.type == DioExceptionType.connectionError ||
          error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.receiveTimeout) {
        return '网络连接失败，请检查网络后重试';
      }
      final statusCode = error.response?.statusCode;
      if (statusCode == 403 || statusCode == 429) {
        return 'GitHub 请求过于频繁或访问受限，请稍后重试';
      }
      return 'GitHub 请求失败（HTTP ${statusCode ?? '未知'}）';
    }
    return '更新失败，请稍后重试';
  }
}

final updateControllerProvider =
    NotifierProvider<UpdateController, UpdateState>(UpdateController.new);
