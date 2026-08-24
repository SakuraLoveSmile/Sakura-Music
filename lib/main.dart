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
import 'data/db/app_database.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
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
      } catch (error) {
        debugPrint('Failed to read safeAudioMode setting: $error');
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
    runApp(
      ProviderScope(
        overrides: [audioPlayerProvider.overrideWithValue(audioHandler)],
        child: const SakuraMusicApp(),
      ),
    );
    return;
  } else if (Platform.isMacOS || Platform.isWindows) {
    MediaKit.ensureInitialized();
    if (Platform.isWindows) {
      await SMTCWindows.initialize();
    }
  }
  runApp(const ProviderScope(child: SakuraMusicApp()));
}
