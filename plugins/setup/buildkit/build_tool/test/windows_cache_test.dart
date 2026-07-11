import 'dart:io';

import 'package:build_tool/src/build_cache.dart';
import 'package:test/test.dart';

void main() {
  late Directory temporaryDirectory;
  late BuildCache cache;
  late BuildNotice notice;
  late File coreOutput;
  late File helperOutput;
  late int coreBuilds;
  late int helperBuilds;
  late int taskKills;

  setUp(() {
    temporaryDirectory = Directory.systemTemp.createTempSync(
      'setup_windows_cache_test_',
    );
    cache = BuildCache(rootDir: temporaryDirectory.path);
    notice = BuildNotice();
    coreOutput = File('${temporaryDirectory.path}/core.exe');
    helperOutput = File('${temporaryDirectory.path}/helper.exe');
    coreBuilds = 0;
    helperBuilds = 0;
    taskKills = 0;
  });

  tearDown(() {
    temporaryDirectory.deleteSync(recursive: true);
  });

  Future<BuildExecution> buildCore(String fingerprint) => cache.run(
        key: 'windows-amd64-core',
        fingerprint: () async => fingerprint,
        primaryOutput: coreOutput.path,
        notice: notice,
        build: () async {
          coreBuilds++;
          coreOutput.writeAsStringSync('core-$fingerprint');
          return [coreOutput.path];
        },
      );

  Future<BuildExecution> buildHelper({
    required String coreToken,
    required String sourceFingerprint,
    bool debug = false,
  }) =>
      cache.run(
        key: 'windows-amd64-helper-${debug ? 'debug' : 'release'}',
        fingerprint: () async => '$sourceFingerprint:$coreToken',
        primaryOutput: helperOutput.path,
        notice: notice,
        build: () async {
          if (debug) taskKills++;
          helperBuilds++;
          helperOutput.writeAsStringSync(
            'helper-$sourceFingerprint-$coreToken',
          );
          return [helperOutput.path];
        },
      );

  test('core and release helper both skip when unchanged', () async {
    await buildCore('core-a');
    await buildHelper(coreToken: 'sha-a', sourceFingerprint: 'helper-a');

    expect((await buildCore('core-a')).rebuilt, isFalse);
    expect(
      (await buildHelper(
        coreToken: 'sha-a',
        sourceFingerprint: 'helper-a',
      ))
          .rebuilt,
      isFalse,
    );
    expect(coreBuilds, 1);
    expect(helperBuilds, 1);
  });

  test('helper source change does not rebuild core', () async {
    await buildCore('core-a');
    await buildHelper(coreToken: 'sha-a', sourceFingerprint: 'helper-a');

    expect((await buildCore('core-a')).rebuilt, isFalse);
    expect(
      (await buildHelper(
        coreToken: 'sha-a',
        sourceFingerprint: 'helper-b',
      ))
          .rebuilt,
      isTrue,
    );
    expect(coreBuilds, 1);
    expect(helperBuilds, 2);
  });

  test('release core SHA change invalidates helper token', () async {
    await buildHelper(coreToken: 'sha-a', sourceFingerprint: 'helper-a');

    expect(
      (await buildHelper(
        coreToken: 'sha-b',
        sourceFingerprint: 'helper-a',
      ))
          .rebuilt,
      isTrue,
    );
    expect(helperBuilds, 2);
  });

  test('debug helper cache hit does not run taskkill', () async {
    await buildHelper(
      coreToken: '',
      sourceFingerprint: 'helper-a',
      debug: true,
    );
    expect(taskKills, 1);

    expect(
      (await buildHelper(
        coreToken: '',
        sourceFingerprint: 'helper-a',
        debug: true,
      ))
          .rebuilt,
      isFalse,
    );
    expect(taskKills, 1);
  });
}
