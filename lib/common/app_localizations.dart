import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui';

import 'package:dio/dio.dart';
import 'package:fl_clash/core/desktop/launch_policy.dart';
import 'package:fl_clash/core/method.dart';
import 'package:fl_clash/l10n/l10n.dart';

final currentAppLocalizations = AppLocalizations.current;

String? networkErrorMessage(Object error, AppLocalizations appLocalizations) {
  if (error case CoreMethodException(:final code)) {
    return switch (code) {
      'request_bad_response' => appLocalizations.networkException,
      'request_error' => appLocalizations.unknownNetworkError,
      _ => null,
    };
  }
  if (error is DioException) {
    if (error.type == DioExceptionType.badResponse) {
      final response = error.response;
      final statusCode = response?.statusCode ?? 0;
      final body = _responseBody(response?.data);
      final detail = body.isNotEmpty ? '[$statusCode]\n$body' : '[$statusCode]';
      return '${appLocalizations.networkException} $detail';
    }
    final message = appLocalizations.unknownNetworkError;
    final detail = error.error?.toString().trim();
    return detail == null || detail.isEmpty ? message : '$message\n$detail';
  }
  return null;
}

String? coreLaunchBlockedMessage(
  Object error,
  AppLocalizations appLocalizations,
) {
  if (!isPolicyBlockedLaunch(error)) {
    return null;
  }
  return switch (smartAppControlStateReader()) {
    SmartAppControlState.on || SmartAppControlState.evaluation =>
      appLocalizations.coreBlockedBySmartAppControlTip,
    _ => appLocalizations.coreBlockedByPolicyTip(launchOsError(error)!),
  };
}

String _responseBody(Object? data) {
  if (data == null) return '';
  if (data is Uint8List) {
    try {
      return utf8.decode(data).trim();
    } on FormatException {
      return '';
    }
  }
  return data.toString().trim();
}

String userFacingErrorMessage(Object error, AppLocalizations appLocalizations) {
  return networkErrorMessage(error, appLocalizations) ??
      coreLaunchBlockedMessage(error, appLocalizations) ??
      switch (error) {
        CoreMethodException(:final message) => message,
        _ => error.toString(),
      };
}

Locale? getLocaleForString(String? localString) {
  if (localString == null) return null;
  final localSplit = localString.split('_');
  if (localSplit.length == 1) {
    return Locale(localSplit[0]);
  }
  if (localSplit.length == 2) {
    return Locale(localSplit[0], localSplit[1]);
  }
  if (localSplit.length == 3) {
    return Locale.fromSubtags(
      languageCode: localSplit[0],
      scriptCode: localSplit[1],
      countryCode: localSplit[2],
    );
  }
  return null;
}
