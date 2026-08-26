import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/settings_repository.dart';

/// Supported UI locale codes. `system` follows the platform locale; anything
/// else falls back to simplified Chinese, the app default.
const supportedLocaleCodes = <String>['system', 'zh', 'en'];

class LocaleNotifier extends Notifier<String> {
  @override
  String build() {
    // Starts as the app default so the first frame renders immediately;
    // the stored choice (if any) is applied asynchronously right after.
    _hydrate();
    return 'zh';
  }

  Future<void> _hydrate() async {
    try {
      final row = await ref.read(settingsRepositoryProvider).read();
      final code = row?.localeCode;
      if (code != null &&
          code != state &&
          supportedLocaleCodes.contains(code)) {
        state = code;
      }
    } catch (_) {
      // Unreadable settings keep the default locale.
    }
  }

  Future<void> setLocale(String code) async {
    if (!supportedLocaleCodes.contains(code) || code == state) {
      return;
    }
    final previous = state;
    state = code;
    try {
      await ref.read(settingsRepositoryProvider).updateLocale(localeCode: code);
    } catch (error, stackTrace) {
      state = previous;
      Error.throwWithStackTrace(error, stackTrace);
    }
  }
}

final localeCodeProvider = NotifierProvider<LocaleNotifier, String>(
  LocaleNotifier.new,
);
