import 'dart:async';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:smtc_windows/smtc_windows.dart';
import 'package:window_manager/window_manager.dart';

import 'app.dart';
import 'audio/audio_player_provider.dart';
import 'audio/audio_service_handler.dart';
import 'core/crash_report.dart';
import 'core/desktop_runtime_status.dart';
import 'data/db/app_database.dart';

Future<void> main() async {
  // Wrap the ENTIRE bootstrap (engine init, crash-handler install, and the
  // per-stage startup) so an unhandled async error before runApp never silently
  // blanks the already-created native window.
  runZonedGuarded(() async {
    // Initialise the engine first so the framework's error plumbing is wired
    // before we install our own handlers.
    WidgetsFlutterBinding.ensureInitialized();

    // Install crash visibility before any other work so a failure below is
    // always recorded (and, on Windows, surfaced via a native dialog).
    initCrashReporting();

    await _bootstrap();
  }, (error, stack) {
    reportFatalStartupError(error, stack);
  });
}

/// Per-stage desktop/mobile startup. Every external integration is isolated in
/// its own try/catch: a failure degrades a feature but the UI must still render.
Future<void> _bootstrap() async {
  // Replace the default blank/grey build-failure screen with a readable dark
  // panel so a late build error is never an invisible white screen.
  ErrorWidget.builder = _buildErrorWidget;

  if (Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
    try {
      await windowManager.ensureInitialized();
      const windowOptions = WindowOptions(
        size: Size(1280, 800),
        minimumSize: Size(960, 640),
        center: true,
        title: 'SakuraMusic',
      );
      windowManager.waitUntilReadyToShow(windowOptions, () async {
        await windowManager.show();
        await windowManager.focus();
      });
    } catch (error, stack) {
      // The native window exists even if the window_manager channel failed, so
      // we must still start the UI rather than leave a blank window.
      logCrash(error, stack, context: 'windowManager.ensureInitialized');
    }
  }

  if (Platform.isAndroid || Platform.isIOS) {
    if (Platform.isAndroid) {
      await Permission.notification.request();
    }
    // Read the diagnostic "safe audio mode" before the player is built so the
    // equalizer pipeline can be skipped from the very first launch. Changing
    // it later requires a restart because the player is created here.
    var safeAudioMode = true;
    try {
      final db = AppDatabase();
      final settings = await db.getSettings();
      safeAudioMode = settings?.safeAudioMode ?? true;
      await db.close();
    } catch (error, stack) {
      logCrash(error, stack, context: 'readSafeAudioMode');
    }
    final audioHandler = await AudioService.init<AudioServiceHandler>(
      builder: () => AudioServiceHandler(
        disableEqualizerPipeline: safeAudioMode,
      ),
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'com.sakuramusic.app.audio',
        androidNotificationChannelName: 'SakuraMusic 播放',
        androidStopForegroundOnPause: false,
      ),
    );
    _runApp(audioHandler: audioHandler);
    return;
  }

  // Desktop media backends. Each loads native libraries that can be missing
  // (e.g. libmpv / smtc DLLs, VC++ runtimes); a failure degrades playback but
  // must not prevent the UI from rendering.
  try {
    MediaKit.ensureInitialized();
    setMediaKitReady(true);
  } catch (error, stack) {
    logCrash(error, stack, context: 'MediaKit.ensureInitialized');
  }

  if (Platform.isWindows) {
    try {
      await SMTCWindows.initialize();
      setSmtcWindowsReady(true);
    } catch (error, stack) {
      logCrash(error, stack, context: 'SMTCWindows.initialize');
    }
  }

  _runApp();
}

void _runApp({AudioServiceHandler? audioHandler}) {
  runApp(
    ProviderScope(
      observers: const [CrashReportingObserver()],
      overrides: audioHandler != null
          ? [audioPlayerProvider.overrideWithValue(audioHandler)]
          : const <Override>[],
      child: const SakuraMusicApp(),
    ),
  );
}

/// Logs provider construction failures (e.g. the media player failing to load
/// native libraries) so they are not invisible in a release build.
class CrashReportingObserver extends ProviderObserver {
  const CrashReportingObserver();

  @override
  void providerDidFail(
    ProviderBase<Object?> provider,
    Object error,
    StackTrace stackTrace,
    ProviderContainer container,
  ) {
    logCrash(
      error,
      stackTrace,
      context: 'provider:${provider.name ?? provider.runtimeType}',
    );
  }
}

Widget _buildErrorWidget(FlutterErrorDetails details) {
  final message = details.exceptionAsString();
  return Directionality(
    textDirection: TextDirection.ltr,
    child: DefaultTextStyle(
      style: const TextStyle(color: Colors.white70, fontSize: 13),
      child: Container(
        color: const Color(0xFF121212),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const DefaultTextStyle(
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
              child: Text('界面渲染出错 / Render error'),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: SingleChildScrollView(
                child: Text(message),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
