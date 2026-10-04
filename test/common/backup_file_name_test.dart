import 'package:fl_clash/common/backup_file_name.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 10, 4, 15, 30, 25);

  String render(String template) => BackupFileName.render(
    template,
    version: '0.8.92',
    platform: 'android',
    now: now,
  );

  BackupFileNameError? validate(String template) => BackupFileName.validate(
    template,
    version: '0.8.92',
    platform: 'android',
    now: now,
  );

  test('expands all variables from one timestamp', () {
    expect(
      render('FlClash_{version}_{platform}_{date}_{time}.zip'),
      'FlClash_0.8.92_android_2026-10-04_153025.zip',
    );
    expect(render('{date}_{time}_{time}'), '2026-10-04_153025_153025.zip');
  });

  test('preserves fixed names and adds a missing zip extension once', () {
    expect(render('backup.zip'), 'backup.zip');
    expect(render('backup.ZIP'), 'backup.ZIP');
    expect(render('backup'), 'backup.zip');
    expect(validate('backup.zip'), isNull);
  });

  test('rejects unknown and unmatched variables', () {
    for (final template in [
      '{arch}',
      '{DATE}',
      '{date',
      'date}',
      '{{date}}',
      '{}',
    ]) {
      expect(validate(template), BackupFileNameError.unknownVariable);
    }
  });

  test('rejects empty names, paths, reserved names and special characters', () {
    expect(validate(''), BackupFileNameError.empty);
    expect(validate('  '), BackupFileNameError.empty);
    for (final template in [
      '../backup',
      r'folder\backup',
      'backup:time',
      'backup?',
      'backup\n',
      ' backup',
      'backup ',
      'backup.',
      '.zip',
      '..zip',
      'CON.zip',
      'lpt1',
    ]) {
      expect(
        validate(template),
        BackupFileNameError.invalidName,
        reason: template,
      );
    }
  });

  test('checks expanded UTF-8 length including the zip extension', () {
    expect(validate('${'a' * 251}.zip'), isNull);
    expect(validate('a' * 252), BackupFileNameError.tooLong);
    expect(validate('备' * 84), BackupFileNameError.tooLong);
    expect(validate('${'a' * 241}_{date}'), BackupFileNameError.tooLong);
  });
}
