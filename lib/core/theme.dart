import 'package:flutter/material.dart';

ThemeData buildTheme(
  Brightness brightness, {
  Color seedColor = const Color(0xff1e7bf6),
}) {
  final isDark = brightness == Brightness.dark;
  final colorScheme = ColorScheme.fromSeed(
    seedColor: seedColor,
    brightness: brightness,
    surface: isDark ? const Color(0xFF08090D) : const Color(0xFFF2F2F7),
    surfaceContainerLowest: isDark ? const Color(0xFF08090D) : Colors.white,
    surfaceContainerLow: isDark
        ? const Color(0xFF151519)
        : const Color(0xFFF2F2F7),
    surfaceContainer: isDark
        ? const Color(0xFF1C1C1E)
        : const Color(0xFFE8EAEE),
    surfaceContainerHigh: isDark
        ? const Color(0xFF252528)
        : const Color(0xFFE0E2E8),
    surfaceContainerHighest: isDark
        ? const Color(0xFF303034)
        : const Color(0xFFD6D8E0),
    primary: seedColor,
  );

  return ThemeData(
    colorScheme: colorScheme,
    useMaterial3: true,
    brightness: brightness,
    splashFactory: NoSplash.splashFactory,
    scaffoldBackgroundColor: isDark
        ? const Color(0xFF08090D)
        : const Color(0xFFF2F2F7),
    appBarTheme: AppBarTheme(
      backgroundColor: isDark
          ? const Color(0xFF08090D)
          : const Color(0xFFF2F2F7),
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: isDark ? Colors.white : Colors.black87,
        fontSize: 20,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.4,
      ),
      iconTheme: IconThemeData(color: isDark ? Colors.white70 : Colors.black87),
    ),
    sliderTheme: SliderThemeData(
      trackHeight: 4,
      activeTrackColor: seedColor,
      inactiveTrackColor: isDark ? const Color(0xFF323540) : Colors.black12,
      thumbColor: Colors.white,
      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7.0),
      overlayShape: const RoundSliderOverlayShape(overlayRadius: 14.0),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: isDark ? const Color(0xFF252528) : Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedSuperellipseBorder(borderRadius: BorderRadius.circular(26)),
      elevation: 12,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: isDark ? const Color(0xFF1C1C1E) : Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedSuperellipseBorder(borderRadius: BorderRadius.circular(26)),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: isDark ? const Color(0xFF1C1C1E) : Colors.white,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      clipBehavior: Clip.antiAlias,
      shape: const RoundedSuperellipseBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(38)),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(44, 44),
        shape: const StadiumBorder(),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(44, 44),
        shape: const StadiumBorder(),
        side: BorderSide(color: colorScheme.onSurface.withValues(alpha: 0.16)),
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: const WidgetStatePropertyAll(Colors.white),
      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return colorScheme.onSurface.withValues(alpha: 0.08);
        }
        return states.contains(WidgetState.selected)
            ? seedColor
            : colorScheme.onSurface.withValues(alpha: 0.20);
      }),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: isDark
          ? const Color(0xFF16171C)
          : colorScheme.surfaceContainerLow,
      selectedIconTheme: IconThemeData(color: seedColor, size: 22),
      unselectedIconTheme: IconThemeData(
        color: isDark ? Colors.white60 : colorScheme.onSurfaceVariant,
        size: 22,
      ),
      selectedLabelTextStyle: TextStyle(
        color: seedColor,
        fontWeight: FontWeight.w700,
        fontSize: 13,
      ),
      unselectedLabelTextStyle: TextStyle(
        color: isDark ? Colors.white60 : colorScheme.onSurfaceVariant,
        fontWeight: FontWeight.w500,
        fontSize: 12,
      ),
      indicatorColor: seedColor.withValues(alpha: 0.15),
      useIndicator: true,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: isDark
          ? const Color(0xFF16171C)
          : colorScheme.surfaceContainerLow,
      indicatorColor: seedColor.withValues(alpha: 0.2),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return IconThemeData(color: seedColor);
        }
        return IconThemeData(
          color: isDark ? Colors.white60 : colorScheme.onSurfaceVariant,
        );
      }),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return TextStyle(
            color: seedColor,
            fontWeight: FontWeight.w700,
            fontSize: 12,
          );
        }
        return TextStyle(
          color: isDark ? Colors.white60 : colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w500,
          fontSize: 12,
        );
      }),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: isDark
          ? const Color(0xFF1C1C1E)
          : Colors.black.withValues(alpha: 0.05),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: seedColor, width: 1.5),
      ),
    ),
    cardTheme: CardThemeData(
      color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedSuperellipseBorder(borderRadius: BorderRadius.circular(26)),
    ),
  );
}
