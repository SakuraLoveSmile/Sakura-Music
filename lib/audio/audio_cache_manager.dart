import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';

class AudioCacheManager {
  static const maxBytes = 512 * 1024 * 1024;

  static Future<Directory> directory() async {
    final temporary = await getTemporaryDirectory();
    final directory = Directory('${temporary.path}/sakuramusic_audio_cache');
    await directory.create(recursive: true);
    return directory;
  }

  static File fileFor(Directory directory, String key) {
    final filename = md5.convert(utf8.encode(key)).toString();
    return File('${directory.path}/$filename.audio');
  }

  /// Deletes the oldest cached files until usage is below [maxBytes].
  ///
  /// [exclude] holds absolute cache-file paths that must not be deleted (for
  /// example the files backing the currently queued tracks), so a trim never
  /// removes audio mid-playback. Excluded files still count toward the total
  /// usage; the trim deletes older, unqueued files instead.
  static Future<void> trim(Directory directory, {Set<String>? exclude}) async {
    final excludeSet = exclude ?? const <String>{};
    final files = await directory
        .list()
        .where((entity) => entity is File)
        .cast<File>()
        .toList();
    files.sort(
      (a, b) => b.statSync().modified.compareTo(a.statSync().modified),
    );
    var total = 0;
    for (final file in files) {
      total += await file.length();
    }
    for (final file in files.reversed) {
      if (total <= maxBytes) {
        break;
      }
      if (excludeSet.contains(file.path)) {
        continue;
      }
      final length = await file.length();
      await file.delete();
      total -= length;
    }
  }
}
