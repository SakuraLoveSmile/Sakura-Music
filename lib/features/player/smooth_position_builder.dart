import 'dart:async';

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../../audio/audio_player_service.dart';

typedef SmoothPositionBuilderCallback =
    Widget Function(
      BuildContext context,
      Duration position,
      SmoothPositionControls controls,
    );

/// Renders a locally interpolated playback position between throttled snapshots.
///
/// The audio service remains the source of truth. This widget only advances the
/// last snapshot while playback is active and snaps back to every incoming
/// snapshot so seeks, pauses, rate changes, and track changes stay accurate.
class SmoothPositionBuilder extends StatefulWidget {
  const SmoothPositionBuilder({
    required this.service,
    required this.builder,
    this.duration,
    super.key,
  });

  final AudioPlayerService service;
  final Duration? duration;
  final SmoothPositionBuilderCallback builder;

  @override
  State<SmoothPositionBuilder> createState() => _SmoothPositionBuilderState();
}

class SmoothPositionControls {
  const SmoothPositionControls({required this.seek, required this.seekEnd});

  final ValueChanged<Duration> seek;
  final VoidCallback seekEnd;
}

class _SmoothPositionBuilderState extends State<SmoothPositionBuilder>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  StreamSubscription<PlayerSnapshot>? _subscription;
  PlayerSnapshot? _snapshot;
  Duration _position = Duration.zero;
  DateTime _lastTick = DateTime.now();
  bool _isSeeking = false;

  @override
  void initState() {
    super.initState();
    _snapshot = widget.service.currentSnapshot;
    _position = _snapshot?.position ?? Duration.zero;
    _ticker = createTicker(_onTick);
    _subscribe(widget.service);
    _updateTicker();
  }

  @override
  void didUpdateWidget(covariant SmoothPositionBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.service != widget.service) {
      _subscription?.cancel();
      _snapshot = widget.service.currentSnapshot;
      _position = _snapshot?.position ?? Duration.zero;
      _isSeeking = false;
      _subscribe(widget.service);
    }
    _position = _clampPosition(_position);
    _updateTicker();
  }

  void _subscribe(AudioPlayerService service) {
    _subscription = service.snapshot.listen(_onSnapshot);
  }

  void _onSnapshot(PlayerSnapshot snapshot) {
    if (!mounted) {
      return;
    }

    final trackChanged =
        _snapshot?.currentIndex != snapshot.currentIndex ||
        _snapshot?.currentItem?.id != snapshot.currentItem?.id;
    _snapshot = snapshot;
    if (!_isSeeking || trackChanged || !snapshot.playing) {
      _position = snapshot.position;
    }
    if (trackChanged || !snapshot.playing) {
      _isSeeking = false;
    }
    _position = _clampPosition(_position);
    _lastTick = DateTime.now();
    _updateTicker();
    setState(() {});
  }

  void _onTick(Duration elapsed) {
    final snapshot = _snapshot;
    if (!mounted || snapshot == null || !snapshot.playing || _isSeeking) {
      return;
    }

    final now = DateTime.now();
    final delta = now.difference(_lastTick);
    _lastTick = now;
    if (delta <= Duration.zero) {
      return;
    }
    _position = _clampPosition(_position + delta * snapshot.speed);
    setState(() {});
  }

  void _seek(Duration position) {
    _isSeeking = true;
    _position = _clampPosition(position);
    _lastTick = DateTime.now();
    _updateTicker();
    setState(() {});
    unawaited(widget.service.seek(position));
  }

  void _seekEnd() {
    _isSeeking = false;
    _lastTick = DateTime.now();
    _updateTicker();
  }

  Duration _clampPosition(Duration position) {
    final duration = widget.duration;
    if (duration == null || duration <= Duration.zero) {
      return position < Duration.zero ? Duration.zero : position;
    }
    if (position < Duration.zero) {
      return Duration.zero;
    }
    if (position > duration) {
      return duration;
    }
    return position;
  }

  void _updateTicker() {
    final shouldTick = mounted && _snapshot?.playing == true && !_isSeeking;
    if (shouldTick && !_ticker.isActive) {
      _lastTick = DateTime.now();
      _ticker.start();
    } else if (!shouldTick && _ticker.isActive) {
      _ticker.stop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(
      context,
      _clampPosition(_position),
      SmoothPositionControls(seek: _seek, seekEnd: _seekEnd),
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _ticker.dispose();
    super.dispose();
  }
}
