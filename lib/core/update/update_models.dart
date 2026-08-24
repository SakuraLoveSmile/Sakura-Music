import 'dart:math' as math;

/// A release asset exposed by the GitHub Releases API.
class ReleaseAsset {
  const ReleaseAsset({
    required this.name,
    required this.downloadUrl,
    required this.sizeBytes,
    this.sha256,
  });

  final String name;
  final Uri downloadUrl;
  final int sizeBytes;
  final String? sha256;

  factory ReleaseAsset.fromJson(Map<String, dynamic> json) {
    final name = json['name'] as String?;
    final downloadUrl = json['browser_download_url'] as String?;
    if (name == null || downloadUrl == null) {
      throw const FormatException(
        'GitHub release asset is missing its name or URL',
      );
    }

    final digest = json['digest'] as String?;
    return ReleaseAsset(
      name: name,
      downloadUrl: Uri.parse(downloadUrl),
      sizeBytes: (json['size'] as num?)?.toInt() ?? 0,
      sha256: _parseSha256(digest),
    );
  }

  static String? _parseSha256(String? digest) {
    if (digest == null) {
      return null;
    }
    final value = digest.startsWith('sha256:')
        ? digest.substring('sha256:'.length)
        : digest;
    return RegExp(r'^[a-fA-F0-9]{64}$').hasMatch(value)
        ? value.toLowerCase()
        : null;
  }
}

class AppRelease {
  const AppRelease({
    required this.version,
    required this.tagName,
    required this.notes,
    required this.pageUrl,
    required this.publishedAt,
    required this.assets,
  });

  final String version;
  final String tagName;
  final String notes;
  final Uri pageUrl;
  final DateTime? publishedAt;
  final List<ReleaseAsset> assets;

  factory AppRelease.fromJson(Map<String, dynamic> json) {
    final tagName = json['tag_name'] as String?;
    final pageUrl = json['html_url'] as String?;
    if (tagName == null || pageUrl == null) {
      throw const FormatException(
        'GitHub release is missing its tag or page URL',
      );
    }

    final rawAssets = json['assets'];
    final assets = rawAssets is List
        ? rawAssets
              .whereType<Map>()
              .map(
                (asset) => ReleaseAsset.fromJson(
                  asset.map((key, value) => MapEntry(key.toString(), value)),
                ),
              )
              .toList(growable: false)
        : const <ReleaseAsset>[];

    return AppRelease(
      version: tagName,
      tagName: tagName,
      notes: json['body'] as String? ?? '',
      pageUrl: Uri.parse(pageUrl),
      publishedAt: DateTime.tryParse(json['published_at'] as String? ?? ''),
      assets: assets,
    );
  }
}

/// Compares two SemVer values after removing an optional `v` prefix.
///
/// Build metadata does not affect precedence. The return value is negative
/// when [left] is older than [right], zero when they have equal precedence,
/// and positive when [left] is newer.
int compareVersions(String left, String right) {
  final a = _SemVer.parse(left);
  final b = _SemVer.parse(right);
  return a.compareTo(b);
}

class _SemVer implements Comparable<_SemVer> {
  const _SemVer(this.major, this.minor, this.patch, this.prerelease);

  final int major;
  final int minor;
  final int patch;
  final List<String> prerelease;

  factory _SemVer.parse(String value) {
    var normalized = value.trim();
    if (normalized.startsWith('v') || normalized.startsWith('V')) {
      normalized = normalized.substring(1);
    }
    normalized = normalized.split('+').first;

    final match = RegExp(
      r'^(\d+)(?:\.(\d+))?(?:\.(\d+))?(?:-([0-9A-Za-z.-]+))?$',
    ).firstMatch(normalized);
    if (match == null) {
      return const _SemVer(0, 0, 0, <String>['invalid']);
    }

    return _SemVer(
      int.parse(match.group(1)!),
      int.parse(match.group(2) ?? '0'),
      int.parse(match.group(3) ?? '0'),
      match.group(4)?.split('.') ?? const <String>[],
    );
  }

  @override
  int compareTo(_SemVer other) {
    final core = _compareInts(major, other.major);
    if (core != 0) return core;
    final minorResult = _compareInts(minor, other.minor);
    if (minorResult != 0) return minorResult;
    final patchResult = _compareInts(patch, other.patch);
    if (patchResult != 0) return patchResult;

    if (prerelease.isEmpty && other.prerelease.isEmpty) return 0;
    if (prerelease.isEmpty) return 1;
    if (other.prerelease.isEmpty) return -1;

    for (
      var i = 0;
      i < math.min(prerelease.length, other.prerelease.length);
      i++
    ) {
      final result = _compareIdentifiers(prerelease[i], other.prerelease[i]);
      if (result != 0) return result;
    }
    return _compareInts(prerelease.length, other.prerelease.length);
  }

  static int _compareInts(int left, int right) => left.compareTo(right);

  static int _compareIdentifiers(String left, String right) {
    final leftNumber = int.tryParse(left);
    final rightNumber = int.tryParse(right);
    if (leftNumber != null && rightNumber != null) {
      return leftNumber.compareTo(rightNumber);
    }
    if (leftNumber != null) return -1;
    if (rightNumber != null) return 1;
    return left.compareTo(right);
  }
}

ReleaseAsset? pickAsset(
  List<ReleaseAsset> assets, {
  required String platform,
  String? androidAbi,
}) {
  final normalizedPlatform = platform.toLowerCase();
  final names = <String>[];
  switch (normalizedPlatform) {
    case 'android':
      {
        if (androidAbi != null && androidAbi.isNotEmpty) {
          names.add('SakuraMusic-android-$androidAbi.apk');
        }
        names.addAll(<String>[
          'SakuraMusic-android-universal.apk',
          'SakuraMusic-android.apk',
        ]);
        break;
      }
    case 'windows':
      {
        names.add('SakuraMusic-windows-x64.zip');
        break;
      }
    case 'macos':
    case 'macosx':
      {
        names.add('SakuraMusic-macos.zip');
        break;
      }
    default:
      return null;
  }

  for (final name in names) {
    for (final asset in assets) {
      if (asset.name == name) return asset;
    }
  }
  return null;
}
