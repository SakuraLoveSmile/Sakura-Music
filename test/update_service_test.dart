import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramusic/core/update/update_models.dart';
import 'package:sakuramusic/core/update/update_service.dart';

void main() {
  group('compareVersions', () {
    test('orders stable and pre-release versions according to SemVer', () {
      expect(compareVersions('1.0.0-alpha', '1.0.0-beta'), lessThan(0));
      expect(compareVersions('1.0.0-beta', '1.0.0-rc.1'), lessThan(0));
      expect(compareVersions('1.0.0-rc.1', '1.0.0'), lessThan(0));
      expect(compareVersions('1.0.0', '1.0.0-alpha'), greaterThan(0));
    });

    test('does not treat a newer local pre-release as an update', () {
      expect(compareVersions('0.1.1-alpha', 'v0.1.0-alpha'), greaterThan(0));
    });

    test('ignores v prefix and build metadata', () {
      expect(compareVersions('v1.2.3+100', '1.2.3+101'), equals(0));
      expect(compareVersions('1.2.3-alpha.2', '1.2.3-alpha.10'), lessThan(0));
      expect(compareVersions('1.2.3-1', '1.2.3-alpha'), lessThan(0));
    });
  });

  group('pickAsset', () {
    final digest = 'a' * 64;
    final assets = <ReleaseAsset>[
      ReleaseAsset(
        name: 'SakuraMusic-android-arm64-v8a.apk',
        downloadUrl: Uri.parse('https://example.com/arm64.apk'),
        sizeBytes: 100,
        sha256: digest,
      ),
      ReleaseAsset(
        name: 'SakuraMusic-android-universal.apk',
        downloadUrl: Uri.parse('https://example.com/universal.apk'),
        sizeBytes: 200,
        sha256: digest,
      ),
      ReleaseAsset(
        name: 'SakuraMusic-windows-x64.zip',
        downloadUrl: Uri.parse('https://example.com/windows.zip'),
        sizeBytes: 300,
        sha256: digest,
      ),
      ReleaseAsset(
        name: 'SakuraMusic-macos.zip',
        downloadUrl: Uri.parse('https://example.com/macos.zip'),
        sizeBytes: 400,
        sha256: digest,
      ),
    ];

    test('selects the matching Android ABI', () {
      expect(
        pickAsset(assets, platform: 'android', androidAbi: 'arm64-v8a')?.name,
        equals('SakuraMusic-android-arm64-v8a.apk'),
      );
    });

    test('falls back to the universal Android package', () {
      expect(
        pickAsset(assets, platform: 'android', androidAbi: 'x86_64')?.name,
        equals('SakuraMusic-android-universal.apk'),
      );
    });

    test('selects desktop assets by platform', () {
      expect(
        pickAsset(assets, platform: 'windows')?.name,
        equals('SakuraMusic-windows-x64.zip'),
      );
      expect(
        pickAsset(assets, platform: 'macos')?.name,
        equals('SakuraMusic-macos.zip'),
      );
    });
  });

  test('parses a GitHub release response and its SHA-256 digest', () {
    final release = AppRelease.fromJson(<String, dynamic>{
      'tag_name': 'v0.2.0-alpha',
      'html_url':
          'https://github.com/SakuraLoveSmile/Sakura-Music/releases/tag/v0.2.0-alpha',
      'body': '修复播放列表同步问题',
      'published_at': '2026-08-23T01:02:03Z',
      'assets': <Map<String, dynamic>>[
        <String, dynamic>{
          'name': 'SakuraMusic-macos.zip',
          'browser_download_url': 'https://example.com/SakuraMusic-macos.zip',
          'size': 123456,
          'digest': 'sha256:${'b' * 64}',
        },
      ],
    });

    expect(release.version, equals('v0.2.0-alpha'));
    expect(release.tagName, equals('v0.2.0-alpha'));
    expect(release.notes, equals('修复播放列表同步问题'));
    expect(release.publishedAt, isNotNull);
    expect(release.assets.single.sizeBytes, equals(123456));
    expect(release.assets.single.sha256, equals('b' * 64));
  });

  test('downloads an asset and verifies its SHA-256 digest', () async {
    final bytes = utf8.encode('sakuramusic update fixture');
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final temporaryDirectory = await Directory.systemTemp.createTemp(
      'sakuramusic-update-test-',
    );
    addTearDown(() async {
      await server.close(force: true);
      await temporaryDirectory.delete(recursive: true);
    });
    server.listen((request) {
      request.response
        ..statusCode = HttpStatus.ok
        ..add(bytes);
      request.response.close();
    });

    final service = UpdateService(
      dio: Dio(),
      temporaryDirectoryLoader: () async => temporaryDirectory,
    );
    final asset = ReleaseAsset(
      name: 'SakuraMusic-macos.zip',
      downloadUrl: Uri.parse('http://127.0.0.1:${server.port}/update.zip'),
      sizeBytes: bytes.length,
      sha256: sha256.convert(bytes).toString(),
    );
    final release = AppRelease(
      version: 'v0.2.0',
      tagName: 'v0.2.0',
      notes: '',
      pageUrl: Uri.parse('https://example.com'),
      publishedAt: null,
      assets: <ReleaseAsset>[],
    );

    final downloaded = await service.downloadUpdate(release, asset);
    expect(await downloaded.readAsBytes(), equals(bytes));
  });

  test('deletes a download when its digest does not match', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final temporaryDirectory = await Directory.systemTemp.createTemp(
      'sakuramusic-update-test-',
    );
    addTearDown(() async {
      await server.close(force: true);
      await temporaryDirectory.delete(recursive: true);
    });
    server.listen((request) {
      request.response
        ..statusCode = HttpStatus.ok
        ..write('tampered');
      request.response.close();
    });

    final service = UpdateService(
      dio: Dio(),
      temporaryDirectoryLoader: () async => temporaryDirectory,
    );
    final asset = ReleaseAsset(
      name: 'SakuraMusic-macos.zip',
      downloadUrl: Uri(scheme: 'http', host: '127.0.0.1', port: 1),
      sizeBytes: 8,
      sha256: 'c' * 64,
    );
    final release = AppRelease(
      version: 'v0.2.0',
      tagName: 'v0.2.0',
      notes: '',
      pageUrl: Uri.parse('https://example.com'),
      publishedAt: null,
      assets: <ReleaseAsset>[],
    );

    final actualAsset = ReleaseAsset(
      name: asset.name,
      downloadUrl: Uri.parse('http://127.0.0.1:${server.port}/update.zip'),
      sizeBytes: asset.sizeBytes,
      sha256: asset.sha256,
    );
    await expectLater(
      service.downloadUpdate(release, actualAsset),
      throwsA(isA<UpdateException>()),
    );
    expect(
      await File(
        '${temporaryDirectory.path}${Platform.pathSeparator}updates'
        '${Platform.pathSeparator}${asset.name}',
      ).exists(),
      isFalse,
    );
  });
}
