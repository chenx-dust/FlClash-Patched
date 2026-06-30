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

    test('Flutter build environment does not depend on Core SHA256', () {
      expect(setup.createBuildEnvironment('dev'), {'APP_ENV': 'dev'});
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
  });
}
