import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'audio/playback_coordinator.dart';
import 'audio/equalizer_service.dart';
import 'core/appearance.dart';
import 'core/locale.dart';
import 'core/theme.dart';
import 'core/update/update_providers.dart';
import 'features/lyrics_overlay/lyrics_overlay_controller.dart';
import 'features/settings/widgets/update_dialog.dart';
import 'l10n/app_localizations.dart';
import 'router.dart';

class SakuraMusicApp extends ConsumerStatefulWidget {
  const SakuraMusicApp({super.key});

  @override
  ConsumerState<SakuraMusicApp> createState() => _SakuraMusicAppState();
}

class _SakuraMusicAppState extends ConsumerState<SakuraMusicApp> {
  bool _updateDialogOpen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(updateControllerProvider.notifier).check(silent: true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<UpdateState>(updateControllerProvider, (_, next) {
      if (next.status != UpdateStatus.available ||
          next.release == null ||
          _updateDialogOpen) {
        return;
      }
      _updateDialogOpen = true;
      final navigatorContext = rootNavigatorKey.currentContext;
      if (navigatorContext == null) {
        _updateDialogOpen = false;
        return;
      }
      showUpdateDialog(navigatorContext).whenComplete(() {
        _updateDialogOpen = false;
      });
    });
    ref.watch(playbackCoordinatorProvider);
    ref.watch(equalizerProvider);
    // Keeps the lyrics-overlay controller alive so it survives navigation.
    ref.watch(lyricsOverlayControllerProvider);
    final appearance =
        ref.watch(appearanceProvider).value ?? const AppAppearance();
    final seedColor = Color(appearance.seedColorValue);
    final localeCode = ref.watch(localeCodeProvider);
    return MaterialApp.router(
      title: 'SakuraMusic',
      // The app is dark-only by design; no light theme is provided.
      darkTheme: buildTheme(Brightness.dark, seedColor: seedColor),
      themeMode: ThemeMode.dark,
      locale: localeCode == 'system' ? null : Locale(localeCode),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const <LocalizationsDelegate<Object>>[
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: ref.watch(appRouterProvider),
    );
  }
}
