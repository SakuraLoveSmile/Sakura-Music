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

  /// GitHub Releases API endpoint for the latest published release.
  static const defaultLatestReleaseUrl =
      'https://api.github.com/repos/SakuraLoveSmile/Sakura-Music/releases/latest';

  /// Mirror manifest URLs used as fallbacks when the GitHub API is rate
  /// limited (HTTP 403/429) or unreachable. Each URL must serve a
  /// `release/latest.json` manifest whose JSON shape matches the GitHub
  /// Releases API (see [AppRelease.fromJson]). jsDelivr caches `@main`
  /// references for up to ~12h, so these mirror the latest *published* release
  /// with a bounded lag and are only consulted after the primary source fails.
  static const defaultManifestMirrorUrls = <String>[
    'https://cdn.jsdelivr.net/gh/SakuraLoveSmile/Sakura-Music@main/release/latest.json',
    'https://fastly.jsdelivr.net/gh/SakuraLoveSmile/Sakura-Music@main/release/latest.json',
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

  Future<AppRelease?> checkForUpdate() async {
    final packageInfo = await _packageInfoLoader();
    final userAgent = 'SakuraMusic/${packageInfo.version}';

    AppRelease? parseRelease(Response<Object?> response) {
      final data = response.data;
      if (data is! Map) {
        throw const UpdateException('GitHub 返回的版本信息格式无效');
      }
      final release = AppRelease.fromJson(
        data.map((key, value) => MapEntry(key.toString(), value)),
      );
      return compareVersions(packageInfo.version, release.version) < 0
          ? release
          : null;
    }

    Future<Response<Object?>> fetch(String url, Map<String, String> headers) =>
        _dio.get<Object?>(url, options: Options(headers: headers));

    const primaryHeaders = <String, String>{
      'Accept': 'application/vnd.github+json',
      'X-GitHub-Api-Version': '2022-11-28',
    };

    // 1. Primary: GitHub API. A missing User-Agent triggers GitHub's
    //    60 req/h/IP anonymous limit, which returns HTTP 403 on shared/NAT
    //    egress IPs, so we always send one.
    try {
      return parseRelease(
        await fetch(latestReleaseUrl, <String, String>{
          ...primaryHeaders,
          'User-Agent': userAgent,
        }),
      );
    } on DioException {
      // Fall through to the mirror manifests.
    }

    // 2. Mirrors: take the first successful manifest response.
    Object? lastError = const UpdateException('无法获取版本更新信息');
    for (final url in manifestMirrorUrls) {
      try {
        final response = await fetch(url, <String, String>{
          'User-Agent': userAgent,
        });
        return parseRelease(response);
      } on Object catch (error) {
        lastError = error;
      }
    }
    throw lastError!;
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
    final file = File(
      '${updatesDirectory.path}${Platform.pathSeparator}$fileName',
    );
    if (await file.exists()) {
      await file.delete();
    }

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
      final actualSha256 = digest.toString().toLowerCase();
      if (actualSha256 != asset.sha256!.toLowerCase()) {
        throw const UpdateException('安装包完整性校验失败，文件已删除');
      }
      completed = true;
      return file;
    } finally {
      if (!completed && await file.exists()) {
        await file.delete();
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
