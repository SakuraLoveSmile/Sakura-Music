import 'dart:convert';

import 'package:feedback_widget/feedback_widget.dart';
import 'package:flutter/foundation.dart' show kDebugMode, setEquals;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/settings_repository.dart';
import 'feedback_logs.dart' show collectFeedbackLogs;

/// Compile-time feedback wiring, injected with `--dart-define`.
///
/// * `FEEDBACK_ENABLED` — master gate. When it is unset the layer is enabled
///   for release/profile builds and disabled for debug builds and `flutter
///   test`, so day-to-day dev runs and the existing widget-test suite stay
///   unaffected unless feedback is explicitly requested.
/// * `FEEDBACK_API_BASE` — Feedback service base URL (defaults to production).
/// * `FEEDBACK_APP_ID` — the appId registered on the Feedback service for Music.
/// * `FEEDBACK_APP_NAME` — display name reported with submissions. The service
///   only adopts it while no admin-set name exists for the appId (Feedback
///   ≥0.4.0; ignored by older servers).
///
/// Only these three values are read here. The client never touches AI/Kaneo/
/// admin secrets: it knows the service base URL, the appId, and — after the
/// in-panel login — its own token (stored under a key derived from apiBase +
/// appId, fully isolated from Music's own credential keys).
class FeedbackBuildConfig {
  const FeedbackBuildConfig._();

  /// Production Feedback service address (punycode form of the IDN domain).
  static const String defaultApiBase = 'https://feedback.xn--fhqths51enha.cn';

  /// appId registered on the Feedback service for this app.
  static const String defaultAppId = 'sakuramusic';

  /// Display name reported alongside submissions (matches the app title).
  static const String defaultAppName = 'SakuraMusic';

  static const String _enabledRaw = String.fromEnvironment('FEEDBACK_ENABLED');
  static const String _apiBaseRaw = String.fromEnvironment('FEEDBACK_API_BASE');
  static const String _appIdRaw = String.fromEnvironment('FEEDBACK_APP_ID');
  static const String _appNameRaw =
      String.fromEnvironment('FEEDBACK_APP_NAME');

  /// Whether the feedback layer is mounted. Defaults to on for official builds.
  static bool get enabled =>
      _enabledRaw.isEmpty ? !kDebugMode : (_enabledRaw == 'true' || _enabledRaw == '1');

  static String get apiBase => _apiBaseRaw.isEmpty ? defaultApiBase : _apiBaseRaw;

  static String get appId => _appIdRaw.isEmpty ? defaultAppId : _appIdRaw;

  static String get appName =>
      _appNameRaw.isEmpty ? defaultAppName : _appNameRaw;
}

/// Runtime service identity handed to `FeedbackWidget`. `null` means the
/// feedback layer is off (do not mount it, do not show host entry points).
class FeedbackServiceConfig {
  const FeedbackServiceConfig({
    required this.apiBase,
    required this.appId,
    this.appName,
  });

  final String apiBase;
  final String appId;

  /// Optional display name reported with submissions (Feedback ≥0.4.0).
  final String? appName;
}

/// Resolves the service identity from the build config. Tests override this
/// provider to enable feedback against an isolated address, or to force it off.
final feedbackServiceConfigProvider = Provider<FeedbackServiceConfig?>((ref) {
  if (!FeedbackBuildConfig.enabled) return null;
  return FeedbackServiceConfig(
    apiBase: FeedbackBuildConfig.apiBase,
    appId: FeedbackBuildConfig.appId,
    appName: FeedbackBuildConfig.appName,
  );
});

/// The single, root-owned controller shared by the floating entry and any host
/// UI (e.g. Settings → 问题反馈) that opens the same capture flow. Disposed with
/// the root [ProviderContainer], never by a page.
final feedbackControllerProvider = Provider<FeedbackController>((ref) {
  final FeedbackController controller = FeedbackController();
  ref.onDispose(controller.dispose);
  return controller;
});

/// Page categories that may be reported as `pageLabel`. Anything outside this
/// allow-list collapses to `other`, so a route id, search term, server address
/// or query parameter can never leak into the feedback metadata.
const Set<String> _pageCategories = <String>{
  'home',
  'songs',
  'albums',
  'artists',
  'genres',
  'radios',
  'favorites',
  'downloads',
  'playlists',
  'search',
  'welcome',
  'membership',
  'settings',
  'debug',
  'add-server',
  'player',
};

/// Reduces a router location to a coarse, non-sensitive page category.
///
/// Only the first non-empty path segment is considered, and it must be a known
/// category: ids (`/albums/123`), sub-paths (`/add-server/config`) and query
/// parameters (`/search?q=...`) are all dropped.
String feedbackPageLabelFromUri(Uri uri) {
  for (final String segment in uri.pathSegments) {
    if (segment.isEmpty) continue;
    return _pageCategories.contains(segment) ? segment : 'other';
  }
  return 'home';
}

/// Builds the immutable `FeedbackConfig` for the current runtime state.
///
/// Fixed choices (see the integration plan): right-side floating orb, viewport
/// capture on invoke, dark theme (the app is dark-only), and an initial bottom
/// offset that clears the mini-player bar and the mobile bottom navigation.
///
/// [logProvider] defaults to [collectFeedbackLogs], which attaches the host's
/// own redacted diagnostics (playback ring buffer + crash-log tail) to a
/// submission. This is an explicit host decision — the component still never
/// grabs host info on its own — and callers/tests may override it or pass
/// `null` to attach nothing.
///
/// [showLauncher] stays `true` for this host: the floating entry is governed by
/// the host-owned idle style instead, which keeps a single source of truth with
/// the component's in-panel settings. Since feedback_widget 0.9.0 `hidden` only
/// hides the idle entry (enabled wake gestures can still wake the full orb), so
/// the panel stays reachable from Settings → 问题反馈 either way.
FeedbackConfig buildFeedbackConfig({
  required FeedbackServiceConfig service,
  required String pageLabel,
  String? appVersion,
  bool showLauncher = true,
  FeedbackLogProvider? logProvider = collectFeedbackLogs,
}) {
  return FeedbackConfig(
    service.apiBase,
    service.appId,
    appName: service.appName,
    appVersion: appVersion,
    pageLabel: pageLabel,
    side: FeedbackSide.right,
    theme: FeedbackThemeMode.dark,
    // Explicit: orb launcher + capture the current viewport on invoke. The
    // package defaults are `tab` / `off`, so these must be stated.
    launcherMode: FeedbackLauncherMode.orb,
    showLauncher: showLauncher,
    captureMode: FeedbackCaptureMode.viewport,
    // 30% up the right edge keeps the orb clear of the mini-player bar and the
    // mobile bottom NavigationBar; it remains draggable to anywhere else.
    launcherBottom: '30%',
    logProvider: logProvider,
  );
}

/// Persisted idle style of the right-edge floating orb (Settings → 关于).
///
/// `hidden` only hides the idle (collapsed) entry since feedback_widget 0.9.0:
/// the full orb is still shown after launch or waking, and enabled wake
/// gestures can wake it again. Settings → 问题反馈 still opens the panel through
/// the shared [feedbackControllerProvider]. The value is host-owned since
/// feedback_widget 0.8.4, so changes made inside the panel come back here.
FeedbackOrbIdleStyle decodeFeedbackOrbIdleStyle(String? raw) {
  for (final FeedbackOrbIdleStyle style in FeedbackOrbIdleStyle.values) {
    if (style.name == raw) {
      return style;
    }
  }
  return FeedbackOrbIdleStyle.handle;
}

/// Decodes the stored JSON array of wake-gesture ids.
Set<FeedbackWakeGesture> decodeFeedbackWakeGestures(String? raw) {
  if (raw == null || raw.isEmpty) {
    return <FeedbackWakeGesture>{};
  }
  try {
    final Object? decoded = jsonDecode(raw);
    if (decoded is! List) {
      return <FeedbackWakeGesture>{};
    }
    return <FeedbackWakeGesture>{
      for (final FeedbackWakeGesture gesture in FeedbackWakeGesture.values)
        if (decoded.contains(gesture.id)) gesture,
    };
  } on FormatException {
    return <FeedbackWakeGesture>{};
  }
}

/// Encodes wake gestures as a JSON array of the component's stable ids.
String encodeFeedbackWakeGestures(Set<FeedbackWakeGesture> gestures) {
  return jsonEncode(<String>[
    for (final FeedbackWakeGesture gesture in FeedbackWakeGesture.values)
      if (gestures.contains(gesture)) gesture.id,
  ]);
}

/// Host-owned idle style for the floating feedback orb (Settings → 关于).
class FeedbackOrbIdleStyleNotifier
    extends AsyncNotifier<FeedbackOrbIdleStyle> {
  @override
  Future<FeedbackOrbIdleStyle> build() async {
    final row = await ref.watch(settingsRepositoryProvider).read();
    return decodeFeedbackOrbIdleStyle(row?.feedbackOrbIdleStyle);
  }

  /// Applies the style immediately and persists it. A failed write rolls the
  /// state back so the UI never shows a value that would not survive a restart.
  Future<void> setStyle(FeedbackOrbIdleStyle style) async {
    final FeedbackOrbIdleStyle previous =
        state.value ?? FeedbackOrbIdleStyle.handle;
    if (previous == style) {
      return;
    }
    state = AsyncData(style);
    try {
      await ref
          .read(settingsRepositoryProvider)
          .updateFeedbackOrbIdleStyle(style: style.name);
    } catch (error, stackTrace) {
      state = AsyncData(previous);
      Error.throwWithStackTrace(error, stackTrace);
    }
  }
}

final feedbackOrbIdleStyleProvider =
    AsyncNotifierProvider<FeedbackOrbIdleStyleNotifier, FeedbackOrbIdleStyle>(
      FeedbackOrbIdleStyleNotifier.new,
    );

/// Host-owned wake gestures for the floating feedback orb (Settings → 关于).
class FeedbackWakeGesturesNotifier
    extends AsyncNotifier<Set<FeedbackWakeGesture>> {
  @override
  Future<Set<FeedbackWakeGesture>> build() async {
    final row = await ref.watch(settingsRepositoryProvider).read();
    return decodeFeedbackWakeGestures(row?.feedbackWakeGestures);
  }

  /// Applies the gesture set immediately and persists it; a failed write rolls
  /// the state back.
  Future<void> setGestures(Set<FeedbackWakeGesture> gestures) async {
    final Set<FeedbackWakeGesture> previous =
        state.value ?? const <FeedbackWakeGesture>{};
    final Set<FeedbackWakeGesture> next =
        Set<FeedbackWakeGesture>.of(gestures);
    if (setEquals(previous, next)) {
      return;
    }
    state = AsyncData(next);
    try {
      await ref
          .read(settingsRepositoryProvider)
          .updateFeedbackWakeGestures(
            gesturesJson: encodeFeedbackWakeGestures(next),
          );
    } catch (error, stackTrace) {
      state = AsyncData(previous);
      Error.throwWithStackTrace(error, stackTrace);
    }
  }
}

final feedbackWakeGesturesProvider = AsyncNotifierProvider<
    FeedbackWakeGesturesNotifier,
    Set<FeedbackWakeGesture>
>(FeedbackWakeGesturesNotifier.new);
