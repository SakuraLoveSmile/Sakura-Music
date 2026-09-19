import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:feedback_widget/feedback_widget.dart' show FeedbackLogFile;

import '../../audio/playback_debug_log.dart' show playbackDebugLog;
import '../crash_report.dart' show getCrashLogFile;
import '../security/sensitive_data_redactor.dart' show redactSensitiveText;

/// Byte budget for the crash-log tail attached to a submission. Keeps the
/// attachment far below the component's 1 MiB per-file cap (`kFeedbackMaxLogBytes`)
/// while carrying enough recent history to diagnose a crash.
const int _crashLogTailBytes = 128 * 1024;

/// The host's diagnostics collector wired as `FeedbackConfig.logProvider`
/// (see `buildFeedbackConfig`). The feedback component invokes it lazily when
/// the panel opens, under its own 3s timeout and try/catch.
///
/// Sources, both already redacted at their own sink ([PlaybackDebugLog.add] and
/// `logCrash`):
///  - the in-memory playback ring buffer ([playbackDebugLog], <= 500 entries);
///  - the tail of the on-disk crash log ([getCrashLogFile]), when present.
///
/// Attaching these is an explicit host choice — the component never grabs host
/// info on its own. This never throws: any source that fails is omitted, so a
/// diagnostics problem can't block the user's feedback.
Future<List<FeedbackLogFile>> collectFeedbackLogs() async {
  return buildFeedbackLogFiles(
    playbackText: _playbackLogText(),
    crashTail: await _crashLogTail(),
  );
}

/// Pure builder for the feedback log attachments: shapes and defensively
/// re-redacts [playbackText] / [crashTail] into component-valid
/// [FeedbackLogFile]s. Empty (post-trim) sources are skipped, so an app with no
/// playback history and no crash log attaches nothing.
///
/// Filenames use the `.log` extension (in the component's allow-list) and the
/// sizes stay well under its 1 MiB per-file cap. Split from [collectFeedbackLogs]
/// so the redaction/shaping contract is unit-testable without touching the
/// process-wide ring buffer or the filesystem.
List<FeedbackLogFile> buildFeedbackLogFiles({
  required String playbackText,
  String crashTail = '',
}) {
  final List<FeedbackLogFile> files = <FeedbackLogFile>[];
  final String playback = playbackText.trim();
  if (playback.isNotEmpty) {
    files.add(_logFile('playback.log', playback));
  }
  final String crash = crashTail.trim();
  if (crash.isNotEmpty) {
    files.add(_logFile('crash.log', crash));
  }
  return files;
}

FeedbackLogFile _logFile(String filename, String text) => FeedbackLogFile(
      filename: filename,
      // Redact again defensively: the sinks already sanitize, but a feedback
      // attachment must never leak credentials even if a future producer forgets.
      bytes: Uint8List.fromList(utf8.encode(redactSensitiveText(text))),
      source: 'auto',
    );

String _playbackLogText() {
  try {
    return playbackDebugLog.copyAllText();
  } catch (_) {
    // Diagnostics are best-effort; never let them break a submission.
    return '';
  }
}

Future<String> _crashLogTail() async {
  try {
    final File file = getCrashLogFile();
    if (!await file.exists()) return '';
    final int length = await file.length();
    if (length == 0) return '';
    final int start =
        length > _crashLogTailBytes ? length - _crashLogTailBytes : 0;
    final RandomAccessFile raf = await file.open(mode: FileMode.read);
    try {
      await raf.setPosition(start);
      final List<int> bytes = await raf.read(length - start);
      // allowMalformed: the tail cut may split a multi-byte UTF-8 sequence.
      return utf8.decode(bytes, allowMalformed: true);
    } finally {
      await raf.close();
    }
  } catch (_) {
    // A missing/unreadable crash log simply means no crash attachment.
    return '';
  }
}
