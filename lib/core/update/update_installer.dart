import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:flutter/foundation.dart';
import 'package:open_filex/open_filex.dart';
import 'package:url_launcher/url_launcher.dart';

import 'update_models.dart';
import 'update_service.dart';

typedef ProcessStarter =
    Future<Process> Function(
      String executable,
      List<String> arguments, {
      ProcessStartMode mode,
    });

class UpdateInstaller {
  UpdateInstaller({
    ProcessStarter? processStarter,
    Never Function(int exitCode)? exitProcess,
  }) : _processStarter = processStarter ?? Process.start,
       _exitProcess = exitProcess ?? exit;

  final ProcessStarter _processStarter;
  final Never Function(int exitCode) _exitProcess;

  Future<void> installUpdate(File package, AppRelease release) async {
    if (Platform.isAndroid) {
      await _installAndroid(package);
      return;
    }
    if (Platform.isWindows) {
      await _installWindows(package);
      return;
    }
    if (Platform.isMacOS) {
      await _installMacOS(package);
      return;
    }

    await openReleasePage(release);
  }

  Future<void> openReleasePage(AppRelease release) async {
    final launched = await launchUrl(
      release.pageUrl,
      mode: LaunchMode.externalApplication,
    );
    if (!launched) {
      throw const UpdateException('无法打开 GitHub Release 页面');
    }
  }

  Future<void> _installAndroid(File package) async {
    final result = await OpenFilex.open(
      package.path,
      type: 'application/vnd.android.package-archive',
    );
    if (result.type != ResultType.done) {
      throw UpdateException('无法调起系统安装器：${result.message}');
    }
  }

  Future<void> _installWindows(File package) async {
    final executable = File(Platform.resolvedExecutable);
    final installDirectory = executable.parent;
    await _ensureWritable(installDirectory);

    final extractionDirectory = await _extractZip(package);
    final sourceRoot = await _singleTopLevelDirectory(extractionDirectory);
    final executableName = _basename(executable.path);
    final sourceExecutable = File(
      '${sourceRoot.path}${Platform.pathSeparator}$executableName',
    );
    if (!await sourceExecutable.exists()) {
      await _deleteIfExists(extractionDirectory);
      throw const UpdateException('Windows 更新包中没有找到应用程序文件');
    }

    final script = File(
      '${extractionDirectory.parent.path}${Platform.pathSeparator}'
      'sakuramusic-update-${DateTime.now().microsecondsSinceEpoch}.ps1',
    );
    final logDirectory = Directory(
      '${Directory.systemTemp.path}${Platform.pathSeparator}SakuraMusic',
    );
    await logDirectory.create(recursive: true);
    final logPath = '${logDirectory.path}${Platform.pathSeparator}update.log';
    await script.writeAsString(r'''
param(
  [int]$ProcessId,
  [string]$Source,
  [string]$Target,
  [string]$ExecutableName,
  [string]$LogPath
)
$ErrorActionPreference = 'Stop'
try {
  $logDirectory = Split-Path -Parent $LogPath
  New-Item -ItemType Directory -Force -Path $logDirectory | Out-Null
  Set-Content -LiteralPath $LogPath -Value 'update started'
  Add-Content -LiteralPath $LogPath -Value 'waiting for process'
  while (Get-Process -Id $ProcessId -ErrorAction SilentlyContinue) {
    Start-Sleep -Milliseconds 250
  }
  Add-Content -LiteralPath $LogPath -Value 'process exited'
  Add-Content -LiteralPath $LogPath -Value 'copy started'
  Copy-Item -Path (Join-Path $Source '*') -Destination $Target -Recurse -Force
  Add-Content -LiteralPath $LogPath -Value 'copy completed'
  Add-Content -LiteralPath $LogPath -Value 'relaunch started'
  Start-Process -FilePath (Join-Path $Target $ExecutableName)
  Add-Content -LiteralPath $LogPath -Value 'update completed'
  Remove-Item -LiteralPath $Source -Recurse -Force -ErrorAction SilentlyContinue
} catch {
  $_ | Out-String | Add-Content -LiteralPath $LogPath
  exit 1
}
''');

    await _processStarter(
      'powershell.exe',
      buildWindowsUpdaterArguments(
        scriptPath: script.path,
        processId: pid,
        sourcePath: sourceRoot.path,
        targetPath: installDirectory.path,
        executableName: executableName,
        logPath: logPath,
      ),
      mode: ProcessStartMode.detached,
    );
    _exitProcess(0);
  }

  Future<void> _installMacOS(File package) async {
    final targetAppPath = _macOSAppPath();
    final targetApp = Directory(targetAppPath);
    await _ensureWritable(targetApp.parent);

    final extractionDirectory = await _extractZip(package);
    final sourceApp = await _findAppBundle(extractionDirectory);
    if (sourceApp == null) {
      await _deleteIfExists(extractionDirectory);
      throw const UpdateException('macOS 更新包中没有找到应用程序包');
    }

    final script = File(
      '${extractionDirectory.parent.path}${Platform.pathSeparator}'
      'sakuramusic-update-${DateTime.now().microsecondsSinceEpoch}.sh',
    );
    await script.writeAsString(r'''
#!/bin/bash
set -e
process_id="$1"
source_app="$2"
target_app="$3"
while kill -0 "$process_id" 2>/dev/null; do
  sleep 0.25
done
rm -rf "$target_app"
ditto "$source_app" "$target_app"
xattr -dr com.apple.quarantine "$target_app" 2>/dev/null || true
open "$target_app"
rm -rf "$(dirname "$source_app")"
''');
    await Process.run('chmod', <String>['u+x', script.path]);

    await _processStarter('/bin/bash', <String>[
      script.path,
      pid.toString(),
      sourceApp.path,
      targetApp.path,
    ], mode: ProcessStartMode.detached);
    _exitProcess(0);
  }

  /// Builds the Windows updater invocation. Kept separate so the PID and all
  /// paths can be asserted without starting a platform updater in unit tests.
  @visibleForTesting
  static List<String> buildWindowsUpdaterArguments({
    required String scriptPath,
    required int processId,
    required String sourcePath,
    required String targetPath,
    required String executableName,
    required String logPath,
  }) {
    return <String>[
      '-NoProfile',
      '-ExecutionPolicy',
      'Bypass',
      '-File',
      scriptPath,
      processId.toString(),
      sourcePath,
      targetPath,
      executableName,
      logPath,
    ];
  }

  Future<Directory> _extractZip(File package) async {
    final extractionDirectory = Directory(
      '${package.parent.path}${Platform.pathSeparator}'
      'sakuramusic-extract-${DateTime.now().microsecondsSinceEpoch}',
    );
    await extractionDirectory.create(recursive: true);
    try {
      await extractFileToDisk(package.path, extractionDirectory.path);
      return extractionDirectory;
    } catch (_) {
      await _deleteIfExists(extractionDirectory);
      rethrow;
    }
  }

  Future<Directory> _singleTopLevelDirectory(Directory directory) async {
    final entities = await directory.list(followLinks: false).toList();
    if (entities.length == 1 && entities.single is Directory) {
      return entities.single as Directory;
    }
    return directory;
  }

  Future<Directory?> _findAppBundle(Directory directory) async {
    if (directory.path.toLowerCase().endsWith('.app')) {
      return directory;
    }
    await for (final entity in directory.list(
      recursive: true,
      followLinks: false,
    )) {
      if (entity is Directory && entity.path.toLowerCase().endsWith('.app')) {
        return entity;
      }
    }
    return null;
  }

  Future<void> _ensureWritable(Directory directory) async {
    if (!await directory.exists()) {
      throw UpdateException('安装目录不存在：${directory.path}');
    }
    final probe = File(
      '${directory.path}${Platform.pathSeparator}'
      '.sakuramusic-update-probe-${DateTime.now().microsecondsSinceEpoch}',
    );
    try {
      await probe.writeAsString('probe');
    } on FileSystemException {
      throw UpdateException('没有权限写入安装目录：${directory.path}');
    } finally {
      if (await probe.exists()) {
        await probe.delete();
      }
    }
  }

  String _macOSAppPath() {
    var path = Platform.resolvedExecutable;
    for (var i = 0; i < 3; i++) {
      path = _dirname(path);
    }
    if (!path.toLowerCase().endsWith('.app')) {
      throw const UpdateException('无法定位当前 macOS 应用程序包');
    }
    return path;
  }

  String _basename(String value) {
    final separator = Platform.pathSeparator;
    final index = value.lastIndexOf(separator);
    return index == -1 ? value : value.substring(index + 1);
  }

  String _dirname(String value) {
    final separator = Platform.pathSeparator;
    final index = value.lastIndexOf(separator);
    return index <= 0 ? separator : value.substring(0, index);
  }

  Future<void> _deleteIfExists(FileSystemEntity entity) async {
    if (await entity.exists()) {
      await entity.delete(recursive: entity is Directory);
    }
  }
}
