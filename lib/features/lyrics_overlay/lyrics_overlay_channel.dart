import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'lyrics_overlay_config.dart';

/// Boundary for talking to the Android lyrics-overlay implementation. The
/// controller depends on this interface so unit tests can fake the channel.
abstract class LyricsOverlayChannel {
  Future<bool> checkPermission();

  Future<void> requestPermission();

  Future<void> show();

  Future<void> hide();

  Future<void> updateLyrics({
    required String current,
    required String next,
    required bool isPlaying,
  });

  /// Pushes the floating window appearance. Called on every change so the
  /// native window updates live while the user drags a slider.
  Future<void> applyConfig(LyricsOverlayConfig config);

  /// Native reports back when the user closes the overlay from its own close
  /// button, so the Flutter-side switch can stay in sync.
  void setOverlayClosedHandler(void Function() handler);
}

class MethodChannelLyricsOverlayChannel implements LyricsOverlayChannel {
  static const MethodChannel _methodChannel = MethodChannel(
    'sakuramusic/lyrics_overlay',
  );

  void Function()? _onOverlayClosed;

  MethodChannelLyricsOverlayChannel() {
    _methodChannel.setMethodCallHandler((call) async {
      if (call.method == 'onOverlayClosed') {
        _onOverlayClosed?.call();
      }
      return null;
    });
  }

  @override
  Future<bool> checkPermission() async {
    return await _methodChannel.invokeMethod<bool>('checkPermission') ?? false;
  }

  @override
  Future<void> requestPermission() async {
    await _methodChannel.invokeMethod<void>('requestPermission');
  }

  @override
  Future<void> show() async {
    await _methodChannel.invokeMethod<void>('show');
  }

  @override
  Future<void> hide() async {
    await _methodChannel.invokeMethod<void>('hide');
  }

  @override
  Future<void> updateLyrics({
    required String current,
    required String next,
    required bool isPlaying,
  }) async {
    await _methodChannel.invokeMethod<void>('updateLyrics', <String, Object?>{
      'current': current,
      'next': next,
      'isPlaying': isPlaying,
    });
  }

  @override
  Future<void> applyConfig(LyricsOverlayConfig config) async {
    await _methodChannel.invokeMethod<void>(
      'applyConfig',
      config.toChannelMap(),
    );
  }

  @override
  void setOverlayClosedHandler(void Function() handler) {
    _onOverlayClosed = handler;
  }
}

final lyricsOverlayChannelProvider = Provider<LyricsOverlayChannel>((ref) {
  return MethodChannelLyricsOverlayChannel();
});
