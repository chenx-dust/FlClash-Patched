import 'dart:convert';
import 'dart:math';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:fl_clash/common/string.dart';
import 'package:xml/xml.dart';

class DAVFile {
  final String name;
  final DateTime? modified;

  const DAVFile({required this.name, this.modified});
}

final class DAVException implements Exception {
  final String method;
  final String path;
  final int? statusCode;
  final String? reasonPhrase;

  const DAVException({
    required this.method,
    required this.path,
    this.statusCode,
    this.reasonPhrase,
  });

  @override
  String toString() {
    final reason = reasonPhrase?.trim();
    final detail = [
      if (statusCode != null) '$statusCode',
      if (reason != null && reason.isNotEmpty) reason,
    ].join(' ');
    return 'WebDAV $method $path failed: ${detail.isEmpty ? 'no response' : detail}';
  }
}

/// Requests go through `Dio`, so they inherit the app-wide HttpOverrides: the
/// user's proxy selection and the TLS certificate setting apply here too.
class DAVTransport {
  DAVTransport({
    required String uri,
    required this.user,
    required this.password,
    Dio? dio,
  }) : _base = Uri.parse(uri.trim()),
       _dio = dio ?? Dio() {
    _dio.options
      ..connectTimeout = const Duration(seconds: 8)
      ..sendTimeout = const Duration(seconds: 60)
      ..receiveTimeout = const Duration(seconds: 60);
  }

  static const _maxRedirects = 5;

  final String user;
  final String password;
  final Uri _base;
  final Dio _dio;

  _DigestChallenge? _digest;
  int _digestNonceCount = 0;

  Uri resolve(String path, {bool collection = false}) {
    final segments = [
      ..._base.pathSegments.where((segment) => segment.isNotEmpty),
      ...path.split('/').where((segment) => segment.isNotEmpty),
    ];
    return Uri(
      scheme: _base.scheme,
      host: _base.host,
      port: _base.hasPort ? _base.port : null,
      pathSegments: collection ? [...segments, ''] : segments,
    );
  }

  Future<void> options(String path) async {
    await _send('OPTIONS', path, collection: true, accept: const {200, 204});
  }

  /// 405 means the collection is already there, which is the common case: the
  /// backup directory only has to be created once per account.
  Future<void> mkcol(String path) async {
    await _send(
      'MKCOL',
      path,
      collection: true,
      accept: const {200, 201, 204, 405},
    );
  }

  Future<void> put(String path, List<int> bytes) async {
    await _send(
      'PUT',
      path,
      body: bytes,
      headers: {
        Headers.contentTypeHeader: 'application/octet-stream',
        Headers.contentLengthHeader: bytes.length,
      },
      accept: const {200, 201, 204},
    );
  }

  Future<Uint8List> get(String path) async {
    final response = await _send(
      'GET',
      path,
      responseType: ResponseType.bytes,
      accept: const {200},
    );
    final data = response.data;
    return data is List<int> ? Uint8List.fromList(data) : Uint8List(0);
  }

  Future<void> delete(String path) async {
    await _send('DELETE', path, accept: const {200, 202, 204, 404});
  }

  Future<List<DAVFile>> list(
    String path, {
    bool directoriesOnly = false,
  }) async {
    const body =
        '<d:propfind xmlns:d="DAV:"><d:prop>'
        '<d:resourcetype/><d:getlastmodified/>'
        '</d:prop></d:propfind>';
    final response = await _send(
      'PROPFIND',
      path,
      collection: true,
      body: utf8.encode(body),
      headers: const {
        'depth': '1',
        Headers.contentTypeHeader: 'application/xml',
      },
      accept: const {207, 404},
    );
    if (response.statusCode == 404) return [];
    final collection = resolve(path, collection: true);
    final parent = collection.pathSegments
        .where((part) => part.isNotEmpty)
        .toList();
    final files = <String, DAVFile>{};
    final document = XmlDocument.parse(response.data as String);
    for (final entry in document.findAllElements(
      'response',
      namespaceUri: 'DAV:',
    )) {
      final href = entry.getElement('href', namespaceUri: 'DAV:')?.innerText;
      if (href == null) continue;
      final uri = collection.resolve(href);
      final segments = uri.pathSegments.toList();
      if (segments.isNotEmpty && segments.last.isEmpty) segments.removeLast();
      if (!_sameOrigin(uri, collection) ||
          segments.length != parent.length + 1 ||
          parent.indexed.any((entry) => segments[entry.$1] != entry.$2)) {
        continue;
      }
      final name = segments.last;
      if (name.isEmpty ||
          name == '.' ||
          name == '..' ||
          name.contains('/') ||
          name.contains('\\')) {
        continue;
      }
      DateTime? modified;
      var isFile = false;
      var isCollection = false;
      for (final propstat in entry.findElements(
        'propstat',
        namespaceUri: 'DAV:',
      )) {
        final status = propstat
            .getElement('status', namespaceUri: 'DAV:')
            ?.innerText;
        if (status == null ||
            !RegExp(r'^HTTP/\S+ 2\d\d(?:\s|$)').hasMatch(status.trim())) {
          continue;
        }
        final prop = propstat.getElement('prop', namespaceUri: 'DAV:');
        if (prop == null) continue;
        isFile = true;
        isCollection |=
            prop
                .getElement('resourcetype', namespaceUri: 'DAV:')
                ?.getElement('collection', namespaceUri: 'DAV:') !=
            null;
        final rawDate = prop
            .getElement('getlastmodified', namespaceUri: 'DAV:')
            ?.innerText;
        if (rawDate != null) {
          try {
            modified = HttpDate.parse(rawDate);
          } on HttpException {
            modified = DateTime.tryParse(rawDate);
          }
        }
      }
      if (isFile && isCollection == directoriesOnly) {
        files[name] = DAVFile(name: name, modified: modified);
      }
    }
    return files.values.toList()..sort((a, b) {
      if (directoriesOnly) return a.name.compareTo(b.name);
      final dateOrder = (b.modified ?? DateTime.fromMillisecondsSinceEpoch(0))
          .compareTo(a.modified ?? DateTime.fromMillisecondsSinceEpoch(0));
      return dateOrder != 0 ? dateOrder : a.name.compareTo(b.name);
    });
  }

  Future<Response<dynamic>> _send(
    String method,
    String path, {
    bool collection = false,
    List<int>? body,
    Map<String, dynamic> headers = const {},
    ResponseType responseType = ResponseType.plain,
    required Set<int> accept,
  }) async {
    final origin = resolve(path, collection: collection);
    var uri = origin;
    var retriedAuth = false;
    for (var redirects = 0; ; redirects++) {
      final response = await _request(
        method,
        uri,
        origin: origin,
        body: body,
        headers: headers,
        responseType: responseType,
      );
      final status = response.statusCode;
      if (status != null && accept.contains(status)) {
        return response;
      }
      if (status == 401 && !retriedAuth && _adoptChallenge(response)) {
        retriedAuth = true;
        continue;
      }
      final location = _redirectTarget(response);
      if (location != null && redirects < _maxRedirects) {
        uri = uri.resolveUri(location);
        continue;
      }
      throw DAVException(
        method: method,
        path: path,
        statusCode: status,
        reasonPhrase: response.statusMessage,
      );
    }
  }

  Future<Response<dynamic>> _request(
    String method,
    Uri uri, {
    required Uri origin,
    List<int>? body,
    required Map<String, dynamic> headers,
    required ResponseType responseType,
  }) {
    return _dio.requestUri<dynamic>(
      uri,
      data: body,
      options: Options(
        method: method,
        headers: {...headers, ..._authorization(method, uri, origin)},
        responseType: responseType,
        // Redirects are followed by hand so that a PUT stays a PUT, and every
        // status reaches the caller instead of becoming a DioException.
        followRedirects: false,
        maxRedirects: 0,
        validateStatus: (_) => true,
      ),
    );
  }

  Uri? _redirectTarget(Response<dynamic> response) {
    const redirects = {301, 302, 303, 307, 308};
    if (!redirects.contains(response.statusCode)) {
      return null;
    }
    final location = response.headers.value('location');
    if (location == null || location.isEmpty) {
      return null;
    }
    return Uri.tryParse(location);
  }

  bool _adoptChallenge(Response<dynamic> response) {
    // Basic and Digest may each arrive as their own www-authenticate line.
    final headerValues = response.headers[Headers.wwwAuthenticateHeader];
    if (headerValues == null) {
      return false;
    }
    for (final header in headerValues) {
      final challenge = _DigestChallenge.parse(header);
      if (challenge != null) {
        _digest = challenge;
        _digestNonceCount = 0;
        return true;
      }
    }
    return false;
  }

  static bool _sameOrigin(Uri a, Uri b) {
    return a.scheme == b.scheme && a.host == b.host && _port(a) == _port(b);
  }

  static int _port(Uri uri) {
    if (uri.hasPort) return uri.port;
    return uri.scheme == 'https' ? 443 : 80;
  }

  Map<String, dynamic> _authorization(String method, Uri uri, Uri origin) {
    // Never forward credentials to a redirect target on another origin.
    if (!_sameOrigin(uri, origin)) {
      return const {};
    }
    if (user.isEmpty && password.isEmpty) {
      return const {};
    }
    final digest = _digest;
    if (digest == null) {
      final credentials = base64.encode(utf8.encode('$user:$password'));
      return {'authorization': 'Basic $credentials'};
    }
    return {
      'authorization': digest.authorize(
        user: user,
        password: password,
        method: method,
        uri: uri,
        nonceCount: ++_digestNonceCount,
      ),
    };
  }
}

class _DigestChallenge {
  const _DigestChallenge({
    required this.realm,
    required this.nonce,
    this.qop,
    this.opaque,
    this.algorithm,
  });

  final String realm;
  final String nonce;
  final String? qop;
  final String? opaque;
  final String? algorithm;

  static _DigestChallenge? parse(String? header) {
    if (header == null) return null;
    final start = header.toLowerCase().indexOf('digest');
    if (start == -1) return null;
    final values = <String, String>{};
    final pattern = RegExp(r'(\w+)\s*=\s*(?:"([^"]*)"|([^\s,]+))');
    for (final match in pattern.allMatches(header.substring(start + 6))) {
      values[match.group(1)!.toLowerCase()] = match.group(2) ?? match.group(3)!;
    }
    final nonce = values['nonce'];
    if (nonce == null) return null;
    final algorithm = values['algorithm'];
    // Only MD5 is implemented; anything else would produce a wrong response
    // hash, and Basic at least has a chance of being accepted.
    if (algorithm != null && algorithm.toUpperCase() != 'MD5') {
      return null;
    }
    return _DigestChallenge(
      realm: values['realm'] ?? '',
      nonce: nonce,
      qop: _pickQop(values['qop']),
      opaque: values['opaque'],
      algorithm: algorithm,
    );
  }

  static String? _pickQop(String? raw) {
    if (raw == null) return null;
    final options = raw.split(',').map((item) => item.trim().toLowerCase());
    return options.contains('auth') ? 'auth' : null;
  }

  String authorize({
    required String user,
    required String password,
    required String method,
    required Uri uri,
    required int nonceCount,
  }) {
    final path = uri.hasQuery ? '${uri.path}?${uri.query}' : uri.path;
    final ha1 = '$user:$realm:$password'.toMd5();
    final ha2 = '$method:$path'.toMd5();
    final count = nonceCount.toRadixString(16).padLeft(8, '0');
    final cnonce = _cnonce();
    final response = qop == null
        ? '$ha1:$nonce:$ha2'.toMd5()
        : '$ha1:$nonce:$count:$cnonce:$qop:$ha2'.toMd5();
    final parts = [
      'username="$user"',
      'realm="$realm"',
      'nonce="$nonce"',
      'uri="$path"',
      'response="$response"',
      if (algorithm != null) 'algorithm=$algorithm',
      if (opaque != null) 'opaque="$opaque"',
      if (qop != null) 'qop=$qop',
      if (qop != null) 'nc=$count',
      if (qop != null) 'cnonce="$cnonce"',
    ];
    return 'Digest ${parts.join(', ')}';
  }

  static String _cnonce() {
    final random = Random.secure();
    final bytes = List<int>.generate(8, (_) => random.nextInt(256));
    return bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
  }
}
