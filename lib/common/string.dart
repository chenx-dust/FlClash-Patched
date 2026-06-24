import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:fl_clash/common/common.dart';

class SearchMatcher {
  final String query;
  final bool useRegex;
  final String _lowQuery;
  final RegExp? _regExp;

  SearchMatcher(this.query, {this.useRegex = false})
    : _lowQuery = query.toLowerCase(),
      _regExp = useRegex ? _tryBuildRegExp(query) : null;

  static bool isValidRegex(String query) {
    return _tryBuildRegExp(query) != null;
  }

  static RegExp? _tryBuildRegExp(String query) {
    try {
      return RegExp(query, caseSensitive: false);
    } on FormatException {
      return null;
    }
  }

  bool hasMatch(String value) {
    if (query.isEmpty) {
      return true;
    }
    if (!useRegex) {
      return value.toLowerCase().contains(_lowQuery);
    }
    return _regExp?.hasMatch(value) ?? false;
  }

  bool hasAnyMatch(Iterable<String> values) {
    return values.any(hasMatch);
  }
}

extension StringExtension on String {
  bool get isUrl {
    final uri = Uri.tryParse(this);
    return uri != null &&
        (uri.scheme == 'http' ||
            uri.scheme == 'https' ||
            uri.scheme == 'ftp') &&
        uri.host.isNotEmpty;
  }

  dynamic get splitByMultipleSeparators {
    final parts = split(
      RegExp(r'[, ;]+'),
    ).where((part) => part.isNotEmpty).toList();

    return parts.length > 1 ? parts : this;
  }

  int compareToLower(String other) {
    return toLowerCase().compareTo(other.toLowerCase());
  }

  String safeSubstring(int start, [int? end]) {
    if (isEmpty) return '';
    final safeStart = start.clamp(0, length);
    if (end == null) {
      return substring(safeStart);
    }
    final safeEnd = end.clamp(safeStart, length);
    return substring(safeStart, safeEnd);
  }

  List<int> get encodeUtf16LeWithBom {
    final byteData = ByteData(length * 2);
    final bom = [0xFF, 0xFE];
    for (int i = 0; i < length; i++) {
      final int charCode = codeUnitAt(i);
      byteData.setUint16(i * 2, charCode, Endian.little);
    }
    return bom + byteData.buffer.asUint8List();
  }

  Uint8List? get getBase64 {
    final regExp = RegExp(r'base64,(.*)');
    final match = regExp.firstMatch(this);
    final realValue = match?.group(1) ?? '';
    if (realValue.isEmpty) {
      return null;
    }
    try {
      return base64.decode(realValue);
    } catch (e) {
      return null;
    }
  }

  bool get isSvg {
    return endsWith('.svg');
  }

  bool get isRegex {
    try {
      RegExp(this);
      return true;
    } catch (e) {
      commonPrint.log(e.toString());
      return false;
    }
  }

  bool matchesQuery(String query, {bool useRegex = false}) {
    return SearchMatcher(query, useRegex: useRegex).hasMatch(this);
  }

  String toMd5() {
    final bytes = utf8.encode(this);
    return md5.convert(bytes).toString();
  }

  // bool containsToLower(String target) {
  //   return toLowerCase().contains(target);
  // }

  Future<T> commonToJSON<T>() async {
    const thresholdLimit = 51200;
    if (length < thresholdLimit) {
      return json.decode(this);
    } else {
      return decodeJSONTask<T>(this);
    }
  }

  String? get value {
    if (isEmpty) {
      return null;
    }
    return this;
  }
}

extension SearchableStringsExt on Iterable<String> {
  bool matchesQuery(String query, {bool useRegex = false}) {
    return SearchMatcher(query, useRegex: useRegex).hasAnyMatch(this);
  }
}

extension StringNullExt on String? {
  String takeFirstValid(List<String?> others, {String defaultValue = ''}) {
    if (this != null && this!.trim().isNotEmpty) return this!.trim();

    for (final s in others) {
      if (s != null && s.trim().isNotEmpty) {
        return s.trim();
      }
    }
    return defaultValue;
  }
}
