import 'dart:convert';

import 'package:flutter/foundation.dart';

/// Vertical anchor of the floating lyrics window.
enum LyricsOverlayPosition {
  top,
  center,
  bottom;

  static LyricsOverlayPosition parse(Object? value) {
    if (value is String) {
      for (final position in LyricsOverlayPosition.values) {
        if (position.name == value) {
          return position;
        }
      }
    }
    return LyricsOverlayPosition.top;
  }
}

/// Appearance of the Android floating lyrics window.
///
/// The defaults reproduce the look that was hard-coded in
/// `LyricsOverlayService` before it became configurable, so upgrading an
/// existing database never changes what the user sees.
@immutable
class LyricsOverlayConfig {
  const LyricsOverlayConfig({
    this.fontScale = 1.0,
    this.textColor = 0xFFFFFFFF,
    this.backgroundOpacity = 184,
    this.cornerRadiusDp = 18.0,
    this.showNextLine = true,
    this.showCloseButton = true,
    this.position = LyricsOverlayPosition.top,
  });

  /// Scale applied to the current (16sp) and next (12sp) lyric lines.
  static const double minFontScale = 0.6;

  /// Upper bound of [fontScale].
  static const double maxFontScale = 1.6;

  /// Smallest background alpha (fully transparent).
  static const int minBackgroundOpacity = 0;

  /// Largest background alpha (fully opaque), the value of an ARGB channel.
  static const int maxBackgroundOpacity = 255;

  /// Lower bound of the window corner radius.
  static const double minCornerRadiusDp = 0;

  /// Upper bound of the window corner radius.
  static const double maxCornerRadiusDp = 32;

  /// The appearance used before this settings screen existed.
  static const LyricsOverlayConfig _defaults = LyricsOverlayConfig();

  final double fontScale;

  /// ARGB colour of the current lyric line.
  final int textColor;

  /// Alpha channel of the window background (0-255).
  final int backgroundOpacity;

  final double cornerRadiusDp;

  final bool showNextLine;

  final bool showCloseButton;

  final LyricsOverlayPosition position;

  static LyricsOverlayConfig defaults() => _defaults;

  /// Decodes a stored JSON blob. Missing, malformed or out-of-range values
  /// fall back to the corresponding default instead of producing a broken
  /// window.
  static LyricsOverlayConfig decode(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return _defaults;
    }
    Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } catch (_) {
      return _defaults;
    }
    if (decoded is! Map) {
      return _defaults;
    }
    return fromJson(decoded.cast<Object?, Object?>());
  }

  /// Builds a config from a decoded JSON map, clamping every out-of-range
  /// number and replacing invalid fields with their defaults.
  static LyricsOverlayConfig fromJson(Map<Object?, Object?> json) {
    return LyricsOverlayConfig(
      fontScale: _readDouble(
        json['fontScale'],
        _defaults.fontScale,
        minFontScale,
        maxFontScale,
      ),
      textColor: _readColor(json['textColor'], _defaults.textColor),
      backgroundOpacity: _readInt(
        json['backgroundOpacity'],
        _defaults.backgroundOpacity,
        minBackgroundOpacity,
        maxBackgroundOpacity,
      ),
      cornerRadiusDp: _readDouble(
        json['cornerRadiusDp'],
        _defaults.cornerRadiusDp,
        minCornerRadiusDp,
        maxCornerRadiusDp,
      ),
      showNextLine: _readBool(json['showNextLine'], _defaults.showNextLine),
      showCloseButton: _readBool(
        json['showCloseButton'],
        _defaults.showCloseButton,
      ),
      position: LyricsOverlayPosition.parse(json['position']),
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'fontScale': fontScale,
      'textColor': textColor,
      'backgroundOpacity': backgroundOpacity,
      'cornerRadiusDp': cornerRadiusDp,
      'showNextLine': showNextLine,
      'showCloseButton': showCloseButton,
      'position': position.name,
    };
  }

  String encode() => jsonEncode(toJson());

  /// Payload of the `applyConfig` method channel call.
  Map<String, Object?> toChannelMap() => toJson();

  LyricsOverlayConfig copyWith({
    double? fontScale,
    int? textColor,
    int? backgroundOpacity,
    double? cornerRadiusDp,
    bool? showNextLine,
    bool? showCloseButton,
    LyricsOverlayPosition? position,
  }) {
    return LyricsOverlayConfig(
      fontScale: fontScale ?? this.fontScale,
      textColor: textColor ?? this.textColor,
      backgroundOpacity: backgroundOpacity ?? this.backgroundOpacity,
      cornerRadiusDp: cornerRadiusDp ?? this.cornerRadiusDp,
      showNextLine: showNextLine ?? this.showNextLine,
      showCloseButton: showCloseButton ?? this.showCloseButton,
      position: position ?? this.position,
    );
  }

  static double _readDouble(
    Object? value,
    double fallback,
    double min,
    double max,
  ) {
    final parsed = switch (value) {
      final num number => number.toDouble(),
      final String text => double.tryParse(text),
      _ => null,
    };
    if (parsed == null || !parsed.isFinite) {
      return fallback;
    }
    return parsed.clamp(min, max).toDouble();
  }

  static int _readInt(Object? value, int fallback, int min, int max) {
    final parsed = switch (value) {
      final int number => number,
      final double number => number.round(),
      final String text => int.tryParse(text),
      _ => null,
    };
    if (parsed == null) {
      return fallback;
    }
    return parsed.clamp(min, max);
  }

  static int _readColor(Object? value, int fallback) {
    final parsed = switch (value) {
      final int number => number,
      final double number => number.round(),
      final String text => int.tryParse(text),
      _ => null,
    };
    if (parsed == null || parsed < 0 || parsed > 0xFFFFFFFF) {
      return fallback;
    }
    return parsed;
  }

  static bool _readBool(Object? value, bool fallback) {
    if (value is bool) {
      return value;
    }
    if (value == 'true') {
      return true;
    }
    if (value == 'false') {
      return false;
    }
    return fallback;
  }

  @override
  bool operator ==(Object other) {
    return other is LyricsOverlayConfig &&
        other.fontScale == fontScale &&
        other.textColor == textColor &&
        other.backgroundOpacity == backgroundOpacity &&
        other.cornerRadiusDp == cornerRadiusDp &&
        other.showNextLine == showNextLine &&
        other.showCloseButton == showCloseButton &&
        other.position == position;
  }

  @override
  int get hashCode => Object.hash(
    fontScale,
    textColor,
    backgroundOpacity,
    cornerRadiusDp,
    showNextLine,
    showCloseButton,
    position,
  );

  @override
  String toString() =>
      'LyricsOverlayConfig(fontScale: $fontScale, textColor: $textColor, '
      'backgroundOpacity: $backgroundOpacity, '
      'cornerRadiusDp: $cornerRadiusDp, showNextLine: $showNextLine, '
      'showCloseButton: $showCloseButton, position: ${position.name})';
}
