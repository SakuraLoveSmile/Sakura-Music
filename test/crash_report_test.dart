import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:sakuramusic/core/crash_report.dart';

void main() {
  test('crash log directory targets the platform-specific location', () {
    final dir = getCrashLogDirectory().path;
    if (Platform.isWindows) {
      expect(dir, contains(r'SakuraMusic\logs'));
    } else if (Platform.isMacOS) {
      expect(dir, contains('Library/Logs/SakuraMusic'));
    } else {
      expect(dir, contains('SakuraMusic'));
    }
  });

  test('logCrash writes a timestamped record without throwing', () {
    expect(
      () => logCrash('boom', StackTrace.current, context: 'test'),
      returnsNormally,
    );
    expect(() => logCrash('no stack', null), returnsNormally);
  });
}
