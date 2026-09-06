import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:fl_clash/common/app_localizations.dart';
import 'package:fl_clash/core/desktop/helper_client.dart';
import 'package:fl_clash/core/desktop/launch_policy.dart';
import 'package:fl_clash/core/desktop/model.dart';
import 'package:fl_clash/core/method.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppLocalizations appLocalizations;

  setUpAll(() async {
    appLocalizations = await AppLocalizations.load(const Locale('en'));
  });

  test('maps badResponse DioException to the network exception message', () {
    final message = networkErrorMessage(
      DioException(
        requestOptions: RequestOptions(path: '/'),
        type: DioExceptionType.badResponse,
      ),
      appLocalizations,
    );
    expect(message, appLocalizations.networkException);
  });

  test(
    'maps other DioException types to the unknown network error message',
    () {
      final message = networkErrorMessage(
        DioException(
          requestOptions: RequestOptions(path: '/'),
          type: DioExceptionType.connectionError,
        ),
        appLocalizations,
      );
      expect(message, appLocalizations.unknownNetworkError);
    },
  );

  test('returns null for non-Dio exceptions', () {
    expect(networkErrorMessage(StateError('boom'), appLocalizations), isNull);
  });

  test('shows HTTP status and subscription response bodies', () {
    for (final body in <Object>[
      '订阅已过期',
      Uint8List.fromList(utf8.encode('订阅已过期')),
      {'message': '订阅已过期'},
    ]) {
      final options = RequestOptions(path: '/subscription');
      final message = userFacingErrorMessage(
        DioException(
          requestOptions: options,
          type: DioExceptionType.badResponse,
          response: Response<Object>(
            requestOptions: options,
            statusCode: 403,
            data: body,
          ),
        ),
        appLocalizations,
      );
      expect(message, contains('[403]'));
      expect(message, contains('订阅已过期'));
    }
  });

  test('keeps HTTP status when response bytes are not UTF-8', () {
    final options = RequestOptions(path: '/subscription');
    expect(
      userFacingErrorMessage(
        DioException(
          requestOptions: options,
          type: DioExceptionType.badResponse,
          response: Response<Uint8List>(
            requestOptions: options,
            statusCode: 502,
            data: Uint8List.fromList([255]),
          ),
        ),
        appLocalizations,
      ),
      '${appLocalizations.networkException} [502]',
    );
  });

  test('shows underlying connection errors and timeout messages', () {
    for (final type in [
      DioExceptionType.unknown,
      DioExceptionType.connectionError,
      DioExceptionType.badCertificate,
      DioExceptionType.connectionTimeout,
    ]) {
      expect(
        userFacingErrorMessage(
          DioException(
            requestOptions: RequestOptions(path: '/subscription'),
            type: type,
            error: 'Connection refused',
            message: 'Request failed',
          ),
          appLocalizations,
        ),
        '${appLocalizations.unknownNetworkError}\nConnection refused',
      );
    }
    expect(
      userFacingErrorMessage(
        DioException(
          requestOptions: RequestOptions(path: '/subscription'),
          type: DioExceptionType.receiveTimeout,
          message: 'Receive timed out after 10 seconds',
        ),
        appLocalizations,
      ),
      contains('Receive timed out after 10 seconds'),
    );
  });

  test('maps Core request failures using the same network categories', () {
    expect(
      networkErrorMessage(
        const CoreMethodException(
          code: 'request_bad_response',
          message: '503 Service Unavailable',
        ),
        appLocalizations,
      ),
      '${appLocalizations.networkException}\n503 Service Unavailable',
    );
    expect(
      networkErrorMessage(
        const CoreMethodException(
          code: 'request_error',
          message: 'request timed out',
        ),
        appLocalizations,
      ),
      '${appLocalizations.unknownNetworkError}\nrequest timed out',
    );
  });

  test('uses the Core message for non-request failures', () {
    expect(
      userFacingErrorMessage(
        const CoreMethodException(
          code: 'provider_update_error',
          message: 'proxy 0: unsupported type',
        ),
        appLocalizations,
      ),
      'proxy 0: unsupported type',
    );
  });

  group('policy-blocked Core launch', () {
    const blocked = DesktopCoreFailure(
      code: 'start_failed',
      phase: DesktopCorePhase.starting,
      revision: 1,
      cause: HelperException(
        code: 'processLaunchFailed',
        message: 'spawn failed',
        details: {'osError': 577},
      ),
    );

    tearDown(() {
      smartAppControlStateReader = readSmartAppControlState;
    });

    test('names Smart App Control when it is on', () {
      smartAppControlStateReader = () => SmartAppControlState.on;

      expect(
        userFacingErrorMessage(blocked, appLocalizations),
        appLocalizations.coreBlockedBySmartAppControlTip,
      );
    });

    test('names the generic policy with its error code otherwise', () {
      smartAppControlStateReader = () => SmartAppControlState.off;

      expect(
        userFacingErrorMessage(blocked, appLocalizations),
        appLocalizations.coreBlockedByPolicyTip(577),
      );
    });

    test('leaves other start failures on the raw description', () {
      smartAppControlStateReader = () => SmartAppControlState.on;
      const timedOut = DesktopCoreFailure(
        code: 'start_failed',
        phase: DesktopCorePhase.starting,
        revision: 1,
        cause: HelperException(
          code: 'transportError',
          message: 'Helper start request failed',
        ),
      );

      expect(
        userFacingErrorMessage(timedOut, appLocalizations),
        timedOut.toString(),
      );
    });
  });
}
