import 'dart:async';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../audio/audio_player_provider.dart';
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
  return UpdateService(
    dio: Dio(),
    packageInfoLoader: () => ref.read(appVersionProvider.future),
  );
});

final updateInstallerProvider = Provider<UpdateInstaller>(
  (ref) => UpdateInstaller(),
);

class UpdateController extends Notifier<UpdateState> {
  CancelToken? _cancelToken;

  @override
  UpdateState build() {
    ref.onDispose(() => _cancelToken?.cancel());
    return const UpdateState();
  }

  Future<void> check({bool silent = false}) async {
    if (state.status == UpdateStatus.checking ||
        state.status == UpdateStatus.downloading ||
        state.status == UpdateStatus.installing) {
      return;
    }

    state = const UpdateState(status: UpdateStatus.checking);
    try {
      final release = await ref.read(updateServiceProvider).checkForUpdate();
      if (release == null) {
        state = const UpdateState();
        return;
      }
      final asset = await _assetFor(release);
      state = UpdateState(
        status: UpdateStatus.available,
        release: release,
        asset: asset,
      );
    } catch (error) {
      state = silent
          ? const UpdateState()
          : UpdateState(
              status: UpdateStatus.error,
              errorMessage: _errorMessage(error),
            );
    }
  }

  Future<void> startDownload() async {
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
              if (cancelToken.isCancelled) return;
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
      await ref
          .read(updateInstallerProvider)
          .installUpdate(current.file!, release);
      if (Platform.isAndroid) {
        state = const UpdateState();
      }
    } catch (error) {
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

  Future<ReleaseAsset?> _assetFor(AppRelease release) async {
    if (Platform.isAndroid) {
      final info = await DeviceInfoPlugin().androidInfo;
      final abi = info.supportedAbis.isEmpty ? null : info.supportedAbis.first;
      return pickAsset(release.assets, platform: 'android', androidAbi: abi);
    }
    if (Platform.isWindows) {
      return pickAsset(release.assets, platform: 'windows');
    }
    if (Platform.isMacOS) {
      return pickAsset(release.assets, platform: 'macos');
    }
    return null;
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
