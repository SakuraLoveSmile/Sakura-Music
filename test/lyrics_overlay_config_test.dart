import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramusic/data/db/tables.dart';
import 'package:sakuramusic/features/lyrics_overlay/lyrics_overlay_config.dart';

void main() {
  test('defaults reproduce the previously hard-coded overlay look', () {
    final config = LyricsOverlayConfig.defaults();

    expect(config.fontScale, 1.0);
    expect(config.textColor, 0xFFFFFFFF);
    expect(config.backgroundOpacity, 184);
    expect(config.cornerRadiusDp, 18.0);
    expect(config.showNextLine, isTrue);
    expect(config.showCloseButton, isTrue);
    expect(config.position, LyricsOverlayPosition.top);
  });

  test('the database column default matches the model defaults', () {
    expect(
      lyricsOverlayConfigDefaultsJson,
      LyricsOverlayConfig.defaults().encode(),
    );
    expect(
      LyricsOverlayConfig.decode(lyricsOverlayConfigDefaultsJson),
      LyricsOverlayConfig.defaults(),
    );
  });

  test('round-trips every field through JSON', () {
    const config = LyricsOverlayConfig(
      fontScale: 1.3,
      textColor: 0xFFFFD1DC,
      backgroundOpacity: 60,
      cornerRadiusDp: 6.5,
      showNextLine: false,
      showCloseButton: false,
      position: LyricsOverlayPosition.bottom,
    );

    expect(LyricsOverlayConfig.decode(config.encode()), config);
    expect(config.toChannelMap(), config.toJson());
  });

  test('malformed JSON falls back to the defaults', () {
    for (final raw in <String?>[null, '', '   ', 'not json', '[1,2,3]']) {
      expect(
        LyricsOverlayConfig.decode(raw),
        LyricsOverlayConfig.defaults(),
        reason: '${raw ?? 'null'} must decode to the defaults',
      );
    }
    // A syntactically valid map without any known key is all defaults too.
    expect(LyricsOverlayConfig.decode('{}'), LyricsOverlayConfig.defaults());
  });

  test('out-of-range values are clamped or replaced instead of accepted', () {
    final config = LyricsOverlayConfig.decode(
      jsonEncode(<String, Object?>{
        'fontScale': 4.2,
        'textColor': -5,
        'backgroundOpacity': 900,
        'cornerRadiusDp': -3,
        'showNextLine': 'yes',
        'showCloseButton': null,
        'position': 'left',
      }),
    );

    expect(config.fontScale, LyricsOverlayConfig.maxFontScale);
    expect(config.textColor, 0xFFFFFFFF);
    expect(config.backgroundOpacity, LyricsOverlayConfig.maxBackgroundOpacity);
    expect(config.cornerRadiusDp, LyricsOverlayConfig.minCornerRadiusDp);
    expect(config.showNextLine, isTrue);
    expect(config.showCloseButton, isTrue);
    expect(config.position, LyricsOverlayPosition.top);
  });

  test('values below the lower bound clamp up', () {
    final config = LyricsOverlayConfig.decode(
      jsonEncode(<String, Object?>{
        'fontScale': 0.1,
        'backgroundOpacity': -20,
        'cornerRadiusDp': 99,
      }),
    );

    expect(config.fontScale, LyricsOverlayConfig.minFontScale);
    expect(config.backgroundOpacity, LyricsOverlayConfig.minBackgroundOpacity);
    expect(config.cornerRadiusDp, LyricsOverlayConfig.maxCornerRadiusDp);
  });

  test('numeric strings and integral doubles are accepted', () {
    final config = LyricsOverlayConfig.decode(
      jsonEncode(<String, Object?>{
        'fontScale': '1.2',
        'textColor': 4294967295,
        'backgroundOpacity': 128.0,
        'cornerRadiusDp': '10',
        'showNextLine': 'false',
        'position': 'center',
      }),
    );

    expect(config.fontScale, 1.2);
    expect(config.textColor, 0xFFFFFFFF);
    expect(config.backgroundOpacity, 128);
    expect(config.cornerRadiusDp, 10.0);
    expect(config.showNextLine, isFalse);
    expect(config.position, LyricsOverlayPosition.center);
  });

  test('copyWith only replaces the named fields', () {
    final config = LyricsOverlayConfig.defaults().copyWith(showNextLine: false);

    expect(config.showNextLine, isFalse);
    expect(config.fontScale, 1.0);
    expect(config.textColor, 0xFFFFFFFF);
    expect(config.backgroundOpacity, 184);
    expect(config.cornerRadiusDp, 18.0);
    expect(config.showCloseButton, isTrue);
    expect(config.position, LyricsOverlayPosition.top);
    expect(config, isNot(LyricsOverlayConfig.defaults()));
  });

  test('the channel payload keeps the documented key names and types', () {
    final payload = LyricsOverlayConfig.defaults().toChannelMap();

    expect(payload.keys, <String>[
      'fontScale',
      'textColor',
      'backgroundOpacity',
      'cornerRadiusDp',
      'showNextLine',
      'showCloseButton',
      'position',
    ]);
    expect(payload['fontScale'], isA<double>());
    expect(payload['textColor'], 0xFFFFFFFF);
    expect(payload['backgroundOpacity'], isA<int>());
    expect(payload['cornerRadiusDp'], isA<double>());
    expect(payload['showNextLine'], isTrue);
    expect(payload['showCloseButton'], isTrue);
    expect(payload['position'], 'top');
  });
}
