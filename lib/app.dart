import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme.dart';
import 'core/appearance.dart';
import 'router.dart';
import 'audio/playback_coordinator.dart';
import 'audio/equalizer_service.dart';

class SakuraMusicApp extends ConsumerWidget {
  const SakuraMusicApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(playbackCoordinatorProvider);
    ref.watch(equalizerProvider);
    final appearance =
        ref.watch(appearanceProvider).value ?? const AppAppearance();
    final seedColor = Color(appearance.seedColorValue);
    return MaterialApp.router(
      title: 'SakuraMusic',
      theme: buildTheme(Brightness.light, seedColor: seedColor),
      darkTheme: buildTheme(Brightness.dark, seedColor: seedColor),
      themeMode: appearance.themeMode,
      routerConfig: ref.watch(appRouterProvider),
    );
  }
}
