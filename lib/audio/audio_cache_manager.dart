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

  static Future<void> trim(Directory directory) async {
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
      final length = await file.length();
      await file.delete();
      total -= length;
    }
  }
}
