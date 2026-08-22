import 'dart:async';
import 'dart:io';

import 'package:smtc_windows/smtc_windows.dart';

import 'audio_player_service.dart';

/// Bridges the desktop player to Windows System Media Transport Controls.
/// The package is only constructed on Windows, keeping other platforms inert.
class SmtcWindowsIntegration {
  SmtcWindowsIntegration({required this.service}) {
    if (!Platform.isWindows) {
      return;
    }
    _smtc = SMTCWindows();
    _subscriptions.add(service.snapshot.listen(_publishSnapshot));
    _subscriptions.add(_smtc!.buttonPressStream.listen(_onButton));
    _subscriptions.add(_smtc!.shuffleChangeStream.listen(service.setShuffle));
    _subscriptions.add(
      _smtc!.repeatModeChangeStream.listen((mode) {
        unawaited(
          service.setLoopMode(switch (mode) {
            RepeatMode.none => AppLoopMode.off,
            RepeatMode.list => AppLoopMode.all,
            RepeatMode.track => AppLoopMode.one,
          }),
        );
      }),
    );
  }

  final AudioPlayerService service;
  SMTCWindows? _smtc;
  final List<StreamSubscription<dynamic>> _subscriptions =
      <StreamSubscription<dynamic>>[];

  void _publishSnapshot(PlayerSnapshot snapshot) {
    final smtc = _smtc;
    if (smtc == null) {
      return;
    }
    final item = snapshot.currentItem;
    final duration = snapshot.duration ?? item?.duration ?? Duration.zero;
    unawaited(
      smtc.updateMetadata(
        MusicMetadata(
          title: item?.title,
          artist: item?.artist,
          album: item?.album,
          thumbnail: item?.artworkUrl,
        ),
      ),
    );
    unawaited(
      smtc.updateTimeline(
        PlaybackTimeline(
          startTimeMs: 0,
          endTimeMs: duration.inMilliseconds,
          positionMs: snapshot.position.inMilliseconds,
        ),
      ),
    );
    unawaited(smtc.setShuffleEnabled(snapshot.shuffle));
    unawaited(
      smtc.setRepeatMode(switch (snapshot.loopMode) {
        AppLoopMode.off => RepeatMode.none,
        AppLoopMode.all => RepeatMode.list,
        AppLoopMode.one => RepeatMode.track,
      }),
    );
    unawaited(
      smtc.setPlaybackStatus(
        item == null
            ? PlaybackStatus.stopped
            : snapshot.playing
            ? PlaybackStatus.playing
            : PlaybackStatus.paused,
      ),
    );
  }

  void _onButton(PressedButton button) {
    unawaited(switch (button) {
      PressedButton.play => service.play(),
      PressedButton.pause => service.pause(),
      PressedButton.next => service.next(),
      PressedButton.previous => service.previous(),
      PressedButton.stop => service.pause(),
      PressedButton.fastForward => _seekBy(const Duration(seconds: 10)),
      PressedButton.rewind => _seekBy(const Duration(seconds: -10)),
      _ => Future<void>.value(),
    });
  }

  Future<void> _seekBy(Duration offset) async {
    final snapshot = await service.snapshot.first;
    final duration = snapshot.duration ?? snapshot.currentItem?.duration;
    var position = snapshot.position + offset;
    if (position < Duration.zero) {
      position = Duration.zero;
    }
    if (duration != null && position > duration) {
      position = duration;
    }
    await service.seek(position);
  }

  Future<void> dispose() async {
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    await _smtc?.dispose();
  }
}
