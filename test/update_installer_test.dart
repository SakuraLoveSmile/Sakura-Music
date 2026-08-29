import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramusic/core/update/update_installer.dart';

void main() {
  test('Windows updater receives a numeric PID and all install paths', () {
    final arguments = UpdateInstaller.buildWindowsUpdaterArguments(
      scriptPath: r'C:\Temp\update.ps1',
      processId: 12345,
      sourcePath: r'C:\Temp\extracted',
      targetPath: r'C:\Apps\SakuraMusic',
      executableName: 'sakuramusic.exe',
      logPath: r'C:\Users\demo\AppData\Local\Temp\SakuraMusic\update.log',
    );

    expect(arguments[5], '12345');
    expect(int.tryParse(arguments[5]), isNotNull);
    expect(arguments, isNot(contains(r'$pid')));
    expect(arguments[6], r'C:\Temp\extracted');
    expect(arguments[7], r'C:\Apps\SakuraMusic');
    expect(arguments[8], 'sakuramusic.exe');
    expect(
      arguments[9],
      r'C:\Users\demo\AppData\Local\Temp\SakuraMusic\update.log',
    );
  });
}
