import 'package:just_audio/just_audio.dart';

/// Seam around the platform equalizer effect so the audio service can be
/// unit-tested without a native audio engine. The production implementation
/// delegates to [AndroidEqualizer]; tests supply a fake.
abstract class EqualizerController {
  Future<void> setEnabled(bool enabled);

  Future<EqualizerParameters> get parameters;
}

abstract class EqualizerParameters {
  double get minDecibels;

  double get maxDecibels;

  List<EqualizerBand> get bands;
}

abstract class EqualizerBand {
  Future<void> setGain(double gain);
}

class AndroidEqualizerController implements EqualizerController {
  AndroidEqualizerController(this._delegate);

  final AndroidEqualizer _delegate;

  @override
  Future<void> setEnabled(bool enabled) => _delegate.setEnabled(enabled);

  @override
  Future<EqualizerParameters> get parameters =>
      _delegate.parameters.then(AndroidEqualizerParametersAdapter.new);
}

class AndroidEqualizerParametersAdapter implements EqualizerParameters {
  AndroidEqualizerParametersAdapter(this._delegate);

  final AndroidEqualizerParameters _delegate;

  @override
  double get minDecibels => _delegate.minDecibels;

  @override
  double get maxDecibels => _delegate.maxDecibels;

  @override
  List<EqualizerBand> get bands =>
      _delegate.bands.map(AndroidEqualizerBandAdapter.new).toList();
}

class AndroidEqualizerBandAdapter implements EqualizerBand {
  AndroidEqualizerBandAdapter(this._delegate);

  final AndroidEqualizerBand _delegate;

  @override
  Future<void> setGain(double gain) => _delegate.setGain(gain);
}
