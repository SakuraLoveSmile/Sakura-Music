import 'dart:io';
import 'dart:ui';

import 'package:flutter/foundation.dart';

import 'crash_report_windows.dart';

const String _appName = 'SakuraMusic';

/// Resolves the directory that hosts the error log for the host platform,
/// using only [Platform.environment] so it works before [runApp] and without
/// any plugin (e.g. path_provider) being registered.
///
///  - Windows: `%APPDATA%/SakuraMusic/logs`
///  - macOS:   `~/Library/Logs/SakuraMusic`
///  - Linux:   `$XDG_STATE_HOME/SakuraMusic/logs` (falling back to
///    `~/.local/state/SakuraMusic/logs`)
Directory getCrashLogDirectory() {
  if (Platform.isWindows) {
    final appData = Platform.environment['APPDATA'];
    if (appData != null && appData.isNotEmpty) {
      return Directory(_join([appData, _appName, 'logs']));
    }
    final profile =
        Platform.environment['USERPROFILE'] ?? Directory.current.path;
    return Directory(_join([profile, _appName, 'logs']));
  }
  if (Platform.isMacOS) {
    final home = Platform.environment['HOME'] ?? Directory.current.path;
    return Directory(_join([home, 'Library', 'Logs', _appName]));
  }
  final stateHome = Platform.environment['XDG_STATE_HOME'] ??
      _join([Platform.environment['HOME'] ?? '.', '.local', 'state']);
  return Directory(_join([stateHome, _appName, 'logs']));
}

/// The concrete `error.log` file inside [getCrashLogDirectory].
File getCrashLogFile() => File(_join([getCrashLogDirectory().path, 'error.log']));

String _join(List<String> parts) =>
    parts.where((part) => part.isNotEmpty).join(Platform.pathSeparator);

/// Installs global error handlers so no failure is ever silent:
///  - [FlutterError.onError] captures framework (build/layout/paint) errors.
///  - [PlatformDispatcher.onError] captures errors that escape the framework.
///
/// Both write a timestamped record to [getCrashLogFile]. This must be called
/// after `WidgetsFlutterBinding.ensureInitialized()` so the framework's error
/// plumbing is fully wired.
void initCrashReporting() {
  FlutterError.onError = (details) {
    logCrash(details.exception, details.stack, context: 'FlutterError');
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    logCrash(error, stack, context: 'PlatformDispatcher');
    return true;
  };

  // Leave a marker so a support session can see how often the app starts.
  try {
    final directory = getCrashLogDirectory();
    directory.createSync(recursive: true);
    getCrashLogFile().writeAsStringSync(
      '=== SakuraMusic start ${DateTime.now().toIso8601String()} ===\n',
      mode: FileMode.append,
      flush: true,
    );
  } catch (_) {
    // Logging must never break startup.
  }
}

/// Appends a timestamped crash record to the error log. Safe to call at any
/// time (including before runApp) because it depends only on dart:io.
void logCrash(Object error, StackTrace? stack, {String? context}) {
  try {
    final directory = getCrashLogDirectory();
    directory.createSync(recursive: true);
    final buffer = StringBuffer()
      ..writeln(
        '[${DateTime.now().toIso8601String()}] CRASH'
        "${context != null ? ' ($context)' : ''}",
      )
      ..writeln(error.toString())
      ..writeln(stack?.toString() ?? '<no stack>')
      ..writeln('${'-' * 50}\n');
    getCrashLogFile().writeAsStringSync(
      buffer.toString(),
      mode: FileMode.append,
      flush: true,
    );
  } catch (_) {
    // Never let logging throw during startup.
  }
}

/// Logs a fatal error that occurred before the UI was shown and, on Windows,
/// pops a native message box so the failure is impossible to miss. On macOS
/// the log file is the only record.
void reportFatalStartupError(Object error, StackTrace stack) {
  logCrash(error, stack, context: 'fatal-startup');
  final logPath = getCrashLogFile().path;
  final message = <String>[
    'SakuraMusic 启动失败 / failed to start.',
    '',
    error.toString(),
    '',
    '日志已写入 / Log written to:',
    logPath,
    '',
    '如需帮助，请将该日志提供给开发者。',
    'Please share this log with the developer.',
  ].join('\n');
  showFatalErrorDialog(message, logPath);
}
