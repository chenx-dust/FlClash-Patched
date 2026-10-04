import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:fl_clash/common/webdav.dart';
import 'package:flutter_test/flutter_test.dart';

class _ScriptedAdapter implements HttpClientAdapter {
  _ScriptedAdapter(this._responses);

  final ResponseBody Function(RequestOptions options) _responses;
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return _responses(options);
  }

  @override
  void close({bool force = false}) {}
}

Dio _dioWith(_ScriptedAdapter adapter) => Dio()..httpClientAdapter = adapter;

void main() {
  test(
    'directory listing accepts collection URLs with trailing slashes',
    () async {
      final adapter = _ScriptedAdapter(
        (_) => ResponseBody.fromString('''
<multistatus xmlns="DAV:">
 <response><href>/dav/</href><propstat><prop><resourcetype><collection/></resourcetype></prop><status>HTTP/1.1 200 OK</status></propstat></response>
 <response><href>/dav/archives%20old/</href><propstat><prop><resourcetype><collection/></resourcetype></prop><status>HTTP/1.1 200 OK</status></propstat></response>
 <response><href>/dav/backup.zip</href><propstat><prop><resourcetype/></prop><status>HTTP/1.1 200 OK</status></propstat></response>
 <response><href>/dav/forbidden/</href><propstat><prop><resourcetype><collection/></resourcetype></prop><status>HTTP/1.1 403 Forbidden</status></propstat></response>
 <response><href>/dav/archives/nested/</href><propstat><prop><resourcetype><collection/></resourcetype></prop><status>HTTP/1.1 200 OK</status></propstat></response>
</multistatus>''', 207),
      );
      final transport = DAVTransport(
        uri: 'http://origin.example/dav',
        user: '',
        password: '',
        dio: _dioWith(adapter),
      );
      expect(
        (await transport.list(
          '/',
          directoriesOnly: true,
        )).map((directory) => directory.name),
        ['archives old'],
      );
    },
  );

  test(
    'lists immediate files, decodes names and sorts by modified time',
    () async {
      final adapter = _ScriptedAdapter((options) {
        expect(options.method, 'PROPFIND');
        expect(options.headers['depth'], '1');
        expect(options.uri.path, '/dav/FlClash/');
        return ResponseBody.fromString('''
<d:multistatus xmlns:d="DAV:">
  <d:response><d:href>/dav/FlClash/</d:href><d:propstat><d:prop><d:resourcetype><d:collection/></d:resourcetype></d:prop><d:status>HTTP/1.1 200 OK</d:status></d:propstat></d:response>
  <d:response><d:href>/dav/FlClash/old.zip</d:href><d:propstat><d:prop><d:getlastmodified>Sat, 03 Oct 2026 10:00:00 GMT</d:getlastmodified></d:prop><d:status>HTTP/1.1 200 OK</d:status></d:propstat></d:response>
  <d:response><d:href>http://origin.example/dav/FlClash/new%20backup.zip</d:href><d:propstat><d:prop><d:resourcetype/><d:getlastmodified>Sun, 04 Oct 2026 10:00:00 GMT</d:getlastmodified></d:prop><d:status>HTTP/1.1 200 OK</d:status></d:propstat></d:response>
  <d:response><d:href>/dav/FlClash/folder.zip</d:href><d:propstat><d:prop><d:resourcetype><d:collection/></d:resourcetype></d:prop><d:status>HTTP/1.1 200 OK</d:status></d:propstat></d:response>
  <d:response><d:href>/dav/FlClash/failed.zip</d:href><d:propstat><d:prop/><d:status>HTTP/1.1 403 Forbidden</d:status></d:propstat></d:response>
  <d:response><d:href>/dav/FlClash/nested/backup.zip</d:href><d:propstat><d:prop/><d:status>HTTP/1.1 200 OK</d:status></d:propstat></d:response>
  <d:response><d:href>http://other.example/dav/FlClash/foreign.zip</d:href><d:propstat><d:prop/><d:status>HTTP/1.1 200 OK</d:status></d:propstat></d:response>
  <d:response><d:href>/dav/FlClash/bad%2Fname.zip</d:href><d:propstat><d:prop/><d:status>HTTP/1.1 200 OK</d:status></d:propstat></d:response>
  <d:response><d:href>/dav/FlClash/undated.zip</d:href><d:propstat><d:prop><d:getlastmodified>invalid</d:getlastmodified></d:prop><d:status>HTTP/1.1 200 OK</d:status></d:propstat></d:response>
</d:multistatus>''', 207);
      });
      final transport = DAVTransport(
        uri: 'http://origin.example/dav',
        user: '',
        password: '',
        dio: _dioWith(adapter),
      );

      final files = await transport.list('FlClash');

      expect(files.map((file) => file.name), [
        'new backup.zip',
        'old.zip',
        'undated.zip',
      ]);
      expect(files.first.modified, DateTime.utc(2026, 10, 4, 10));
      expect(files.last.modified, isNull);
    },
  );

  test('a missing collection is an empty backup list', () async {
    final adapter = _ScriptedAdapter((_) => ResponseBody.fromString('', 404));
    final transport = DAVTransport(
      uri: 'http://origin.example',
      user: '',
      password: '',
      dio: _dioWith(adapter),
    );
    expect(await transport.list('FlClash'), isEmpty);
  });

  test(
    'listing surfaces authentication and malformed response errors',
    () async {
      for (final status in [401, 207]) {
        final adapter = _ScriptedAdapter(
          (_) => ResponseBody.fromString('not xml', status),
        );
        final transport = DAVTransport(
          uri: 'http://origin.example',
          user: '',
          password: '',
          dio: _dioWith(adapter),
        );
        await expectLater(transport.list('FlClash'), throwsA(isA<Exception>()));
      }
    },
  );

  test(
    'redirect to a different origin drops the Authorization header',
    () async {
      var call = 0;
      final adapter = _ScriptedAdapter((options) {
        call++;
        if (call == 1) {
          return ResponseBody.fromString(
            '',
            302,
            headers: {
              'location': ['http://other.example/target'],
            },
          );
        }
        return ResponseBody.fromString('', 204);
      });
      final transport = DAVTransport(
        uri: 'http://origin.example/base',
        user: 'user',
        password: 'pass',
        dio: _dioWith(adapter),
      );

      await transport.options('probe');

      expect(adapter.requests, hasLength(2));
      expect(adapter.requests[0].headers, contains('authorization'));
      expect(adapter.requests[1].uri.host, 'other.example');
      expect(adapter.requests[1].headers, isNot(contains('authorization')));
    },
  );

  test(
    'redirect within the same origin keeps the Authorization header',
    () async {
      var call = 0;
      final adapter = _ScriptedAdapter((options) {
        call++;
        if (call == 1) {
          return ResponseBody.fromString(
            '',
            302,
            headers: {
              'location': ['http://origin.example/base/moved'],
            },
          );
        }
        return ResponseBody.fromString('', 204);
      });
      final transport = DAVTransport(
        uri: 'http://origin.example/base',
        user: 'user',
        password: 'pass',
        dio: _dioWith(adapter),
      );

      await transport.options('probe');

      expect(adapter.requests, hasLength(2));
      expect(adapter.requests[1].headers, contains('authorization'));
    },
  );

  test(
    'a Digest challenge is found even behind a Basic www-authenticate line',
    () async {
      var call = 0;
      final adapter = _ScriptedAdapter((options) {
        call++;
        if (call == 1) {
          return ResponseBody.fromString(
            '',
            401,
            headers: {
              'www-authenticate': [
                'Basic realm="x"',
                'Digest realm="y", nonce="abc123", qop="auth", opaque="op1"',
              ],
            },
          );
        }
        return ResponseBody.fromString('', 204);
      });
      final transport = DAVTransport(
        uri: 'http://origin.example/base',
        user: 'user',
        password: 'pass',
        dio: _dioWith(adapter),
      );

      await transport.options('probe');

      expect(adapter.requests, hasLength(2));
      final retryAuth = adapter.requests[1].headers['authorization'] as String;
      expect(retryAuth, startsWith('Digest '));
      expect(retryAuth, contains('realm="y"'));
    },
  );
}
