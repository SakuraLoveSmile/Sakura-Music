import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// One timed line of lyrics sent to the Lyricon center service. [beginMs] is
/// the line's start timestamp; [endMs] is the next line's start (or the song
/// duration for the final line), which is how Lyricon highlights the active
/// line without per-position line lookups.
class StatusBarLyricLine {
  const StatusBarLyricLine({
    required this.beginMs,
    required this.endMs,
    required this.text,
  });

  final int beginMs;
  final int endMs;
  final String text;

  Map<String, Object?> toMap() => <String, Object?>{
    'begin': beginMs,
    'end': endMs,
    'text': text,
  };
}

/// Boundary for talking to the Android Lyricon status-bar lyrics bridge. The
/// controller depends on this interface so unit tests can fake the channel.
abstract class StatusBarLyricsChannel {
  /// Bind the provider to the Lyricon center service. Safe to call repeatedly.
  Future<void> register();

  /// Push the whole song (title, artist, duration and timed lines) at once.
  /// Pass an empty [lines] list for a song with no synced lyrics; pass null
  /// artist for unknown artists.
  Future<void> setSong({
    required String id,
    required String name,
    required String? artist,
    required int durationMs,
    required List<StatusBarLyricLine> lines,
  });

  /// Stream the current playback position in milliseconds.
  Future<void> setPosition(int ms);

  /// Stream the play/pause state.
  Future<void> setPlaybackState(bool playing);

  /// Clear the currently displayed song.
  Future<void> clearSong();

  /// Unbind the provider from the center service and release native resources.
  Future<void> destroy();
}

class MethodChannelStatusBarLyricsChannel implements StatusBarLyricsChannel {
  static const MethodChannel _methodChannel = MethodChannel(
    'sakuramusic/lyricon',
  );

  @override
  Future<void> register() async {
    await _methodChannel.invokeMethod<void>('register');
  }

  @override
  Future<void> setSong({
    required String id,
    required String name,
    required String? artist,
    required int durationMs,
    required List<StatusBarLyricLine> lines,
  }) async {
    await _methodChannel.invokeMethod<void>('setSong', <String, Object?>{
      'id': id,
      'name': name,
      'artist': artist,
      'durationMs': durationMs,
      'lines': lines.map((line) => line.toMap()).toList(),
    });
  }

  @override
  Future<void> setPosition(int ms) async {
    await _methodChannel.invokeMethod<void>('setPosition', <String, Object?>{
      'ms': ms,
    });
  }

  @override
  Future<void> setPlaybackState(bool playing) async {
    await _methodChannel.invokeMethod<void>(
      'setPlaybackState',
      <String, Object?>{'playing': playing},
    );
  }

  @override
  Future<void> clearSong() async {
    await _methodChannel.invokeMethod<void>('clearSong');
  }

  @override
  Future<void> destroy() async {
    await _methodChannel.invokeMethod<void>('destroy');
  }
}

final statusBarLyricsChannelProvider = Provider<StatusBarLyricsChannel>((ref) {
  return MethodChannelStatusBarLyricsChannel();
});
