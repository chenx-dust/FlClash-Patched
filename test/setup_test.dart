import 'package:test/test.dart';

import '../setup.dart' as setup;

void main() {
  group('setup.dart', () {
    test('parses -v as verbose mode', () {
      final results = setup.createSetupArgParser().parse(['android', '-v']);

      expect(results['verbose'], isTrue);
      expect(results.rest, ['android']);
    });

    test('accepts dev application environment', () {
      final results = setup.createSetupArgParser().parse([
        'android',
        '--env',
        'dev',
      ]);

      expect(results['env'], 'dev');
    });

    test('Flutter build environment does not depend on Core SHA256', () {
      expect(setup.createBuildEnvironment('dev'), {'APP_ENV': 'dev'});
    });

    test('omits verbose from flutter build args by default', () {
      final args = setup.createFlutterBuildArgs(
        platform: 'android',
        verbose: false,
      );

      expect(args, ['dart-define-from-file=env.json', 'split-per-abi']);
    });

    test('adds verbose to flutter build args with -v', () {
      final args = setup.createFlutterBuildArgs(
        platform: 'android',
        verbose: true,
      );

      expect(args, [
        'verbose',
        'dart-define-from-file=env.json',
        'split-per-abi',
      ]);
    });

    test('refuses to package while a native build hook is skipped', () {
      const pubspec = '''
hooks:
  user_defines:
    setup:
      build_assets: false
    rust_api:
      build_assets: true
''';

      expect(setup.packagesNotBuildingAssets(pubspec), ['setup']);
      expect(setup.packagesNotBuildingAssets('name: x\n'), isEmpty);
    });

    test('packages every Linux format on every architecture', () {
      expect(setup.createPackageTargets('linux', null), 'deb,appimage,rpm');
      expect(setup.createPackageTargets('linux', 'deb'), 'deb');
      expect(setup.createPackageTargets('macos', null), 'dmg');
    });

    test('packages iOS as an IPA', () {
      expect(setup.createPackageTargets('ios', null), 'ipa');
    });

    test('signs the extensions before the app that embeds them', () {
      final targets = setup.createIOSSigningTargets(
        rootDir: '/repo',
        appPath: '/repo/build/Runner.app',
        appBundleId: 'com.follow.clash',
      );

      expect(targets, [
        (
          bundle: '/repo/build/Runner.app/PlugIns/NECore.appex',
          bundleIdentifier: 'com.follow.clash.NECore',
          entitlements: '/repo/ios/NECore/NECore.entitlements',
        ),
        (
          bundle: '/repo/build/Runner.app/PlugIns/Widget.appex',
          bundleIdentifier: 'com.follow.clash.Widget',
          entitlements: '/repo/ios/Widget/Widget.entitlements',
        ),
        (
          bundle: '/repo/build/Runner.app',
          bundleIdentifier: 'com.follow.clash',
          entitlements: '/repo/ios/Runner/Runner.entitlements',
        ),
      ]);
    });

    test(
      'resolves the app group and names the application in entitlements',
      () {
        const source = '''
<plist version="1.0">
<dict>
	<key>com.apple.security.application-groups</key>
	<array>
		<string>group.\$(APP_BUNDLE_ID)</string>
	</array>
</dict>
</plist>
''';

        final content = setup.createIOSEntitlements(
          source: source,
          appBundleId: 'com.follow.clash',
          bundleIdentifier: 'com.follow.clash.NECore',
        );

        expect(content, contains('<string>group.com.follow.clash</string>'));
        expect(
          content,
          contains(
            '<key>application-identifier</key>\n'
            '\t<string>UNKNOWN000.com.follow.clash.NECore</string>',
          ),
        );
        expect(content, endsWith('</dict>\n</plist>\n'));
      },
    );

    test('downloads the appimagetool build matching the host', () {
      expect(setup.appImageToolArch('arm64'), 'aarch64');
      expect(setup.appImageToolArch('amd64'), 'x86_64');
    });
  });
}
