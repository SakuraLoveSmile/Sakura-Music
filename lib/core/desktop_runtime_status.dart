/// Runtime flags for optional desktop media integrations.
///
/// Set by the bootstrap in `main.dart` once each integration has been
/// initialised (or has failed). The audio layer reads these to degrade
/// gracefully without any provider signature changes.
bool _mediaKitReady = false;
bool _smtcWindowsReady = false;

bool get mediaKitReady => _mediaKitReady;
bool get smtcWindowsReady => _smtcWindowsReady;

void setMediaKitReady(bool value) => _mediaKitReady = value;
void setSmtcWindowsReady(bool value) => _smtcWindowsReady = value;
