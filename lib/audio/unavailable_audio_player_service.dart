import 'dart:async';

import 'audio_player_service.dart';
import 'equalizer_models.dart';

/// Fallback player used when the platform audio service cannot initialize
/// (e.g. AudioService.init throws on a misbehaving device). The UI still
/// starts; every playback action fails with a predictable [StateError] and
/// the snapshot stays in the error state instead of the app white-screening.
class UnavailableAudioPlayerService implements AudioPlayerService {
  UnavailableAudioPlayerService({
    this.reason = 'Audio playback is unavailable on this device',
  });

  final String reason;

  final StreamController<PlayerSnapshot> _controller =
      StreamController<PlayerSnapshot>.broadcast();

  late final PlayerSnapshot _snapshot = PlayerSnapshot(
    status: PlayerStatus.error,
    error: reason,
  );

  // async so callers receive a failed Future instead of a synchronous throw.
  Future<void> _unavailable() async => throw StateError(reason);

  @override
  Stream<PlayerSnapshot> get snapshot {
    // Broadcast streams have no replay; deliver the error snapshot once to
    // late subscribers the same way a real service would emit its state.
    scheduleMicrotask(() {
      if (!_controller.isClosed) {
        _controller.add(_snapshot);
      }
    });
    return _controller.stream;
  }

  @override
  PlayerSnapshot? get currentSnapshot => _snapshot;

  @override
  Future<void> setQueue(List<PlayableItem> items, {int startIndex = 0}) =>
      _unavailable();

  @override
  Future<void> play() => _unavailable();

  @override
  Future<void> pause() => _unavailable();

  @override
  Future<void> next() => _unavailable();

  @override
  Future<void> previous() => _unavailable();

  @override
  Future<void> seek(Duration position) => _unavailable();

  @override
  Future<void> setLoopMode(AppLoopMode mode) => _unavailable();

  @override
  Future<void> setShuffle(bool enabled) => _unavailable();

  @override
  Future<void> playAt(int index) => _unavailable();

  @override
  Future<void> insertNext(PlayableItem item) => _unavailable();

  @override
  Future<void> removeAt(int index) => _unavailable();

  @override
  Future<void> moveItem(int from, int to) => _unavailable();

  @override
  Future<void> setVolume(double value) => _unavailable();

  @override
  Future<void> setSpeed(double value) => _unavailable();

  @override
  Future<bool> setPreferredOutputDevice(int? deviceId) async => false;

  @override
  Future<void> setEqualizer(EqualizerSettings settings) => _unavailable();

  @override
  Future<void> dispose() async {
    if (!_controller.isClosed) {
      await _controller.close();
    }
  }
}
