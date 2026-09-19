import 'package:feedback_widget/feedback_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'audio/playback_coordinator.dart';
import 'audio/equalizer_service.dart';
import 'core/appearance.dart';
import 'core/feedback/feedback_config.dart';
import 'core/feedback/feedback_layer.dart';
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

class _SakuraMusicAppState extends ConsumerState<SakuraMusicApp>
    with WidgetsBindingObserver {
  bool _updateDialogOpen = false;

  // Root-owned feedback wiring. The controller and the outer navigator key are
  // created once and never rebuilt on page/theme/locale changes, so the
  // feedback session (draft + login token) survives navigation.
  final GlobalKey<NavigatorState> _feedbackNavigatorKey =
      GlobalKey<NavigatorState>();
  final ValueNotifier<String> _feedbackPageLabel = ValueNotifier<String>('home');
  late final FeedbackController _feedbackController;
  GoRouter? _router;

  @override
  void initState() {
    super.initState();
    // Register BEFORE the router exists so this observer is consulted first:
    // Android back must close the feedback preview/panel ahead of GoRouter
    // popping a route (or the shell's exit-confirm dialog firing).
    WidgetsBinding.instance.addObserver(this);
    _feedbackController = ref.read(feedbackControllerProvider);
    _router = ref.read(appRouterProvider);
    _router!.routerDelegate.addListener(_onRouteChanged);
    _syncFeedbackPageLabel();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(updateControllerProvider.notifier).check(silent: true);
      }
    });
  }

  @override
  void dispose() {
    _router?.routerDelegate.removeListener(_onRouteChanged);
    WidgetsBinding.instance.removeObserver(this);
    _feedbackPageLabel.dispose();
    super.dispose();
  }

  /// Android back / system pop: close a feedback screenshot-preview dialog,
  /// then the feedback panel, before letting normal navigation handle it.
  @override
  Future<bool> didPopRoute() async => handleFeedbackBackPop(
    navigatorKey: _feedbackNavigatorKey,
    controller: _feedbackController,
  );

  void _onRouteChanged() {
    // The delegate notifies during the router's build/notify phase; defer the
    // ValueNotifier write so it never triggers a rebuild-during-build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _syncFeedbackPageLabel();
    });
  }

  void _syncFeedbackPageLabel() {
    final GoRouter? router = _router;
    if (router == null) return;
    _feedbackPageLabel.value = feedbackPageLabelFromUri(
      router.routerDelegate.currentConfiguration.uri,
    );
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
    final FeedbackServiceConfig? feedbackService =
        ref.watch(feedbackServiceConfigProvider);
    final packageInfo = ref.watch(appVersionProvider).value;
    final String? feedbackAppVersion = packageInfo == null
        ? null
        : '${packageInfo.version}+${packageInfo.buildNumber}';
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
      // Mount the long-lived feedback layer above the whole router subtree so
      // the orb is present on every page and the draft survives navigation.
      builder: (BuildContext context, Widget? child) {
        final Widget routerChild = child ?? const SizedBox.shrink();
        if (feedbackService == null) return routerChild; // feedback disabled
        return ValueListenableBuilder<String>(
          valueListenable: _feedbackPageLabel,
          builder: (BuildContext context, String pageLabel, Widget? _) {
            return FeedbackOverlay(
              controller: _feedbackController,
              navigatorKey: _feedbackNavigatorKey,
              config: buildFeedbackConfig(
                service: feedbackService,
                pageLabel: pageLabel,
                appVersion: feedbackAppVersion,
              ),
              child: routerChild,
            );
          },
        );
      },
    );
  }
}
