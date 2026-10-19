import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart' as crypto;
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

import 'update_models.dart';

typedef PackageInfoLoader = Future<PackageInfo> Function();
typedef TemporaryDirectoryLoader = Future<Directory> Function();

class UpdateException implements Exception {
  const UpdateException(this.message);

  final String message;

  @override
  String toString() => message;
}

class UpdateService {
  UpdateService({
    Dio? dio,
    PackageInfoLoader? packageInfoLoader,
    TemporaryDirectoryLoader? temporaryDirectoryLoader,
    this.latestReleaseUrl = defaultLatestReleaseUrl,
    this.manifestMirrorUrls = defaultManifestMirrorUrls,
    this.previewReleaseUrl = defaultPreviewReleaseUrl,
    this.previewManifestMirrorUrls = defaultPreviewManifestMirrorUrls,
  }) : _dio =
           dio ??
           Dio(
             BaseOptions(
               connectTimeout: const Duration(seconds: 8),
               sendTimeout: const Duration(seconds: 8),
               receiveTimeout: const Duration(seconds: 15),
             ),
           ),
       _packageInfoLoader = packageInfoLoader ?? PackageInfo.fromPlatform,
       _temporaryDirectoryLoader =
           temporaryDirectoryLoader ?? getTemporaryDirectory;

  /// Same-repository manifests. Mirrors always retain the selected path.
  static const defaultLatestReleaseUrl =
      'https://raw.githubusercontent.com/SakuraLoveSmile/Sakura-Music/main/release/latest.json';
  static const defaultPreviewReleaseUrl =
      'https://raw.githubusercontent.com/SakuraLoveSmile/Sakura-Music/main/release/preview.json';
  static const defaultManifestMirrorUrls = <String>[
    'https://cdn.jsdelivr.net/gh/SakuraLoveSmile/Sakura-Music@main/release/latest.json',
    'https://fastly.jsdelivr.net/gh/SakuraLoveSmile/Sakura-Music@main/release/latest.json',
  ];
  static const defaultPreviewManifestMirrorUrls = <String>[
    'https://cdn.jsdelivr.net/gh/SakuraLoveSmile/Sakura-Music@main/release/preview.json',
    'https://fastly.jsdelivr.net/gh/SakuraLoveSmile/Sakura-Music@main/release/preview.json',
  ];

  /// The request client. Visible for tests so the default timeout
  /// configuration can be asserted (providers must not inject a bare Dio).
  @visibleForTesting
  Dio get dio => _dio;

  final Dio _dio;
  final PackageInfoLoader _packageInfoLoader;
  final TemporaryDirectoryLoader _temporaryDirectoryLoader;
  final String latestReleaseUrl;
  final List<String> manifestMirrorUrls;
  final String previewReleaseUrl;
  final List<String> previewManifestMirrorUrls;

  Future<AppRelease?> checkForUpdate({
    UpdateChannel channel = UpdateChannel.stable,
    String? platform,
    String? androidAbi,
  }) async {
    final packageInfo = await _packageInfoLoader();
    final headers = <String, String>{
      'Accept': 'application/json',
      'User-Agent': 'SakuraMusic/${packageInfo.version}',
    };

    Future<AppRelease> fetchManifest(
      String primary,
      List<String> mirrors, {
      required bool stable,
    }) async {
      Object lastError = const UpdateException('无法获取版本更新信息');
      for (final url in <String>[primary, ...mirrors]) {
        try {
          final response = await _dio.get<Object?>(
            url,
            options: Options(headers: headers),
          );
          final responseData = response.data;
          final data = responseData is String
              ? jsonDecode(responseData)
              : responseData;
          if (data is! Map) {
            throw const UpdateException('版本更新信息格式无效');
          }
          final release = AppRelease.fromJson(
            data.map((key, value) => MapEntry(key.toString(), value)),
          );
          if (stable && release.isPrerelease) {
            throw const UpdateException('正式版清单包含测试版本');
          }
          return release;
        } on FormatException {
          lastError = const UpdateException('版本更新信息格式无效');
        } on TypeError {
          lastError = const UpdateException('版本更新信息格式无效');
        } on Object catch (error) {
          lastError = error;
        }
      }
      throw lastError;
    }

    // Both manifests are needed for a trustworthy preview-channel result.
    // A failed preview request must never become a stable-only "up to date".
    final releases = await Future.wait(<Future<AppRelease>>[
      fetchManifest(latestReleaseUrl, manifestMirrorUrls, stable: true),
      if (channel == UpdateChannel.prerelease)
        fetchManifest(
          previewReleaseUrl,
          previewManifestMirrorUrls,
          stable: false,
        ),
    ]);
    final currentBuild = int.tryParse(packageInfo.buildNumber);
    final normalizedPlatform = platform?.toLowerCase();
    AppRelease? newest;
    int? newestBuild;
    for (final release in releases) {
      ReleaseAsset? asset;
      if (const <String>[
        'android',
        'windows',
        'macos',
        'macosx',
      ].contains(normalizedPlatform)) {
        asset = pickAsset(
          release.assets,
          platform: normalizedPlatform!,
          androidAbi: androidAbi,
        );
        if (asset == null || asset.sha256 == null) continue;
      }
      // PackageInfo reports the installed APK versionCode, including Flutter's
      // split-per-ABI offset. Never infer the installed package's base build.
      final candidateBuild =
          normalizedPlatform == 'android' &&
              release.buildNumber != null &&
              asset != null
          ? _androidVersionCode(release.buildNumber!, asset)
          : release.buildNumber;
      final versionOrder = compareVersions(
        release.version,
        packageInfo.version,
      );
      if (versionOrder < 0 ||
          (versionOrder == 0 &&
              (candidateBuild == null ||
                  currentBuild == null ||
                  candidateBuild <= currentBuild))) {
        continue;
      }
      if (normalizedPlatform == 'android' &&
          candidateBuild != null &&
          (currentBuild == null ||
              candidateBuild <= currentBuild ||
              candidateBuild > 2147483647)) {
        continue;
      }
      final newestVersionOrder = newest == null
          ? 1
          : compareVersions(release.version, newest.version);
      if (newestVersionOrder > 0 ||
          (newestVersionOrder == 0 &&
              (candidateBuild ?? 0) > (newestBuild ?? 0))) {
        newest = release;
        newestBuild = candidateBuild;
      }
    }
    return newest;
  }

  int _androidVersionCode(int build, ReleaseAsset asset) {
    final offset = switch (asset.name) {
      'SakuraMusic-android-armeabi-v7a.apk' => 1000,
      'SakuraMusic-android-arm64-v8a.apk' => 2000,
      'SakuraMusic-android-x86_64.apk' => 4000,
      _ => 0,
    };
    return build + offset;
  }

  Future<File> downloadUpdate(
    AppRelease release,
    ReleaseAsset asset, {
    ProgressCallback? onProgress,
    CancelToken? cancelToken,
  }) async {
    if (asset.sha256 == null) {
      throw const UpdateException('该安装包没有可用的 SHA-256 校验值');
    }

    final temporaryDirectory = await _temporaryDirectoryLoader();
    final updatesDirectory = Directory(
      '${temporaryDirectory.path}${Platform.pathSeparator}updates',
    );
    await updatesDirectory.create(recursive: true);

    final fileName = _safeFileName(asset.name);
    // A cancelled transfer may still be unwinding when the user retries.
    // Give each operation its own directory so its cleanup cannot touch a retry.
    final downloadDirectory = await updatesDirectory.createTemp('download-');
    final file = File(
      '${downloadDirectory.path}${Platform.pathSeparator}$fileName',
    );

    var completed = false;
    try {
      await _dio.download(
        asset.downloadUrl.toString(),
        file.path,
        onReceiveProgress: onProgress,
        cancelToken: cancelToken,
        deleteOnError: true,
        options: Options(
          headers: const <String, String>{'Accept': 'application/octet-stream'},
        ),
      );

      final digest = await crypto.sha256.bind(file.openRead()).first;
      // Dio has finished its transfer here; cancellation during the hash must
      // still reject the package and run this operation's cleanup.
      if (cancelToken?.isCancelled == true) throw cancelToken!.cancelError!;
      final actualSha256 = digest.toString().toLowerCase();
      if (actualSha256 != asset.sha256!.toLowerCase()) {
        throw const UpdateException('安装包完整性校验失败，文件已删除');
      }
      completed = true;
      return file;
    } finally {
      if (!completed && await downloadDirectory.exists()) {
        await downloadDirectory.delete(recursive: true);
      }
    }
  }

  String _safeFileName(String value) {
    if (value.isEmpty ||
        value == '.' ||
        value == '..' ||
        value.contains('/') ||
        value.contains('\\') ||
        value.contains('..')) {
      throw const UpdateException('安装包文件名无效');
    }
    return value;
  }
}
