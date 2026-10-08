import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:fl_clash/common/request.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart' show Locale;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:test/test.dart';

final _payload = Uint8List.fromList(List.generate(1000, (i) => i % 251));

/// Serves [_payload], honouring `Range` unless [ignoreRange]; the first
/// [interruptions] responses are cut off after [cutAfter] bytes.
class _FlakyServer {
  final HttpServer _server;
  final ranges = <String?>[];
  int interruptions;
  final int cutAfter;
  final bool ignoreRange;

  _FlakyServer._(
    this._server, {
    required this.interruptions,
    required this.cutAfter,
    required this.ignoreRange,
  }) {
    _server.listen(_handle);
  }

  static Future<_FlakyServer> start({
    int interruptions = 0,
    int cutAfter = 400,
    bool ignoreRange = false,
  }) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    return _FlakyServer._(
      server,
      interruptions: interruptions,
      cutAfter: cutAfter,
      ignoreRange: ignoreRange,
    );
  }

  String get url => 'http://127.0.0.1:${_server.port}/FlClash.apk';

  Future<void> _handle(HttpRequest request) async {
    final range = request.headers.value(HttpHeaders.rangeHeader);
    ranges.add(range);
    final response = request.response;
    var start = 0;
    final match = RegExp(r'^bytes=(\d+)-$').firstMatch(range ?? '');
    if (match != null && !ignoreRange) {
      start = int.parse(match[1]!);
      if (start >= _payload.length) {
        response.statusCode = HttpStatus.requestedRangeNotSatisfiable;
        response.headers.set(
          HttpHeaders.contentRangeHeader,
          'bytes */${_payload.length}',
        );
        await response.close();
        return;
      }
      response.statusCode = HttpStatus.partialContent;
      response.headers.set(
        HttpHeaders.contentRangeHeader,
        'bytes $start-${_payload.length - 1}/${_payload.length}',
      );
    }
    final body = _payload.sublist(start);
    response.contentLength = body.length;
    if (interruptions > 0) {
      interruptions--;
      final socket = await response.detachSocket();
      socket.add(body.sublist(0, cutAfter.clamp(0, body.length)));
      await socket.flush();
      socket.destroy();
      return;
    }
    response.add(body);
    await response.close();
  }

  Future<void> close() => _server.close(force: true);
}

void main() {
  late Directory dir;
  late String savePath;

  setUpAll(() async {
    await AppLocalizations.load(const Locale('en'));
    final container = ProviderContainer();
    addTearDown(container.dispose);
    globalState.container = container;
    globalState.packageInfo = PackageInfo(
      appName: 'FlClash',
      packageName: 'cc.chenx.flclash',
      version: '0.9.3',
      buildNumber: '1',
    );
  });

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('flclash_download');
    savePath = '${dir.path}/FlClash.apk';
  });

  tearDown(() => dir.delete(recursive: true));

  Future<void> download(
    String url, {
    int retries = 3,
    List<int>? progress,
    CancelToken? cancelToken,
  }) {
    return request.downloadFile(
      url,
      savePath,
      retries: retries,
      retryDelay: (_) => Duration.zero,
      cancelToken: cancelToken,
      onReceiveProgress: (received, _) => progress?.add(received),
    );
  }

  test('resumes an interrupted transfer from where it stopped', () async {
    final server = await _FlakyServer.start(interruptions: 1);
    addTearDown(server.close);
    final progress = <int>[];

    await download(server.url, progress: progress);

    expect(await File(savePath).readAsBytes(), _payload);
    expect(server.ranges, [null, 'bytes=400-']);
    expect(progress.last, _payload.length);
    expect(File('$savePath.part').existsSync(), isFalse);
  });

  test('keeps the partial file so a later call continues it', () async {
    final server = await _FlakyServer.start(interruptions: 2);
    addTearDown(server.close);

    await expectLater(download(server.url, retries: 1), throwsException);
    expect(await File('$savePath.part').length(), 800);
    expect(File(savePath).existsSync(), isFalse);

    await download(server.url);

    expect(await File(savePath).readAsBytes(), _payload);
    expect(server.ranges.last, 'bytes=800-');
  });

  test('restarts when the server ignores the range', () async {
    final server = await _FlakyServer.start(ignoreRange: true);
    addTearDown(server.close);
    await File('$savePath.part').writeAsBytes(List.filled(300, 7));

    await download(server.url);

    expect(await File(savePath).readAsBytes(), _payload);
    expect(server.ranges, ['bytes=300-']);
  });

  test('treats an unsatisfiable range as an already complete file', () async {
    final server = await _FlakyServer.start();
    addTearDown(server.close);
    await File('$savePath.part').writeAsBytes(_payload);

    await download(server.url);

    expect(await File(savePath).readAsBytes(), _payload);
    expect(server.ranges, ['bytes=1000-']);
  });

  test('restarts when the partial file is longer than the download', () async {
    final server = await _FlakyServer.start();
    addTearDown(server.close);
    await File('$savePath.part').writeAsBytes(List.filled(1200, 7));

    await download(server.url);

    expect(await File(savePath).readAsBytes(), _payload);
    expect(server.ranges, ['bytes=1200-', null]);
  });

  test('cancelling keeps the partial file and skips the retries', () async {
    final server = await _FlakyServer.start(interruptions: 1);
    addTearDown(server.close);
    final cancelToken = CancelToken();

    final operation = request.downloadFile(
      server.url,
      savePath,
      retryDelay: (_) => const Duration(hours: 1),
      cancelToken: cancelToken,
    );
    await Future<void>.delayed(const Duration(milliseconds: 200));
    cancelToken.cancel();

    await expectLater(
      operation,
      throwsA(
        isA<DioException>().having(
          (e) => e.type,
          'type',
          DioExceptionType.cancel,
        ),
      ),
    );
    expect(await File('$savePath.part').length(), 400);
    expect(server.ranges, [null]);
  });

  test('a client error is not retried', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    var requests = 0;
    server.listen((request) {
      requests++;
      request.response
        ..statusCode = HttpStatus.notFound
        ..close();
    });

    await expectLater(
      download('http://127.0.0.1:${server.port}/missing'),
      throwsException,
    );
    expect(requests, 1);
  });
}
