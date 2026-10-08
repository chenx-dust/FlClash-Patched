import 'dart:io';

import 'package:package_info_plus/package_info_plus.dart';

import 'common.dart';

extension PackageInfoExtension on PackageInfo {
  String get ua => [
    '$appName/v$version',
    'clash-verge',
    'Platform/${Platform.operatingSystem}',
  ].join(' ');
}

/// SemVer order for `[v]major.minor.patch[-pre][+build]`, except a numeric
/// build number breaks ties: every build of one version shares its name.
int compareVersions(String version1, String version2) {
  final a = _ParsedVersion.parse(version1);
  final b = _ParsedVersion.parse(version2);
  for (var i = 0; i < 3; i++) {
    final result = a.core[i].compareTo(b.core[i]);
    if (result != 0) return result;
  }
  final prerelease = _comparePrerelease(a.prerelease, b.prerelease);
  if (prerelease != 0) return prerelease;
  return a.build.compareTo(b.build);
}

class _ParsedVersion {
  final List<int> core;
  final List<String> prerelease;
  final int build;

  const _ParsedVersion(this.core, this.prerelease, this.build);

  static final _pattern = RegExp(
    r'^[vV]?(\d+(?:\.\d+){0,2})(?:-([0-9A-Za-z.-]+))?(?:\+([0-9A-Za-z.-]+))?$',
  );

  factory _ParsedVersion.parse(String version) {
    final match = _pattern.firstMatch(version.trim());
    if (match == null) {
      throw FormatException('Invalid version', version);
    }
    final core = match[1]!.split('.').map(int.parse).toList();
    while (core.length < 3) {
      core.add(0);
    }
    return _ParsedVersion(
      core,
      match[2]?.split('.') ?? const [],
      int.tryParse(match[3] ?? '') ?? 0,
    );
  }
}

int _comparePrerelease(List<String> a, List<String> b) {
  if (a.isEmpty || b.isEmpty) {
    return b.length.sign - a.length.sign;
  }
  for (var i = 0; i < a.length && i < b.length; i++) {
    final numA = int.tryParse(a[i]);
    final numB = int.tryParse(b[i]);
    final result = switch ((numA, numB)) {
      (final int x, final int y) => x.compareTo(y),
      (int(), null) => -1,
      (null, int()) => 1,
      _ => a[i].compareTo(b[i]),
    };
    if (result != 0) return result;
  }
  return a.length.compareTo(b.length);
}

const releaseNotesBeginMarker = '<!-- flclash:changelog:begin -->';
const releaseNotesEndMarker = '<!-- flclash:changelog:end -->';

List<String> parseReleaseBody(String? body) {
  if (body == null) return [];
  final regex = RegExp(r'^[ \t]*-[ \t]+(.*)$', multiLine: true);
  return regex
      .allMatches(scopeReleaseNotes(body))
      .map((match) => match.group(1)?.trim() ?? '')
      .where((item) => item.isNotEmpty)
      .toList();
}

String scopeReleaseNotes(String body) {
  final begin = body.indexOf(releaseNotesBeginMarker);
  if (begin < 0) return body;
  final start = begin + releaseNotesBeginMarker.length;
  final end = body.indexOf(releaseNotesEndMarker, start);
  return end < 0 ? body.substring(start) : body.substring(start, end);
}
