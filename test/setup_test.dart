import 'dart:io';

import 'package:path/path.dart' as p;
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

    test('parses iOS bundle identifier override', () {
      final results = setup.createSetupArgParser().parse([
        'ios',
        '--ios-bundle-id',
        'com.example.flclash',
      ]);

      expect(results['ios-bundle-id'], 'com.example.flclash');
      expect(results.rest, ['ios']);
    });

    test('writes generated iOS bundle config', () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'flclash_setup_test_',
      );
      addTearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });

      await setup.writeIOSGeneratedBundleConfig(
        tempDir.path,
        'com.example.flclash',
      );

      final configFile = File(
        p.join(
          tempDir.path,
          'ios',
          'Flutter',
          'GeneratedBundleConfig.xcconfig',
        ),
      );
      final content = await configFile.readAsString();
      expect(content, contains('APP_BUNDLE_ID = com.example.flclash'));
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

    test('adds default iOS export method to flutter build args', () {
      final args = setup.createFlutterBuildArgs(
        platform: 'ios',
        verbose: false,
      );

      expect(args, [
        'dart-define-from-file=env.json',
        'ipa-export-method=app-store',
      ]);
    });

    test('uses iOS export options plist when provided', () {
      final args = setup.createFlutterBuildArgs(
        platform: 'ios',
        verbose: false,
        iosExportOptionsPlist: 'ios/ExportOptions.plist',
      );

      expect(args, [
        'dart-define-from-file=env.json',
        'ipa-export-options-plist=ios/ExportOptions.plist',
      ]);
    });
  });
}
