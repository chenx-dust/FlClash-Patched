import 'package:test/test.dart';

import '../setup.dart' as setup;

void main() {
  group('setup.dart', () {
    test('parses -v as verbose mode', () {
      final results = setup.createSetupArgParser().parse(['android', '-v']);

      expect(results['verbose'], isTrue);
      expect(results.rest, ['android']);
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
        'export-method=app-store',
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
        'export-options-plist=ios/ExportOptions.plist',
      ]);
    });
  });
}
