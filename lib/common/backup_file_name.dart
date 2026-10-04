import 'dart:convert';

enum BackupFileNameError { empty, unknownVariable, invalidName, tooLong }

abstract final class BackupFileName {
  static const variables = ['version', 'date', 'time', 'platform'];
  static final _variable = RegExp(r'\{([^{}]+)\}');
  static final _invalid = RegExp(r'[<>:"/\\|?*\x00-\x1f]');
  static final _reserved = RegExp(
    r'^(CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])(?:\.|$)',
    caseSensitive: false,
  );

  static bool hasVariables(String template) =>
      template.contains('{') || template.contains('}');

  static String ensureZipExtension(String name) =>
      name.toLowerCase().endsWith('.zip') ? name : '$name.zip';

  static String render(
    String template, {
    required String version,
    required String platform,
    required DateTime now,
  }) {
    String pad(int value) => value.toString().padLeft(2, '0');
    final values = {
      'version': version,
      'platform': platform,
      'date':
          '${now.year.toString().padLeft(4, '0')}-${pad(now.month)}-${pad(now.day)}',
      'time': '${pad(now.hour)}${pad(now.minute)}${pad(now.second)}',
    };
    final name = template.replaceAllMapped(
      _variable,
      (match) => values[match[1]] ?? match[0]!,
    );
    return ensureZipExtension(name);
  }

  static BackupFileNameError? validate(
    String template, {
    required String version,
    required String platform,
    required DateTime now,
  }) {
    if (template.trim().isEmpty) return BackupFileNameError.empty;
    final literal = template.replaceAllMapped(
      _variable,
      (match) => variables.contains(match[1]) ? '' : match[0]!,
    );
    if (hasVariables(literal)) return BackupFileNameError.unknownVariable;
    final name = render(
      template,
      version: version,
      platform: platform,
      now: now,
    );
    if (template != template.trim() ||
        template.endsWith('.') ||
        _invalid.hasMatch(name) ||
        _reserved.hasMatch(name) ||
        name == '.zip' ||
        name == '..zip') {
      return BackupFileNameError.invalidName;
    }
    if (utf8.encode(name).length > 255) return BackupFileNameError.tooLong;
    return null;
  }
}
