import 'dart:ffi';
import 'dart:io';

import 'package:fl_clash/common/app_installer.dart';
import 'package:fl_clash/common/app_update.dart';
import 'package:fl_clash/common/system.dart' show ProcessRunner;
import 'package:test/test.dart';

const _hashA =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

Map<String, dynamic> _asset(String name, {Object? sha256 = _hashA}) => {
  'name': name,
  'url': 'https://example.com/$name',
  'size': 42,
  'sha256': sha256,
};

final _release = ReleaseManifest.fromJson({
  'tag': 'v0.9.4',
  'notes': '- notes',
  'assets': [
    _asset('FlClash-0.9.4-windows-x64-setup.exe'),
    _asset('FlClash-0.9.4-windows-x64-v3-setup.exe'),
    _asset('FlClash-0.9.4-windows-x64.zip'),
    _asset('FlClash-0.9.4-android-arm64-v8a.apk'),
    _asset('FlClash-0.9.4-android-armeabi-v7a.apk'),
    _asset('FlClash-0.9.4-macos-arm64.dmg'),
    _asset('FlClash-0.9.4-linux-x64.AppImage'),
    _asset('FlClash-0.9.4-linux-x64-v3.AppImage'),
    _asset('FlClash-0.9.4-linux-x64.deb'),
    _asset('FlClash-0.9.4-linux-x64.tar.zst'),
  ],
});

Future<ProcessResult> _noPackageManager(String command, List<String> args) =>
    throw ProcessException(command, args);

Future<UpdateTarget> _detect({
  required String os,
  required Abi abi,
  String buildArch = '',
  String executable = '/opt/flclash/FlClash',
  Map<String, String> environment = const {},
  Set<String> existing = const {},
  Future<ProcessResult> Function(String, List<String>) runProcess =
      _noPackageManager,
}) {
  return detectUpdateTarget(
    operatingSystem: os,
    abi: abi,
    buildArch: buildArch,
    executable: executable,
    environment: environment,
    exists: existing.contains,
    runProcess: runProcess,
  );
}

void main() {
  group('detectUpdateTarget', () {
    test('maps the Android process ABI to the split APK name', () async {
      expect(
        await _detect(os: 'android', abi: Abi.androidArm64),
        const UpdateTarget(UpdatePackage.androidApk, 'arm64-v8a'),
      );
      expect(
        await _detect(os: 'android', abi: Abi.androidArm),
        const UpdateTarget(UpdatePackage.androidApk, 'armeabi-v7a'),
      );
      expect(
        await _detect(os: 'android', abi: Abi.androidIA32),
        UpdateTarget.unsupported,
      );
    });

    test('prefers the build architecture over the process ABI', () async {
      final target = await _detect(
        os: 'windows',
        abi: Abi.windowsX64,
        buildArch: 'x64-v3',
        executable: r'C:\Program Files\FlClash\FlClash.exe',
        existing: {r'C:\Program Files\FlClash\unins000.exe'},
      );
      expect(
        target,
        const UpdateTarget(UpdatePackage.windowsInstaller, 'x64-v3'),
      );
    });

    test('a Windows copy with a config folder is portable', () async {
      final target = await _detect(
        os: 'windows',
        abi: Abi.windowsX64,
        executable: r'D:\Apps\FlClash\FlClash.exe',
        existing: {r'D:\Apps\FlClash\config', r'D:\Apps\FlClash\unins000.exe'},
      );
      expect(target.package, UpdatePackage.windowsPortable);
      expect(target.package.installsInPlace, isFalse);
    });

    test('a Windows copy without an uninstaller is not updated', () async {
      final target = await _detect(
        os: 'windows',
        abi: Abi.windowsX64,
        executable: r'D:\build\FlClash.exe',
      );
      expect(target, UpdateTarget.unsupported);
    });

    test('macOS updates an app bundle only', () async {
      expect(
        await _detect(
          os: 'macos',
          abi: Abi.macosArm64,
          executable: '/Applications/FlClash.app/Contents/MacOS/FlClash',
        ),
        const UpdateTarget(UpdatePackage.macosDmg, 'arm64'),
      );
      expect(
        await _detect(
          os: 'macos',
          abi: Abi.macosArm64,
          executable: '/tmp/flutter_tester',
        ),
        UpdateTarget.unsupported,
      );
    });

    test('an AppImage wins over every other Linux layout', () async {
      final target = await _detect(
        os: 'linux',
        abi: Abi.linuxX64,
        environment: {'APPIMAGE': '/home/u/FlClash.AppImage'},
        existing: {'/opt/flclash/config'},
      );
      expect(target.package, UpdatePackage.linuxAppImage);
    });

    test('asks each package manager which one owns the binary', () async {
      final asked = <String>[];
      final target = await _detect(
        os: 'linux',
        abi: Abi.linuxArm64,
        executable: '/usr/share/flclash/FlClash',
        runProcess: (command, args) async {
          asked.add(command);
          expect(args.last, '/usr/share/flclash/FlClash');
          return ProcessResult(0, command == 'rpm' ? 0 : 1, '', '');
        },
      );
      expect(asked, ['dpkg', 'rpm']);
      expect(target, const UpdateTarget(UpdatePackage.linuxRpm, 'arm64'));
      expect(target.package.isPackageManaged, isTrue);
    });

    test('an unowned Linux binary is not updated', () async {
      expect(
        await _detect(os: 'linux', abi: Abi.linuxX64),
        UpdateTarget.unsupported,
      );
    });
  });

  group('planAppUpdate', () {
    test('does not mistake x64 for x64-v3', () {
      final v1 = planAppUpdate(
        _release,
        const UpdateTarget(UpdatePackage.windowsInstaller, 'x64'),
      );
      final v3 = planAppUpdate(
        _release,
        const UpdateTarget(UpdatePackage.windowsInstaller, 'x64-v3'),
      );
      expect(v1?.asset.name, 'FlClash-0.9.4-windows-x64-setup.exe');
      expect(v3?.asset.name, 'FlClash-0.9.4-windows-x64-v3-setup.exe');
    });

    test('selects the package format for each target', () {
      String? nameFor(UpdatePackage package, String arch) =>
          planAppUpdate(_release, UpdateTarget(package, arch))?.asset.name;

      expect(
        nameFor(UpdatePackage.androidApk, 'armeabi-v7a'),
        'FlClash-0.9.4-android-armeabi-v7a.apk',
      );
      expect(
        nameFor(UpdatePackage.linuxAppImage, 'x64-v3'),
        'FlClash-0.9.4-linux-x64-v3.AppImage',
      );
      expect(
        nameFor(UpdatePackage.linuxPacman, 'x64'),
        'FlClash-0.9.4-linux-x64.tar.zst',
      );
      expect(nameFor(UpdatePackage.macosDmg, 'x64'), isNull);
      expect(nameFor(UpdatePackage.unsupported, ''), isNull);
    });

    test('tolerates a release without assets', () {
      expect(
        planAppUpdate(
          const ReleaseManifest(tag: 'v1', notes: ''),
          const UpdateTarget(UpdatePackage.androidApk, 'arm64-v8a'),
        ),
        isNull,
      );
    });
  });

  group('ReleaseManifest', () {
    test('reads the manifest the release script writes', () {
      expect(_release.tag, 'v0.9.4');
      expect(_release.notes, '- notes');
      expect(_release.assets, hasLength(10));
      final asset = _release.assets.first;
      expect(asset.url, 'https://example.com/${asset.name}');
      expect(asset.size, 42);
      expect(asset.sha256, _hashA);
    });

    test('drops an asset without a well-formed hash', () {
      final release = ReleaseManifest.fromJson({
        'tag': 'v1',
        'assets': [
          _asset('FlClash-ok.apk'),
          _asset('FlClash-upper.apk', sha256: _hashA.toUpperCase()),
          _asset('FlClash-short.apk', sha256: 'abc'),
          _asset('FlClash-none.apk', sha256: null),
          'not an asset',
        ],
      });
      expect(release.assets.map((asset) => asset.name), ['FlClash-ok.apk']);
      expect(release.notes, isEmpty);
    });

    test('rejects a manifest without a tag', () {
      expect(
        () => ReleaseManifest.fromJson({'notes': ''}),
        throwsFormatException,
      );
      expect(() => ReleaseManifest.fromJson('v1'), throwsFormatException);
    });

    test('reads a GitHub API release and its sha256 digests', () {
      Map<String, dynamic> apiAsset(String name, Object? digest) => {
        'name': name,
        'browser_download_url': 'https://example.com/$name',
        'size': 42,
        'digest': digest,
      };
      final release = ReleaseManifest.fromGitHubRelease({
        'tag_name': 'v0.9.4',
        'body': '- notes',
        'assets': [
          apiAsset('FlClash-ok.apk', 'sha256:$_hashA'),
          apiAsset('FlClash-sha512.apk', 'sha512:$_hashA'),
          apiAsset('FlClash-none.apk', null),
        ],
      });
      expect(release.tag, 'v0.9.4');
      expect(release.notes, '- notes');
      expect(release.assets.map((asset) => asset.name), ['FlClash-ok.apk']);
      expect(release.assets.single.sha256, _hashA);
      expect(release.assets.single.url, 'https://example.com/FlClash-ok.apk');
      expect(
        () => ReleaseManifest.fromGitHubRelease({'body': ''}),
        throwsFormatException,
      );
    });

    test('hashes a file on disk', () async {
      final dir = await Directory.systemTemp.createTemp('flclash_update');
      addTearDown(() => dir.delete(recursive: true));
      final file = File('${dir.path}/payload')..writeAsStringSync('abc');
      expect(
        await sha256OfFile(file),
        'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',
      );
    });
  });

  test('a copy that cannot update itself downloads its asset directly', () {
    final plan = planAppUpdate(
      _release,
      const UpdateTarget(UpdatePackage.windowsPortable, 'x64'),
    );
    expect(
      browserDownloadUri(plan).toString(),
      'https://example.com/FlClash-0.9.4-windows-x64.zip',
    );
    expect(
      browserDownloadUri(null).toString(),
      'https://github.com/chenx-dust/FlClash-Patched/releases/latest',
    );
  });

  group('package manager update', () {
    ProcessRunner tools(Set<String> present, {List<List<String>>? calls}) {
      return (executable, arguments) async {
        calls?.add([executable, ...arguments]);
        if (arguments.length == 4 && arguments[1] == r'command -v "$1"') {
          final tool = arguments.last;
          return present.contains(tool)
              ? ProcessResult(0, 0, '/usr/bin/$tool\n', '')
              : ProcessResult(0, 1, '', '');
        }
        return ProcessResult(0, 0, '', '');
      };
    }

    test('prefers the dependency-resolving front end', () async {
      expect(
        await packageManagerInstallCommand(
          UpdatePackage.linuxRpm,
          runProcess: tools({'rpm', 'dnf', 'zypper'}),
        ),
        ['/usr/bin/dnf', 'install', '-y'],
      );
      expect(
        await packageManagerInstallCommand(
          UpdatePackage.linuxDeb,
          runProcess: tools({'dpkg'}),
        ),
        ['/usr/bin/dpkg', '-i'],
      );
      expect(
        await packageManagerInstallCommand(
          UpdatePackage.linuxPacman,
          runProcess: tools({'dpkg'}),
        ),
        isNull,
      );
    });

    late Directory dir;
    late File package;
    const plan = AppUpdatePlan(
      target: UpdateTarget(UpdatePackage.linuxDeb, 'x64'),
      asset: ReleaseAsset(
        name: 'FlClash-0.9.4-linux-x64.deb',
        url: 'https://example.com/a.deb',
        size: 3,
        sha256: _hashA,
      ),
    );

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('flclash_pkg');
      package = File('${dir.path}/FlClash-0.9.4-linux-x64.deb')
        ..writeAsStringSync('abc');
    });

    tearDown(() => dir.delete(recursive: true));

    test('elevates the install script through pkexec', () async {
      final calls = <List<String>>[];

      final installed = await appInstaller.installWithPackageManager(
        plan,
        package,
        runProcess: tools({'apt-get'}, calls: calls),
        asRoot: false,
      );

      expect(installed, isTrue);
      expect(calls.last, [
        'pkexec',
        '/bin/sh',
        '-c',
        packageInstallScript,
        'flclash-update',
        package.path,
        _hashA,
        '/usr/bin/apt-get',
        'install',
        '-y',
      ]);
      expect(package.existsSync(), isFalse);
    });

    test('a refused or failed install keeps the package', () async {
      final installed = await appInstaller.installWithPackageManager(
        plan,
        package,
        runProcess: (executable, arguments) async {
          if (executable == 'pkexec') {
            return ProcessResult(0, 126, '', 'dismissed');
          }
          return tools({'apt-get'})(executable, arguments);
        },
        asRoot: false,
      );

      expect(installed, isFalse);
      expect(package.existsSync(), isTrue);
    });

    test('a missing pkexec falls back', () async {
      final installed = await appInstaller.installWithPackageManager(
        plan,
        package,
        runProcess: (executable, arguments) async {
          if (executable == 'pkexec') {
            throw ProcessException(executable, arguments);
          }
          return tools({'apt-get'})(executable, arguments);
        },
        asRoot: false,
      );

      expect(installed, isFalse);
    });

    group('install script', () {
      Future<ProcessResult> runScript(String sha256, String output) {
        return Process.run('/bin/sh', [
          '-c',
          packageInstallScript,
          'flclash-update',
          package.path,
          sha256,
          '/bin/sh',
          '-c',
          r'cp "$1" "$0"',
          output,
        ]);
      }

      test('installs a private copy that matches the hash', () async {
        final output = '${dir.path}/installed';
        final result = await runScript(
          'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',
          output,
        );

        expect(result.exitCode, 0, reason: '${result.stderr}');
        expect(File(output).readAsStringSync(), 'abc');
      });

      test('refuses a copy whose hash differs', () async {
        final output = '${dir.path}/installed';
        final result = await runScript(_hashA, output);

        expect(result.exitCode, isNot(0));
        expect(File(output).existsSync(), isFalse);
      });
    }, skip: Platform.isWindows ? 'needs a POSIX shell' : false);
  });
}
