import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

/// Shows a blocking native message box on Windows. Uses only raw FFI against
/// user32.dll, so it works even when every Flutter plugin (and its native
/// libraries) failed to load — the exact situation that previously left users
/// with a silent white screen.
///
/// On non-Windows platforms this is a no-op; the guard below ensures no Win32
/// symbol is ever touched off Windows.
void showFatalErrorDialog(String message, String logPath) {
  if (!Platform.isWindows) {
    return;
  }
  try {
    final user32 = DynamicLibrary.open('user32.dll');
    final messageBoxW = user32.lookupFunction<
        Int32 Function(Pointer<Void>, Pointer<Utf16>, Pointer<Utf16>, Uint32),
        int Function(Pointer<Void>, Pointer<Utf16>, Pointer<Utf16>, int)>(
      'MessageBoxW',
    );
    final textPtr = message.toNativeUtf16();
    final captionPtr = 'SakuraMusic — Fatal Error'.toNativeUtf16();
    // MB_OK (0x0) | MB_ICONERROR (0x10).
    messageBoxW(nullptr, textPtr, captionPtr, 0x10);
    free(textPtr);
    free(captionPtr);
  } catch (_) {
    // If even the message box cannot be shown, the log file remains.
  }
}
