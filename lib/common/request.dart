import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/state.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;

class Request {
  late final Dio dio;
  late final Dio _clashDio;
  String? userAgent;

  ProviderReader? _read;

  void attach(ProviderReader read) {
    _read = read;
  }

  Request() {
    dio = Dio(BaseOptions(headers: {'User-Agent': browserUa}));
    _clashDio = Dio();
    _clashDio.httpClientAdapter = IOHttpClientAdapter(
      createHttpClient: () {
        final client = HttpClient();
        client.findProxy = (Uri uri) {
          client.userAgent = globalState.ua;
          final read = _read;
          if (read == null) {
            return 'DIRECT';
          }
          return FlClashHttpOverrides.findProxyForReader(read, uri);
        };
        return client;
      },
    );
  }

  Future<Response<Uint8List>> getFileResponseForUrl(String url) async {
    try {
      return await _clashDio
          .get<Uint8List>(
            url,
            options: Options(responseType: ResponseType.bytes),
          )
          .timeout(const Duration(seconds: 10));
    } catch (e) {
      commonPrint.log(
        'getFileResponseForUrl error ${compactError(e)}',
        logLevel: LogLevel.warning,
      );
      rethrow;
    }
  }

  Future<Response<String>> getTextResponseForUrl(String url) async {
    try {
      return await _clashDio
          .get<String>(url, options: Options(responseType: ResponseType.plain))
          .timeout(const Duration(seconds: 10));
    } catch (e) {
      commonPrint.log(
        'getTextResponseForUrl error ${compactError(e)}',
        logLevel: LogLevel.warning,
      );
      rethrow;
    }
  }

  /// `<savePath>.part` survives cancellation and failure, so retries and later
  /// calls resume it with `Range`; the caller verifies the hash, so a server
  /// that ignores `Range` only costs a restart.
  Future<void> downloadFile(
    String url,
    String savePath, {
    ProgressCallback? onReceiveProgress,
    CancelToken? cancelToken,
    int retries = 3,
    Duration Function(int attempt) retryDelay = _downloadRetryDelay,
  }) async {
    final part = File('$savePath.part');
    for (var attempt = 1; ; attempt++) {
      try {
        await _downloadRange(url, part, onReceiveProgress, cancelToken);
        break;
      } catch (e) {
        if (e is DioException && e.type == DioExceptionType.cancel) {
          rethrow;
        }
        if (attempt > retries || !_isTransientDownloadError(e)) {
          commonPrint.log(
            'downloadFile failed: ${compactError(e)}',
            logLevel: LogLevel.warning,
          );
          throw _requestException(e);
        }
        commonPrint.log(
          'downloadFile attempt $attempt interrupted, resuming: '
          '${compactError(e)}',
          logLevel: LogLevel.info,
        );
        await _delayUnlessCancelled(retryDelay(attempt), cancelToken);
      }
    }
    final target = File(savePath);
    if (await target.exists()) {
      await target.delete();
    }
    await part.rename(savePath);
  }

  Future<void> _downloadRange(
    String url,
    File part,
    ProgressCallback? onReceiveProgress,
    CancelToken? cancelToken,
  ) async {
    final offset = await part.exists() ? await part.length() : 0;
    final response = await _clashDio.get<ResponseBody>(
      url,
      cancelToken: cancelToken,
      options: Options(
        responseType: ResponseType.stream,
        receiveTimeout: const Duration(seconds: 30),
        headers: {if (offset > 0) HttpHeaders.rangeHeader: 'bytes=$offset-'},
        validateStatus: (status) =>
            status == HttpStatus.ok ||
            status == HttpStatus.partialContent ||
            status == HttpStatus.requestedRangeNotSatisfiable,
      ),
    );
    final body = response.data!;
    if (response.statusCode == HttpStatus.requestedRangeNotSatisfiable) {
      await body.stream.drain<void>();
      if (_contentRangeLength(response.headers) == offset) {
        return;
      }
      await part.delete();
      throw const HttpException('The partial file overruns the download');
    }
    final resumed = response.statusCode == HttpStatus.partialContent;
    if (resumed && _contentRangeStart(response.headers) != offset) {
      await body.stream.drain<void>();
      await part.delete();
      throw const HttpException('Content-Range does not match the request');
    }
    var received = resumed ? offset : 0;
    final length = body.contentLength;
    final total = length < 0 ? -1 : received + length;
    final sink = part.openWrite(
      mode: resumed ? FileMode.append : FileMode.write,
    );
    try {
      await for (final chunk in body.stream) {
        sink.add(chunk);
        received += chunk.length;
        onReceiveProgress?.call(received, total);
      }
    } finally {
      await sink.close();
    }
    if (total >= 0 && received < total) {
      throw const HttpException('Connection closed before the body ended');
    }
  }

  int? _contentRangeStart(Headers headers) {
    final value = headers.value(HttpHeaders.contentRangeHeader);
    final match = RegExp(r'^bytes (\d+)-').firstMatch(value ?? '');
    return match == null ? null : int.parse(match[1]!);
  }

  int? _contentRangeLength(Headers headers) {
    final value = headers.value(HttpHeaders.contentRangeHeader);
    final match = RegExp(r'^bytes \*/(\d+)$').firstMatch(value ?? '');
    return match == null ? null : int.parse(match[1]!);
  }

  @visibleForTesting
  Dio get clashDio => _clashDio;

  bool _isTransientDownloadError(Object error) {
    if (error is DioException) {
      return switch (error.type) {
        DioExceptionType.badResponse =>
          (error.response?.statusCode ?? 0) >= HttpStatus.internalServerError,
        DioExceptionType.badCertificate || DioExceptionType.cancel => false,
        _ => true,
      };
    }
    return error is SocketException ||
        error is HttpException ||
        error is TimeoutException;
  }

  Future<void> _delayUnlessCancelled(
    Duration delay,
    CancelToken? cancelToken,
  ) async {
    await Future.any([Future<void>.delayed(delay), ?cancelToken?.whenCancel]);
    final cancelError = cancelToken?.cancelError;
    if (cancelError != null) {
      throw cancelError;
    }
  }

  /// Goes through the same client as [downloadFile], so a GitHub reachable
  /// only through the Core is not reported as offline before the download.
  Future<ReleaseManifest?> checkForUpdate() async {
    try {
      final release = await _latestRelease();
      final version = globalState.packageInfo.version;
      return compareVersions(release.tag, version) > 0 ? release : null;
    } catch (e) {
      commonPrint.log(
        'checkForUpdate failed: ${compactError(e)}',
        logLevel: LogLevel.warning,
      );
      throw _requestException(e);
    }
  }

  /// The manifest is a release download, outside the REST API's limit of 60
  /// unauthenticated requests an hour per IP; the API answers only for a
  /// release without one.
  Future<ReleaseManifest> _latestRelease() async {
    try {
      final response = await _clashDio
          .get<String>(
            'https://github.com/$repository/releases/latest/download/version.json',
            options: Options(responseType: ResponseType.plain),
          )
          .timeout(const Duration(seconds: 10));
      return ReleaseManifest.fromJson(jsonDecode(response.data ?? ''));
    } catch (e) {
      commonPrint.log(
        'release manifest unavailable, asking the API: ${compactError(e)}',
        logLevel: LogLevel.info,
      );
    }
    final response = await _clashDio
        .get<Object?>(
          'https://api.github.com/repos/$repository/releases/latest',
          options: Options(responseType: ResponseType.json),
        )
        .timeout(const Duration(seconds: 10));
    return ReleaseManifest.fromGitHubRelease(response.data);
  }

  MessageException _requestException(Object error) {
    if (error is MessageException) {
      return error;
    }
    if (error is DioException) {
      if (error.type == DioExceptionType.badResponse) {
        final response = error.response;
        final statusCode = response?.statusCode ?? 0;
        final body = _responseBody(response);
        final detail = body.isEmpty ? '[$statusCode]' : '[$statusCode]\n$body';
        return MessageException(
          '${currentAppLocalizations.networkException} $detail',
        );
      }
      final detail = error.error?.toString().trim();
      if (detail != null && detail.isNotEmpty) {
        return MessageException(
          '${currentAppLocalizations.unknownNetworkError}\n$detail',
        );
      }
    }
    return MessageException(
      '${currentAppLocalizations.unknownNetworkError}\n$error',
    );
  }

  String _responseBody(Response<dynamic>? response) {
    final data = response?.data;
    if (data == null) {
      return '';
    }
    if (data is Uint8List) {
      try {
        return utf8.decode(data).trim();
      } catch (_) {
        return '';
      }
    }
    if (data is Map || data is List) {
      return jsonEncode(data).trim();
    }
    return data.toString().trim();
  }

  final Map<String, IpInfo Function(Map<String, dynamic>)> _ipInfoSources = {
    'https://ipwho.is': IpInfo.fromIpWhoIsJson,
    'https://api.myip.com': IpInfo.fromMyIpJson,
    'https://ipapi.co/json': IpInfo.fromIpApiCoJson,
    'https://ident.me/json': IpInfo.fromIdentMeJson,
    'http://ip-api.com/json': IpInfo.fromIpAPIJson,
    'https://api.ip.sb/geoip': IpInfo.fromIpSbJson,
    'https://ipinfo.io/json': IpInfo.fromIpInfoIoJson,
  };

  Future<Result<IpInfo?>> checkIp({CancelToken? cancelToken}) async {
    var failureCount = 0;
    final token = cancelToken ?? CancelToken();
    final futures = _ipInfoSources.entries.map((source) async {
      final Completer<Result<IpInfo?>> completer = Completer();
      void handleFailRes() {
        if (!completer.isCompleted && failureCount == _ipInfoSources.length) {
          completer.complete(Result.success(null));
        }
      }

      final future = dio
          .get<Map<String, dynamic>>(
            source.key,
            cancelToken: token,
            options: Options(responseType: ResponseType.json),
          )
          .timeout(const Duration(seconds: 10));
      unawaited(
        future
            .then((res) {
              if (res.statusCode == HttpStatus.ok && res.data != null) {
                completer.complete(Result.success(source.value(res.data!)));
                return;
              }
              commonPrint.log('checkIp data empty', logLevel: LogLevel.info);
              failureCount++;
              handleFailRes();
            })
            .catchError((e) {
              failureCount++;
              if (e is DioException && e.type == DioExceptionType.cancel) {
                completer.complete(Result.error('cancelled'));
                return;
              }
              commonPrint.log('checkIp error $e', logLevel: LogLevel.warning);
              handleFailRes();
            }),
      );
      return completer.future;
    });
    final res = await Future.any(futures);
    token.cancel();
    return res;
  }
}

Duration _downloadRetryDelay(int attempt) => Duration(seconds: 2 * attempt);

final request = Request();

String? getFileNameForDisposition(String? disposition) {
  if (disposition == null) return null;
  final parseValue = HeaderValue.parse(disposition);
  final parameters = parseValue.parameters;
  final fileNamePointKey = parameters.keys.firstWhere(
    (key) => key == 'filename*',
    orElse: () => '',
  );
  if (fileNamePointKey.isNotEmpty) {
    final res = parameters[fileNamePointKey]?.split("''") ?? [];
    if (res.length >= 2) {
      return Uri.decodeComponent(res[1]);
    }
  }
  final fileNameKey = parameters.keys.firstWhere(
    (key) => key == 'filename',
    orElse: () => '',
  );
  if (fileNameKey.isEmpty) return null;
  return parameters[fileNameKey];
}

String? getFileNameFromUrl(String? url) {
  final realUrl = url?.trim();
  if (realUrl == null || realUrl.isEmpty) return null;
  final uri = Uri.tryParse(realUrl);
  if (uri == null || uri.pathSegments.isEmpty) return null;
  final fileName = uri.pathSegments
      .lastWhere((segment) => segment.trim().isNotEmpty, orElse: () => '')
      .trim();
  if (fileName.isEmpty || fileName.contains('/') || fileName.contains(r'\')) {
    return null;
  }
  final dotIndex = fileName.lastIndexOf('.');
  if (dotIndex <= 0 || dotIndex == fileName.length - 1) {
    return null;
  }
  return fileName;
}
