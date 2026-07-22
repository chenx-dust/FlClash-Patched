import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../setup.dart' as setup;
import '../tool/geodata.dart' as geodata;

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
        'ABCDE12345',
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
      expect(content, contains('DEVELOPMENT_TEAM = ABCDE12345'));
    });

    test('downloads geodata into the Flutter asset directory', () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'flclash_geodata_test_',
      );
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final subscription = server.listen((request) async {
        request.response.add([1, 2, 3, 4]);
        await request.response.close();
      });
      addTearDown(() async {
        await subscription.cancel();
        await server.close(force: true);
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });

      await geodata.ensureGeoData(
        rootDir: tempDir.path,
        sources: {
          'GeoIP.metadb':
              'http://${server.address.address}:${server.port}/GeoIP.metadb',
        },
      );

      final file = File(p.join(tempDir.path, 'assets', 'data', 'GeoIP.metadb'));
      expect(await file.readAsBytes(), [1, 2, 3, 4]);
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
