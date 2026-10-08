import 'package:dio/dio.dart';
import 'package:fl_clash/common/exception.dart';
import 'package:fl_clash/common/request.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/state.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await AppLocalizations.load(const Locale('en'));
  });

  test('getTextResponseForUrl propagates the typed DioException', () async {
    // flutter_test's mocked HttpClient answers every request with HTTP 400,
    // which Dio surfaces as a badResponse DioException.
    await expectLater(
      request.getTextResponseForUrl('http://127.0.0.1/anything'),
      throwsA(
        isA<DioException>().having(
          (e) => e.type,
          'type',
          DioExceptionType.badResponse,
        ),
      ),
    );
  });

  test('getFileResponseForUrl propagates the typed DioException', () async {
    await expectLater(
      request.getFileResponseForUrl('http://127.0.0.1/anything'),
      throwsA(
        isA<DioException>().having(
          (e) => e.type,
          'type',
          DioExceptionType.badResponse,
        ),
      ),
    );
  });

  test('checkForUpdate includes HTTP status and response body', () async {
    final interceptor = InterceptorsWrapper(
      onRequest: (options, handler) {
        handler.reject(
          DioException(
            requestOptions: options,
            response: Response<String>(
              requestOptions: options,
              statusCode: 403,
              data: 'rate limited',
            ),
            type: DioExceptionType.badResponse,
          ),
        );
      },
    );
    request.clashDio.interceptors.add(interceptor);
    addTearDown(() {
      request.clashDio.interceptors.remove(interceptor);
    });

    await expectLater(
      request.checkForUpdate(),
      throwsA(
        isA<MessageException>()
            .having((e) => e.message, 'message', contains('[403]'))
            .having((e) => e.message, 'message', contains('rate limited')),
      ),
    );
  });

  group('checkForUpdate reads the release manifest', () {
    final urls = <String>[];

    void serve(String tag) {
      final interceptor = InterceptorsWrapper(
        onRequest: (options, handler) {
          urls.add(options.uri.toString());
          handler.resolve(
            Response<String>(
              requestOptions: options,
              statusCode: 200,
              data: '{"tag":"$tag","notes":"","assets":[]}',
            ),
          );
        },
      );
      request.clashDio.interceptors.add(interceptor);
      addTearDown(() => request.clashDio.interceptors.remove(interceptor));
    }

    setUp(urls.clear);

    setUpAll(() {
      globalState.packageInfo = PackageInfo(
        appName: 'FlClash',
        packageName: 'cc.chenx.flclash',
        version: '0.9.3',
        buildNumber: '1',
      );
    });

    test('from a release download, not the API', () async {
      serve('v0.9.4');

      final release = await request.checkForUpdate();

      expect(release?.tag, 'v0.9.4');
      expect(urls, [
        'https://github.com/chenx-dust/FlClash-Patched/releases/latest/download/version.json',
      ]);
    });

    test('and ignores a release that is not newer', () async {
      serve('v0.9.3');

      expect(await request.checkForUpdate(), isNull);
    });

    test('falls back to the API for a release without a manifest', () async {
      final interceptor = InterceptorsWrapper(
        onRequest: (options, handler) {
          urls.add(options.uri.toString());
          if (options.uri.host != 'api.github.com') {
            handler.reject(
              DioException(
                requestOptions: options,
                response: Response<String>(
                  requestOptions: options,
                  statusCode: 404,
                ),
                type: DioExceptionType.badResponse,
              ),
            );
            return;
          }
          handler.resolve(
            Response<Object?>(
              requestOptions: options,
              statusCode: 200,
              data: {'tag_name': 'v0.9.4', 'body': '- notes', 'assets': []},
            ),
          );
        },
      );
      request.clashDio.interceptors.add(interceptor);
      addTearDown(() => request.clashDio.interceptors.remove(interceptor));

      final release = await request.checkForUpdate();

      expect(release?.tag, 'v0.9.4');
      expect(release?.notes, '- notes');
      expect(urls.last, startsWith('https://api.github.com/'));
    });

    test('reports an unreadable manifest as a request failure', () async {
      final interceptor = InterceptorsWrapper(
        onRequest: (options, handler) {
          handler.resolve(
            Response<Object?>(
              requestOptions: options,
              statusCode: 200,
              data: options.uri.host == 'api.github.com' ? 'nope' : '{}',
            ),
          );
        },
      );
      request.clashDio.interceptors.add(interceptor);
      addTearDown(() => request.clashDio.interceptors.remove(interceptor));

      await expectLater(
        request.checkForUpdate(),
        throwsA(isA<MessageException>()),
      );
    });
  });
}
