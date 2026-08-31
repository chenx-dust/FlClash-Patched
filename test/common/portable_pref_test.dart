import 'dart:convert';
import 'dart:io';

import 'package:fl_clash/common/portable_pref.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/types.dart';

void main() {
  late Directory directory;
  late File preferencesFile;
  late PortableSharedPreferencesStore store;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('flclash-preferences-');
    preferencesFile = File(
      '${directory.path}${Platform.pathSeparator}shared_preferences.json',
    );
    store = PortableSharedPreferencesStore(preferencesFile);
  });

  tearDown(() async {
    await directory.delete(recursive: true);
  });

  test('persists values in the portable preferences file', () async {
    expect(await store.setValue('String', 'flutter.locale', 'zh_CN'), isTrue);
    expect(await store.setValue('Bool', 'flutter.tun', true), isTrue);

    final stored = json.decode(await preferencesFile.readAsString());
    expect(stored, <String, Object>{
      'flutter.locale': 'zh_CN',
      'flutter.tun': true,
    });
    expect(
      await PortableSharedPreferencesStore(preferencesFile).getAll(),
      <String, Object>{'flutter.locale': 'zh_CN', 'flutter.tun': true},
    );
  });

  test('serializes concurrent writes without dropping values', () async {
    await Future.wait(
      List.generate(
        20,
        (index) => store.setValue('Int', 'flutter.value$index', index),
      ),
    );

    final values = await store.getAll();
    expect(values, hasLength(20));
    for (var index = 0; index < 20; index++) {
      expect(values['flutter.value$index'], index);
    }
  });

  test('filters reads and clears only matching keys', () async {
    await store.setValue('String', 'flutter.first', 'first');
    await store.setValue('String', 'flutter.second', 'second');
    await store.setValue('String', 'other.value', 'other');

    expect(
      await store.getAllWithParameters(
        GetAllParameters(
          filter: PreferencesFilter(
            prefix: 'flutter.',
            allowList: <String>{'flutter.second'},
          ),
        ),
      ),
      <String, Object>{'flutter.second': 'second'},
    );

    await store.clearWithParameters(
      ClearParameters(
        filter: PreferencesFilter(
          prefix: 'flutter.',
          allowList: <String>{'flutter.first'},
        ),
      ),
    );

    expect(json.decode(await preferencesFile.readAsString()), <String, Object>{
      'flutter.second': 'second',
      'other.value': 'other',
    });
  });

  test('reports malformed preferences during initial load', () async {
    await preferencesFile.writeAsString('[]');

    await expectLater(store.getAll(), throwsFormatException);
  });
}
