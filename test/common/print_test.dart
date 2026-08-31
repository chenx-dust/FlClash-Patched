import 'package:dio/dio.dart';
import 'package:fl_clash/common/print.dart';
import 'package:fl_clash/state.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('compactError compacts DioException to type and status code', () {
    final error = DioException(
      requestOptions: RequestOptions(path: '/'),
      type: DioExceptionType.badResponse,
      response: Response(
        requestOptions: RequestOptions(path: '/'),
        statusCode: 403,
      ),
    );
    expect(compactError(error), 'DioException(badResponse, HTTP 403)');
  });

  test('compactError omits the status code when the response is missing', () {
    final error = DioException(
      requestOptions: RequestOptions(path: '/'),
      type: DioExceptionType.connectionError,
    );
    expect(compactError(error), 'DioException(connectionError)');
  });

  test('compactError keeps other exception messages', () {
    expect(compactError(StateError('boom')), contains('boom'));
  });

  test('app logs preserve their payload without adding a prefix', () {
    final originalDebugPrint = debugPrint;
    final wasAttached = globalState.isAttach;
    final messages = <String?>[];
    debugPrint = (message, {wrapWidth}) {
      messages.add(message);
    };
    globalState.isAttach = false;
    addTearDown(() {
      debugPrint = originalDebugPrint;
      globalState.isAttach = wasAttached;
    });

    commonPrint.log('core started');
    commonPrint.log(null);

    expect(messages, ['core started', '']);
  });
}
