import 'package:flutter/material.dart';

ThemeData buildTheme(
  Brightness brightness, {
  Color seedColor = const Color(0xff1e7bf6),
}) {
  final isDark = brightness == Brightness.dark;
  final colorScheme = ColorScheme.fromSeed(
    seedColor: seedColor,
    brightness: brightness,
    surface: isDark ? const Color(0xFF131418) : const Color(0xFFF7F8FA),
    surfaceContainerLowest: isDark ? const Color(0xFF0D0E11) : Colors.white,
    surfaceContainerLow: isDark ? const Color(0xFF16171C) : const Color(0xFFF0F1F5),
    surfaceContainer: isDark ? const Color(0xFF1C1D23) : const Color(0xFFE8EAEE),
    surfaceContainerHigh: isDark ? const Color(0xFF22242C) : const Color(0xFFE0E2E8),
    surfaceContainerHighest: isDark ? const Color(0xFF2A2C37) : const Color(0xFFD6D8E0),
    primary: seedColor,
  );

  return ThemeData(
    colorScheme: colorScheme,
    useMaterial3: true,
    brightness: brightness,
    scaffoldBackgroundColor: isDark ? const Color(0xFF131418) : const Color(0xFFF7F8FA),
    appBarTheme: AppBarTheme(
      backgroundColor: isDark ? const Color(0xFF131418) : const Color(0xFFF7F8FA),
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: isDark ? Colors.white : Colors.black87,
        fontSize: 20,
        fontWeight: FontWeight.w700,
      ),
      iconTheme: IconThemeData(
        color: isDark ? Colors.white70 : Colors.black87,
      ),
    ),
    sliderTheme: SliderThemeData(
      trackHeight: 3.5,
      activeTrackColor: seedColor,
      inactiveTrackColor: isDark ? const Color(0xFF323540) : Colors.black12,
      thumbColor: Colors.white,
      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6.0),
      overlayShape: const RoundSliderOverlayShape(overlayRadius: 14.0),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: isDark ? const Color(0xFF22242D) : Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 6,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: isDark ? const Color(0xFF1E2028) : Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: isDark ? const Color(0xFF16171C) : colorScheme.surfaceContainerLow,
      selectedIconTheme: IconThemeData(
        color: seedColor,
        size: 22,
      ),
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
      backgroundColor: isDark ? const Color(0xFF16171C) : colorScheme.surfaceContainerLow,
      indicatorColor: seedColor.withValues(alpha: 0.2),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return IconThemeData(color: seedColor);
        }
        return IconThemeData(color: isDark ? Colors.white60 : colorScheme.onSurfaceVariant);
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
      fillColor: isDark ? const Color(0xFF22242D) : Colors.black.withValues(alpha: 0.05),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: seedColor, width: 1.5),
      ),
    ),
    cardTheme: CardThemeData(
      color: isDark ? const Color(0xFF1C1D23) : Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );
}

