import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'audio_player_provider.dart';
import 'audio_player_service.dart';

enum SleepTimerPhase { inactive, countdown, endOfTrack, fading }

/// Single source of truth for the sleep timer, shared by the full player and
/// the mini player. Exactly one controller instance exists per audio service,
/// so both UIs always observe (and mutate) the same timer state.
///
/// Behaviour:
/// * countdown — fades the volume out over the last [fadeDuration], pauses
///   playback and restores the volume that was present before the fade;
/// * endOfTrack — pauses as soon as the player reports a completed track;
/// * cancel/replace — invalidates any in-flight fade via a generation counter
///   and restores a volume that a fade may already have lowered.
class SleepTimerController extends ChangeNotifier {
  SleepTimerController({
    required AudioPlayerService service,
    this.fadeDuration = const Duration(seconds: 20),
  }) : _service = service {
    _subscription = service.snapshot.listen(_onSnapshot);
  }

  final AudioPlayerService _service;

  /// How long the volume fade lasts before the final pause. Tests inject a
  /// short value; production fades over 20 seconds.
  final Duration fadeDuration;

  SleepTimerPhase _phase = SleepTimerPhase.inactive;
  DateTime? _endAt;
  Timer? _countdown;
  StreamSubscription<PlayerSnapshot>? _subscription;

  /// Incremented whenever the timer is cancelled, replaced or fires; an
  /// in-flight fade loop compares its own generation and stops when it no
  /// longer matches.
  int _generation = 0;
  double? _volumeBeforeFade;

  SleepTimerPhase get phase => _phase;
  DateTime? get endAt => _endAt;
  bool get isActive => _phase != SleepTimerPhase.inactive;
  bool get isEndOfTrack => _phase == SleepTimerPhase.endOfTrack;

  /// Remaining countdown time; zero when no countdown is running.
  Duration get remaining {
    final end = _endAt;
    if (_phase != SleepTimerPhase.countdown || end == null) {
      return Duration.zero;
    }
    final left = end.difference(DateTime.now());
    return left.isNegative ? Duration.zero : left;
  }

  /// Starts (or replaces) a countdown sleep timer.
  void start(Duration duration) {
    if (duration <= Duration.zero) {
      return;
    }
    _stopInternal();
    _phase = SleepTimerPhase.countdown;
    _endAt = DateTime.now().add(duration);
    _countdown = Timer(duration, _onCountdownEnd);
    notifyListeners();
  }

  /// Stops after the currently playing track finishes.
  void startEndOfTrack() {
    _stopInternal();
    _phase = SleepTimerPhase.endOfTrack;
    notifyListeners();
  }

  /// Cancels the timer and restores a faded volume.
  void cancel() {
    _stopInternal();
    notifyListeners();
  }

  /// Tears down any running timer/fade. An active fade is invalidated via
  /// the generation counter and its lowered volume is restored here; a plain
  /// countdown that never reached the fade phase leaves the volume alone.
  void _stopInternal() {
    _generation++;
    _countdown?.cancel();
    _countdown = null;
    _endAt = null;
    final wasFading = _phase == SleepTimerPhase.fading;
    final volume = _volumeBeforeFade;
    _volumeBeforeFade = null;
    _phase = SleepTimerPhase.inactive;
    if (wasFading && volume != null) {
      unawaited(_service.setVolume(volume));
    }
  }

  Future<void> _onCountdownEnd() async {
    _countdown = null;
    final generation = ++_generation;
    _phase = SleepTimerPhase.fading;
    notifyListeners();

    final originalVolume = _service.currentSnapshot?.volume ?? 1.0;
    _volumeBeforeFade = originalVolume;
    const steps = 10;
    final stepDuration = fadeDuration ~/ steps;
    for (var step = 1; step <= steps; step++) {
      await Future<void>.delayed(stepDuration);
      if (generation != _generation) {
        // Cancelled or replaced mid-fade; the canceller owns the volume now.
        return;
      }
      final value = originalVolume * (1 - step / steps);
      await _service.setVolume(value.clamp(0.0, 1.0).toDouble());
    }
    if (generation != _generation) {
      return;
    }
    await _service.pause();
    await _service.setVolume(originalVolume);
    _volumeBeforeFade = null;
    _phase = SleepTimerPhase.inactive;
    _endAt = null;
    notifyListeners();
  }

  void _onSnapshot(PlayerSnapshot snapshot) {
    if (_phase != SleepTimerPhase.endOfTrack) {
      return;
    }
    if (snapshot.status == PlayerStatus.completed) {
      _stopInternal();
      unawaited(_service.pause());
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _generation++;
    _countdown?.cancel();
    _countdown = null;
    unawaited(_subscription?.cancel());
    super.dispose();
  }
}

final sleepTimerControllerProvider = Provider<SleepTimerController>((ref) {
  final controller = SleepTimerController(
    service: ref.watch(audioPlayerProvider),
  );
  ref.onDispose(controller.dispose);
  return controller;
});
