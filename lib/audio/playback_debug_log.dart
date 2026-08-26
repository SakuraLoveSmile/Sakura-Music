import 'dart:async';

import 'package:flutter/foundation.dart';

/// A single timestamped line in the playback debug ring buffer.
class PlaybackLogEntry {
  PlaybackLogEntry(this.message) : timestamp = DateTime.now();

  final DateTime timestamp;
  final String message;

  String get line {
    final h = timestamp.hour.toString().padLeft(2, '0');
    final m = timestamp.minute.toString().padLeft(2, '0');
    final s = timestamp.second.toString().padLeft(2, '0');
    final ms = timestamp.millisecond.toString().padLeft(3, '0');
    return '[$h:$m:$s.$ms] $message';
  }
}

/// Bounded, in-memory ring buffer that collects playback diagnostics so they
/// can be surfaced in the debug screen and copied for bug reports.
///
/// Every [add] is also echoed through [debugPrint] so the same evidence shows
/// up in `adb logcat` without switching tools.
class PlaybackDebugLog {
  PlaybackDebugLog._();

  static const int _maxEntries = 500;

  final List<PlaybackLogEntry> _entries = <PlaybackLogEntry>[];
  final StreamController<PlaybackLogEntry> _controller =
      StreamController<PlaybackLogEntry>.broadcast();

  /// A broadcast stream of new entries, suitable for UI subscription.
  Stream<PlaybackLogEntry> get stream => _controller.stream;

  /// A snapshot of the buffered entries, oldest first.
  List<PlaybackLogEntry> get entries =>
      List<PlaybackLogEntry>.unmodifiable(_entries);

  int get length => _entries.length;

  void add(String message) {
    final entry = PlaybackLogEntry(message);
    _entries.add(entry);
    if (_entries.length > _maxEntries) {
      _entries.removeAt(0);
    }
    debugPrint('[PlaybackDebug] $message');
    if (!_controller.isClosed) {
      _controller.add(entry);
    }
  }

  /// Removes every buffered entry.
  void clear() {
    _entries.clear();
    add('Log cleared');
  }

  /// Returns all buffered lines as a single newline-separated string for
  /// clipboard export.
  String copyAllText() => _entries.map((entry) => entry.line).join('\n');

  void dispose() {
    if (!_controller.isClosed) {
      _controller.close();
    }
  }
}

/// Process-wide singleton used across the audio layer.
final playbackDebugLog = PlaybackDebugLog._();
