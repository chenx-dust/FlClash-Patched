import 'dart:ffi';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:ffi/ffi.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/core/desktop/helper_client.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/plugins/app.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/widgets/input.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart';
import 'package:xml/xml.dart';

class System {
  static System? _instance;
  bool _isTV = false;

  System._internal();

  factory System() {
    _instance ??= System._internal();
    return _instance!;
  }

  bool get isDesktop => isWindows || isMacOS || isLinux;

  bool get isMobile => isAndroid || isIOS;

  bool get isWindows => Platform.isWindows;

  bool get isMacOS => Platform.isMacOS;

  bool get isAndroid => Platform.isAndroid;

  bool get isIOS => Platform.isIOS;

  bool get isLinux => Platform.isLinux;

  bool get isTV => _isTV;

  Future<int> init() async {
    final deviceInfo = await DeviceInfoPlugin().deviceInfo;
    _isTV = switch (deviceInfo) {
      AndroidDeviceInfo(:final systemFeatures) => systemFeatures.any(
        const {
          'android.hardware.type.television',
          'android.software.leanback',
        }.contains,
      ),
      _ => false,
    };
    return switch (Platform.operatingSystem) {
      'macos' => (deviceInfo as MacOsDeviceInfo).majorVersion,
      'android' => (deviceInfo as AndroidDeviceInfo).version.sdkInt,
      'windows' => (deviceInfo as WindowsDeviceInfo).majorVersion,
      'ios' => int.parse(
        (deviceInfo as IosDeviceInfo).systemVersion.split('.').firstOrNull ??
            '0',
      ),
      String() => 0,
    };
  }

  bool supportsPredictiveBack(int version) => isAndroid && version >= 33;

  Future<bool> checkIsAdmin() async {
    final corePath = appPath.corePath;
    if (system.isWindows) {
      return await windowsHelperClient.readiness() ==
          WindowsHelperReadiness.ready;
    } else if (system.isMacOS) {
      final result = await Process.run('stat', ['-f', '%Su:%Sg %Sp', corePath]);
      final output = result.stdout.trim();
      if (output.startsWith('root:admin') && output.contains('rws')) {
        return true;
      }
      return false;
    } else if (Platform.isLinux) {
      final result = await Process.run('stat', ['-c', '%U:%G %A', corePath]);
      final output = result.stdout.trim();
      if (output.startsWith('root:') && output.contains('rws')) {
        return true;
      }
      return false;
    }
    return true;
  }

  static String _shellEscape(String value) {
    return "'${value.replaceAll("'", "'\\''")}'";
  }

  Future<AuthorizeCode> authorizeCore() async {
    if (system.isMobile) {
      return AuthorizeCode.error;
    }
    if (system.isWindows) {
      return await windows?.registerService() ?? AuthorizeCode.error;
    }
    final isAdmin = await checkIsAdmin();
    if (isAdmin) {
      return AuthorizeCode.none;
    }

    if (system.isMacOS) {
      final escapedPath = _shellEscape(appPath.corePath);
      final shell = 'chown root:admin $escapedPath && chmod +sx $escapedPath';
      final arguments = [
        '-e',
        'do shell script "$shell" with administrator privileges',
      ];
      final result = await Process.run('osascript', arguments);
      if (result.exitCode != 0) {
        return AuthorizeCode.error;
      }
      return AuthorizeCode.success;
    }
    if (Platform.isLinux) {
      const shell = 'chown root:root -- "\$1" && chmod +sx -- "\$1"';
      final arguments = ['/bin/sh', '-c', shell, 'sh', appPath.corePath];
      try {
        final result = await Process.run('pkexec', arguments);
        switch (result.exitCode) {
          case 0:
            return AuthorizeCode.success;
          case 127: // Unavailable
            break;
          default:
            return AuthorizeCode.error;
        }
      } catch (_) {
        // Fall back when polkit cannot complete the authorization request.
      }

      final password = await globalState.showCommonDialog<String>(
        child: InputDialog(
          obscureText: true,
          title: currentAppLocalizations.pleaseInputAdminPassword,
          value: '',
          inputFormatters: TextInputLimits.limit(TextInputLimits.password),
        ),
      );
      if (password == null || password.isEmpty) {
        return AuthorizeCode.error;
      }

      try {
        final process = await Process.start('sudo', [
          '-S',
          '-p',
          '',
          '--',
          ...arguments,
        ]);
        final outputDone = Future.wait([
          process.stdout.drain<void>(),
          process.stderr.drain<void>(),
        ]);
        process.stdin.writeln(password);
        await process.stdin.close();
        final exitCode = await process.exitCode;
        await outputDone;
        return exitCode == 0 ? AuthorizeCode.success : AuthorizeCode.error;
      } catch (_) {
        return AuthorizeCode.error;
      }
    }
    return AuthorizeCode.error;
  }

  Future<void> back() async {
    await app?.moveTaskToBack();
    await window?.hide();
  }

  Future<void> exit() async {
    if (system.isMobile) {
      await SystemNavigator.pop();
    }
    window?.forceExit();
  }
}

final system = System();

class Windows {
  static Windows? _instance;
  late DynamicLibrary _shell32;

  Windows._internal() {
    _shell32 = DynamicLibrary.open('shell32.dll');
  }

  factory Windows() {
    _instance ??= Windows._internal();
    return _instance!;
  }

  bool runas(String command, String arguments) {
    final commandPtr = command.toNativeUtf16();
    final argumentsPtr = arguments.toNativeUtf16();
    final operationPtr = 'runas'.toNativeUtf16();

    final shellExecute = _shell32
        .lookupFunction<
          Int32 Function(
            Pointer<Utf16> hwnd,
            Pointer<Utf16> lpOperation,
            Pointer<Utf16> lpFile,
            Pointer<Utf16> lpParameters,
            Pointer<Utf16> lpDirectory,
            Int32 nShowCmd,
          ),
          int Function(
            Pointer<Utf16> hwnd,
            Pointer<Utf16> lpOperation,
            Pointer<Utf16> lpFile,
            Pointer<Utf16> lpParameters,
            Pointer<Utf16> lpDirectory,
            int nShowCmd,
          )
        >('ShellExecuteW');

    final result = shellExecute(
      nullptr,
      operationPtr,
      commandPtr,
      argumentsPtr,
      nullptr,
      1,
    );

    calloc.free(commandPtr);
    calloc.free(argumentsPtr);
    calloc.free(operationPtr);

    commonPrint.log(
      'windows runas: $command $arguments resultCode:$result',
      logLevel: LogLevel.warning,
    );

    if (result <= 32) {
      return false;
    }
    return true;
  }

  Future<AuthorizeCode> registerService() async {
    final readiness = await windowsHelperClient.readiness();
    switch (readiness) {
      case WindowsHelperReadiness.ready:
        commonPrint.log('helper service is ready');
        return AuthorizeCode.none;
      case WindowsHelperReadiness.manifestMissing:
        commonPrint.log(
          'Core manifest is missing or invalid; Helper service unavailable, '
          'falling back to direct Core',
          logLevel: LogLevel.warning,
        );
        globalState.showNotifier(currentAppLocalizations.helperCorruptTip);
        return AuthorizeCode.error;
      case WindowsHelperReadiness.notReady:
        break;
    }

    commonPrint.log(
      'helper service is unavailable, requesting elevated installation',
      logLevel: LogLevel.warning,
    );
    if (!runas(appPath.helperPath, 'install')) {
      commonPrint.log(
        'failed to launch elevated helper installation',
        logLevel: LogLevel.error,
      );
      return AuthorizeCode.error;
    }

    final isRunning = await _waitForHelperService();
    commonPrint.log(
      isRunning
          ? 'helper service installation completed'
          : 'helper service did not become ready after installation',
      logLevel: isRunning ? LogLevel.info : LogLevel.error,
    );
    return isRunning ? AuthorizeCode.success : AuthorizeCode.error;
  }

  Future<bool> _waitForHelperService() async {
    const timeout = Duration(seconds: 6);
    const interval = Duration(seconds: 1);
    const maxAttempts = 6;
    final stopwatch = Stopwatch()..start();
    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      final remaining = timeout - stopwatch.elapsed;
      if (remaining <= Duration.zero) return false;
      final isRunning =
          await windowsHelperClient.readiness(
            timeout: remaining,
            logFailure: false,
          ) ==
          WindowsHelperReadiness.ready;
      if (isRunning) return true;
      final delay = timeout - stopwatch.elapsed;
      if (delay <= Duration.zero || attempt == maxAttempts - 1) return false;
      await Future.delayed(delay < interval ? delay : interval);
    }
    return false;
  }

  Future<bool> isTaskRegistered(String appName) async {
    final result = await Process.run('schtasks.exe', [
      '/Query',
      '/TN',
      appName,
    ]);
    if (result.exitCode != 0) {
      return false;
    }
    return result.stdout.toString().contains(appName);
  }

  Future<bool> unregisterTask(String appName) async {
    if (!await isTaskRegistered(appName)) {
      return true;
    }
    final result = await Process.run('schtasks.exe', [
      '/Delete',
      '/TN',
      appName,
      '/F',
    ]);
    return result.exitCode == 0;
  }

  Future<bool> registerTask(String appName) async {
    final executable = XmlText(Platform.resolvedExecutable).toXmlString();
    final taskXml =
        '''
<?xml version="1.0" encoding="UTF-16"?>
<Task version="1.2" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
  <Principals>
    <Principal id="Author">
      <LogonType>InteractiveToken</LogonType>
    </Principal>
  </Principals>
  <Triggers>
    <LogonTrigger>
      <Delay>PT0S</Delay>
    </LogonTrigger>
  </Triggers>
  <Settings>
    <MultipleInstancesPolicy>IgnoreNew</MultipleInstancesPolicy>
    <DisallowStartIfOnBatteries>false</DisallowStartIfOnBatteries>
    <StopIfGoingOnBatteries>false</StopIfGoingOnBatteries>
    <AllowHardTerminate>false</AllowHardTerminate>
    <StartWhenAvailable>false</StartWhenAvailable>
    <RunOnlyIfNetworkAvailable>false</RunOnlyIfNetworkAvailable>
    <IdleSettings>
      <StopOnIdleEnd>false</StopOnIdleEnd>
      <RestartOnIdle>false</RestartOnIdle>
    </IdleSettings>
    <AllowStartOnDemand>true</AllowStartOnDemand>
    <Enabled>true</Enabled>
    <Hidden>false</Hidden>
    <RunOnlyIfIdle>false</RunOnlyIfIdle>
    <WakeToRun>false</WakeToRun>
    <ExecutionTimeLimit>PT0S</ExecutionTimeLimit>
    <Priority>7</Priority>
  </Settings>
  <Actions Context="Author">
    <Exec>
      <Command>$executable</Command>
    </Exec>
  </Actions>
</Task>''';
    final taskPath = join(await appPath.tempPath, 'task.xml');
    await File(taskPath).create(recursive: true);
    await File(
      taskPath,
    ).writeAsBytes(taskXml.encodeUtf16LeWithBom, flush: true);
    final commandLine = ['/Create', '/TN', appName, '/XML', taskPath, '/F'];
    final result = await Process.run('schtasks.exe', commandLine);
    if (result.exitCode == 0) {
      return true;
    }
    return runas('schtasks.exe', commandLine.join(' '));
  }
}

final windows = system.isWindows ? Windows() : null;

class MacOS {
  static MacOS? _instance;

  List<String>? originDns;

  MacOS._internal();

  factory MacOS() {
    _instance ??= MacOS._internal();
    return _instance!;
  }

  Future<String?> get defaultServiceName async {
    final result = await Process.run('route', ['-n', 'get', 'default']);
    final output = result.stdout.toString();
    final deviceLine = output
        .split('\n')
        .firstWhere((s) => s.contains('interface:'), orElse: () => '');
    final lineSplits = deviceLine.trim().split(' ');
    if (lineSplits.length != 2) {
      return null;
    }
    final device = lineSplits[1];
    final serviceResult = await Process.run('networksetup', [
      '-listnetworkserviceorder',
    ]);
    final serviceResultOutput = serviceResult.stdout.toString();
    final currentService = serviceResultOutput
        .split('\n\n')
        .firstWhere((s) => s.contains('Device: $device'), orElse: () => '');
    if (currentService.isEmpty) {
      return null;
    }
    final currentServiceNameLine = currentService
        .split('\n')
        .firstWhere(
          (line) => RegExp(r'^\(\d+\).*').hasMatch(line),
          orElse: () => '',
        );
    final currentServiceNameLineSplits = currentServiceNameLine.trim().split(
      ' ',
    );
    if (currentServiceNameLineSplits.length < 2) {
      return null;
    }
    return currentServiceNameLineSplits[1];
  }

  Future<List<String>?> get systemDns async {
    final deviceServiceName = await defaultServiceName;
    if (deviceServiceName == null) {
      return null;
    }
    final result = await Process.run('networksetup', [
      '-getdnsservers',
      deviceServiceName,
    ]);
    final output = result.stdout.toString().trim();
    if (output.startsWith("There aren't any DNS Servers set on")) {
      originDns = [];
    } else {
      originDns = output.split('\n');
    }
    return originDns;
  }

  Future<void> updateDns(bool restore) async {
    final serviceName = await defaultServiceName;
    if (serviceName == null) {
      return;
    }
    List<String>? nextDns;
    if (restore) {
      nextDns = originDns;
    } else {
      final originDns = await systemDns;
      if (originDns == null) {
        return;
      }
      const needAddDns = '223.5.5.5';
      if (originDns.contains(needAddDns)) {
        return;
      }
      nextDns = List.from(originDns)..add(needAddDns);
    }
    if (nextDns == null) {
      return;
    }
    await Process.run('networksetup', [
      '-setdnsservers',
      serviceName,
      if (nextDns.isNotEmpty) ...nextDns,
      if (nextDns.isEmpty) 'Empty',
    ]);
  }
}

final macOS = system.isMacOS ? MacOS() : null;
