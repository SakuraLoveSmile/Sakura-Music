import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

/// Shows a blocking native message box on Windows. Uses only FFI, so it works
/// even when every Flutter plugin (and its native libraries) failed to load —
/// the exact situation that previously left users with a silent white screen.
///
/// On non-Windows platforms this is a no-op; importing win32 here is safe
/// because win32 resolves its native libraries lazily, so merely loading the
/// library on macOS/Linux never touches a Windows DLL. The guard below ensures
/// no win32 symbol is ever accessed off Windows.
void showFatalErrorDialog(String message, String logPath) {
  if (!Platform.isWindows) {
    return;
  }
  try {
    final textPtr = message.toNativeUtf16();
    final captionPtr = 'SakuraMusic — Fatal Error'.toNativeUtf16();
    MessageBoxW(NULL, textPtr, captionPtr, MB_ICONERROR | MB_OK);
    free(textPtr);
    free(captionPtr);
  } catch (_) {
    // If even the message box cannot be shown, the log file remains.
  }
}
