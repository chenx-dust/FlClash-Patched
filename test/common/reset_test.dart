import 'dart:io';

import 'package:fl_clash/common/reset.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('clears data directory contents without deleting its root', () async {
    final root = await Directory.systemTemp.createTemp('flclash-reset-');
    addTearDown(() => root.delete(recursive: true));
    final profiles = Directory('${root.path}${Platform.pathSeparator}profiles');
    final scripts = Directory('${root.path}${Platform.pathSeparator}scripts');
    await profiles.create(recursive: true);
    await scripts.create(recursive: true);
    await File(
      '${profiles.path}${Platform.pathSeparator}1.yaml',
    ).writeAsString('profile');
    await File(
      '${scripts.path}${Platform.pathSeparator}1.js',
    ).writeAsString('script');

    await clearDirectoryContents(root);

    expect(await root.exists(), isTrue);
    expect(await root.list().toList(), isEmpty);
  });
}
