import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:sakuramusic/core/update/update_models.dart';
import 'package:sakuramusic/core/update/update_service.dart';

Map<String, dynamic> manifest(
  String version,
  int build, {
  bool preview = false,
  String asset = 'SakuraMusic-android-universal.apk',
  bool digest = true,
}) => <String, dynamic>{
  'tag_name': 'pilot-$build',
  'version': version,
  'build_number': build,
  'prerelease': preview,
  'draft': false,
  'html_url': 'https://example.com/pilot-$build',
  'assets': <Object>[
    <String, Object>{
      'name': asset,
      'size': 12,
      'browser_download_url': 'https://example.com/$asset',
      if (digest) 'digest': 'sha256:${'a' * 64}',
    },
  ],
};

Future<({UpdateService service, List<String> requests})> fixture(
  Map<String, Object> responses, {
  String currentVersion = '1.0.0',
  String currentBuild = '10',
  bool mirrors = false,
}) async {
  final requests = <String>[];
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  addTearDown(() => server.close(force: true));
  server.listen((request) {
    final path = request.uri.path;
    requests.add(path);
    final value = responses[path] ?? 404;
    request.response.headers.contentType = ContentType.json;
    if (value is int) {
      request.response.statusCode = value;
    } else {
      request.response.write(jsonEncode(value));
    }
    request.response.close();
  });
  final base = 'http://127.0.0.1:${server.port}';
  return (
    service: UpdateService(
      dio: Dio(),
      packageInfoLoader: () async => PackageInfo(
        appName: 'SakuraMusic',
        packageName: 'test.fixture',
        version: currentVersion,
        buildNumber: currentBuild,
      ),
      latestReleaseUrl: '$base/latest.json',
      previewReleaseUrl: '$base/preview.json',
      manifestMirrorUrls: mirrors ? ['$base/stable-mirror.json'] : [],
      previewManifestMirrorUrls: mirrors ? ['$base/preview-mirror.json'] : [],
    ),
    requests: requests,
  );
}

void main() {
  test('default sources are raw same-repository channel paths', () {
    expect(
      UpdateService.defaultLatestReleaseUrl,
      'https://raw.githubusercontent.com/SakuraLoveSmile/Sakura-Music/main/release/latest.json',
    );
    expect(
      UpdateService.defaultPreviewReleaseUrl,
      endsWith('/release/preview.json'),
    );
    expect(
      UpdateService.defaultPreviewManifestMirrorUrls,
      everyElement(endsWith('/release/preview.json')),
    );
  });

  test('accepts raw GitHub JSON served as text/plain', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    server.listen((request) {
      request.response
        ..headers.contentType = ContentType.text
        ..write(jsonEncode(manifest('2.0.0', 11)))
        ..close();
    });
    final service = UpdateService(
      dio: Dio(),
      packageInfoLoader: () async => PackageInfo(
        appName: 'fixture',
        packageName: 'fixture',
        version: '1.0.0',
        buildNumber: '10',
      ),
      latestReleaseUrl: 'http://127.0.0.1:${server.port}/latest.json',
      manifestMirrorUrls: const [],
    );
    expect((await service.checkForUpdate())?.buildNumber, 11);
  });

  test('new identity keeps display tag and validates build metadata', () {
    final release = AppRelease.fromJson(manifest('1.0.0', 11, preview: true));
    expect(release.version, '1.0.0');
    expect(release.tagName, 'pilot-11');
    expect(release.buildNumber, 11);
    expect(release.isPrerelease, isTrue);
    for (final value in [0, -1, 2147483648, '11', 11.5]) {
      expect(
        () => AppRelease.fromJson({
          ...manifest('1.0.0', 11),
          'build_number': value,
        }),
        throwsFormatException,
      );
    }
    expect(
      () => AppRelease.fromJson({...manifest('1.0.0', 11), 'draft': true}),
      throwsFormatException,
    );
  });

  test('same numeric version upgrades by actual build only once', () async {
    final f = await fixture({'/latest.json': manifest('1.0.0', 11)});
    expect(
      (await f.service.checkForUpdate(platform: 'android'))?.buildNumber,
      11,
    );
    final equal = await fixture({'/latest.json': manifest('1.0.0', 10)});
    expect(await equal.service.checkForUpdate(platform: 'android'), isNull);
  });

  test('legacy stable manifests retain version-only comparison', () async {
    final json = manifest('2.0.0', 11)
      ..remove('version')
      ..remove('build_number')
      ..['tag_name'] = 'v2.0.0';
    final f = await fixture({'/latest.json': json});
    final release = await f.service.checkForUpdate(platform: 'android');
    expect(release?.version, 'v2.0.0');
    expect(release?.buildNumber, isNull);
  });

  test(
    'stable never reads preview and never offers a version downgrade',
    () async {
      final f = await fixture({
        '/latest.json': manifest('0.9.0', 99),
        '/preview.json': manifest('2.0.0', 12, preview: true),
      });
      expect(await f.service.checkForUpdate(), isNull);
      expect(f.requests, ['/latest.json']);
    },
  );

  test('preview includes newer stable and newer preview builds', () async {
    final f = await fixture({
      '/latest.json': manifest('2.0.0', 12),
      '/preview.json': manifest('1.1.0', 11, preview: true),
    });
    expect(
      (await f.service.checkForUpdate(
        channel: UpdateChannel.prerelease,
      ))?.buildNumber,
      12,
    );
    final next = await fixture({
      '/latest.json': manifest('1.0.0', 11),
      '/preview.json': manifest('1.0.0', 12, preview: true),
    });
    final release = await next.service.checkForUpdate(
      channel: UpdateChannel.prerelease,
    );
    expect(release?.buildNumber, 12);
    expect(release?.isPrerelease, isTrue);
  });

  test('Android rejects higher version with non-increasing build', () async {
    final f = await fixture({'/latest.json': manifest('2.0.0', 9)});
    expect(await f.service.checkForUpdate(platform: 'android'), isNull);
    expect(await f.service.checkForUpdate(platform: 'ios'), isNotNull);
  });

  test(
    'split APK uses actual code for continuous same-version builds',
    () async {
      final f = await fixture({
        '/latest.json': manifest(
          '1.0.0',
          27,
          asset: 'SakuraMusic-android-arm64-v8a.apk',
        ),
      }, currentBuild: '2026');
      expect(
        (await f.service.checkForUpdate(
          platform: 'android',
          androidAbi: 'arm64-v8a',
        ))?.buildNumber,
        27,
      );
      final equal = await fixture({
        '/latest.json': manifest(
          '1.0.0',
          26,
          asset: 'SakuraMusic-android-arm64-v8a.apk',
        ),
      }, currentBuild: '2026');
      expect(
        await equal.service.checkForUpdate(
          platform: 'android',
          androidAbi: 'arm64-v8a',
        ),
        isNull,
      );
    },
  );

  test(
    'universal candidate cannot downgrade installed split APK code',
    () async {
      final f = await fixture({
        '/latest.json': manifest('2.0.0', 27),
      }, currentBuild: '2026');
      expect(
        await f.service.checkForUpdate(
          platform: 'android',
          androidAbi: 'arm64-v8a',
        ),
        isNull,
      );
    },
  );

  test(
    'each split ABI offset follows selected package and checks overflow',
    () async {
      for (final entry in {
        'armeabi-v7a': 1000,
        'arm64-v8a': 2000,
        'x86_64': 4000,
      }.entries) {
        final f = await fixture({
          '/latest.json': manifest(
            '1.0.0',
            27,
            asset: 'SakuraMusic-android-${entry.key}.apk',
          ),
        }, currentBuild: '${entry.value + 26}');
        expect(
          await f.service.checkForUpdate(
            platform: 'android',
            androidAbi: entry.key,
          ),
          isNotNull,
        );
      }
      final overflow = await fixture({
        '/latest.json': manifest(
          '2.0.0',
          2147483647,
          asset: 'SakuraMusic-android-arm64-v8a.apk',
        ),
      });
      expect(
        await overflow.service.checkForUpdate(
          platform: 'android',
          androidAbi: 'arm64-v8a',
        ),
        isNull,
      );
    },
  );

  test(
    'chooses latest installable candidate rather than unusable preview',
    () async {
      for (final unusable in [
        manifest('3.0.0', 13, preview: true, asset: 'unsigned.ipa'),
        manifest('3.0.0', 13, preview: true, digest: false),
      ]) {
        final f = await fixture({
          '/latest.json': manifest('2.0.0', 12),
          '/preview.json': unusable,
        });
        expect(
          (await f.service.checkForUpdate(
            channel: UpdateChannel.prerelease,
            platform: 'android',
          ))?.buildNumber,
          12,
        );
      }
      final desktop = await fixture({'/latest.json': manifest('2.0.0', 12)});
      expect(await desktop.service.checkForUpdate(platform: 'windows'), isNull);
      expect(await desktop.service.checkForUpdate(platform: 'macos'), isNull);
      expect(await desktop.service.checkForUpdate(platform: 'ios'), isNotNull);
    },
  );

  test('preview source failures use preview mirror exclusively', () async {
    final f = await fixture({
      '/latest.json': manifest('1.0.0', 10),
      '/preview.json': 403,
      '/preview-mirror.json': manifest('1.0.0', 11, preview: true),
    }, mirrors: true);
    expect(
      (await f.service.checkForUpdate(
        channel: UpdateChannel.prerelease,
      ))?.buildNumber,
      11,
    );
    expect(f.requests, contains('/preview-mirror.json'));
    expect(f.requests, isNot(contains('/stable-mirror.json')));
  });

  test('partial preview outage is an error instead of up to date', () async {
    final f = await fixture({
      '/latest.json': manifest('1.0.0', 10),
      '/preview.json': 500,
    });
    await expectLater(
      f.service.checkForUpdate(channel: UpdateChannel.prerelease),
      throwsA(isA<DioException>()),
    );
  });

  test(
    'malformed primary falls back; malformed all sources fails clearly',
    () async {
      final f = await fixture({
        '/latest.json': {'tag_name': 'broken'},
        '/stable-mirror.json': manifest('2.0.0', 11),
      }, mirrors: true);
      expect(await f.service.checkForUpdate(), isNotNull);
      final damaged = await fixture({
        '/latest.json': {'tag_name': 'broken'},
      });
      await expectLater(
        damaged.service.checkForUpdate(),
        throwsA(isA<UpdateException>()),
      );
    },
  );
}
