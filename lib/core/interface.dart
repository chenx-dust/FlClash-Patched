import 'dart:async';
import 'dart:convert';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';

import 'method.dart';

mixin CoreInterface {
  Future<bool> init(InitParams params);

  Future<String> preload();

  Future<bool> shutdown(bool isUser);

  Future<bool> get isInit;

  Future<bool> forceGc();

  Future<String> validateConfig(String path);

  Future<Result> getConfig(String path);

  Future<String> asyncTestDelay(String url, String proxyName);

  Future<String> updateConfig(UpdateParams updateParams);

  Future<String> setupConfig(SetupParams setupParams);

  Future<ProxiesData> getProxies();

  Future<String> changeProxy(ChangeProxyParams changeProxyParams);

  Future<bool> startListener();

  Future<bool> stopListener();

  Future<String> getExternalProviders();

  Future<String>? getExternalProvider(String externalProviderName);

  Future<String> updateGeoData(String type);

  Future<String> sideLoadExternalProvider({
    required String providerName,
    required String data,
  });

  Future<String> updateExternalProvider(String providerName);

  FutureOr<String> getTraffic(bool onlyStatisticsProxy);

  FutureOr<String> getTotalTraffic(bool onlyStatisticsProxy);

  FutureOr<String> getCountryCode(String ip);

  FutureOr<String> getMemory();

  FutureOr<void> resetTraffic();

  FutureOr<void> startLog();

  FutureOr<void> stopLog();

  Future<bool> crash();

  FutureOr<String> getConnections();

  FutureOr<bool> closeConnection(String id);

  FutureOr<String> deleteFile(String path);

  FutureOr<bool> closeConnections();

  FutureOr<bool> resetConnections();
}

abstract class CoreHandlerInterface with CoreInterface {
  int _methodCallId = 0;

  String get nextMethodCallId => '${++_methodCallId}';

  Completer get completer;

  FutureOr<bool> destroy();

  Future<T?> _invokeMethod<T>({
    required CoreMethod method,
    Object? arguments,
    Duration? timeout,
  }) async {
    try {
      await completer.future.timeout(const Duration(seconds: 10));
    } catch (e) {
      commonPrint.log(
        'Invoke method ${method.name} before connection timed out: $e',
        logLevel: LogLevel.error,
      );
      return null;
    }
    return await utils.handleWatch(
      onStart: () {
        commonPrint.log(
          'Invoke method ${method.name} ${DateTime.now()} $arguments',
        );
      },
      function: () async {
        return invokeMethod<T>(
          method: method,
          arguments: arguments,
          timeout: timeout,
        );
      },
      onEnd: (result, elapsedMilliseconds) {
        commonPrint.log(
          'Invoke method ${method.name} completed in ${elapsedMilliseconds}ms',
        );
      },
    );
  }

  Future<T?> invokeMethod<T>({
    required CoreMethod method,
    Object? arguments,
    Duration? timeout,
  });

  @override
  Future<bool> init(InitParams params) async {
    return await _invokeMethod<bool>(
          method: CoreMethod.initClash,
          arguments: params.toJson(),
        ) ??
        false;
  }

  @override
  Future<bool> shutdown(bool isUser);

  @override
  Future<bool> get isInit async {
    return await _invokeMethod<bool>(method: CoreMethod.getIsInit) ?? false;
  }

  @override
  Future<bool> forceGc() async {
    return await _invokeMethod<bool>(method: CoreMethod.forceGc) ?? false;
  }

  @override
  Future<String> validateConfig(String path) async {
    return await _invokeMethod<String>(
          method: CoreMethod.validateConfig,
          arguments: path,
        ) ??
        '';
  }

  @override
  Future<String> updateConfig(UpdateParams updateParams) async {
    return await _invokeMethod<String>(
          method: CoreMethod.updateConfig,
          arguments: updateParams.toJson(),
        ) ??
        '';
  }

  @override
  Future<Result> getConfig(String path) async {
    try {
      final result = await _invokeMethod<Map<String, dynamic>>(
        method: CoreMethod.getConfig,
        arguments: path,
      );
      return Result.success(result ?? {});
    } on CoreMethodException catch (error) {
      return Result.error(error.message);
    }
  }

  @override
  Future<String> setupConfig(SetupParams setupParams) async {
    return await _invokeMethod<String>(
          method: CoreMethod.setupConfig,
          arguments: setupParams.toJson(),
        ) ??
        '';
  }

  @override
  Future<bool> crash() async {
    return await _invokeMethod<bool>(method: CoreMethod.crash) ?? false;
  }

  @override
  Future<ProxiesData> getProxies() async {
    final data = await _invokeMethod<Map<String, dynamic>>(
      method: CoreMethod.getProxies,
    );
    return data != null
        ? ProxiesData.fromJson(data)
        : const ProxiesData(proxies: {}, all: []);
  }

  @override
  Future<String> changeProxy(ChangeProxyParams changeProxyParams) async {
    return await _invokeMethod<String>(
          method: CoreMethod.changeProxy,
          arguments: changeProxyParams.toJson(),
        ) ??
        '';
  }

  @override
  Future<String> getExternalProviders() async {
    return await _invokeMethod<String>(
          method: CoreMethod.getExternalProviders,
        ) ??
        '';
  }

  @override
  Future<String> getExternalProvider(String externalProviderName) async {
    return await _invokeMethod<String>(
          method: CoreMethod.getExternalProvider,
          arguments: externalProviderName,
        ) ??
        '';
  }

  @override
  Future<String> updateGeoData(String type) async {
    return await _invokeMethod<String>(
          method: CoreMethod.updateGeoData,
          arguments: type,
        ) ??
        '';
  }

  @override
  Future<String> sideLoadExternalProvider({
    required String providerName,
    required String data,
  }) async {
    return await _invokeMethod<String>(
          method: CoreMethod.sideLoadExternalProvider,
          arguments: {'providerName': providerName, 'data': data},
        ) ??
        '';
  }

  @override
  Future<String> updateExternalProvider(String providerName) async {
    return await _invokeMethod<String>(
          method: CoreMethod.updateExternalProvider,
          arguments: providerName,
        ) ??
        '';
  }

  @override
  Future<String> getConnections() async {
    return await _invokeMethod<String>(method: CoreMethod.getConnections) ?? '';
  }

  @override
  Future<bool> closeConnections() async {
    return await _invokeMethod<bool>(method: CoreMethod.closeConnections) ??
        false;
  }

  @override
  Future<bool> resetConnections() async {
    return await _invokeMethod<bool>(method: CoreMethod.resetConnections) ??
        false;
  }

  @override
  Future<bool> closeConnection(String id) async {
    return await _invokeMethod<bool>(
          method: CoreMethod.closeConnection,
          arguments: id,
        ) ??
        false;
  }

  @override
  Future<String> getTotalTraffic(bool onlyStatisticsProxy) async {
    return await _invokeMethod<String>(
          method: CoreMethod.getTotalTraffic,
          arguments: onlyStatisticsProxy,
        ) ??
        '';
  }

  @override
  Future<String> getTraffic(bool onlyStatisticsProxy) async {
    return await _invokeMethod<String>(
          method: CoreMethod.getTraffic,
          arguments: onlyStatisticsProxy,
        ) ??
        '';
  }

  @override
  Future<String> deleteFile(String path) async {
    return await _invokeMethod<String>(
          method: CoreMethod.deleteFile,
          arguments: path,
        ) ??
        '';
  }

  @override
  FutureOr<void> resetTraffic() {
    _invokeMethod(method: CoreMethod.resetTraffic);
  }

  @override
  FutureOr<void> startLog() {
    _invokeMethod(method: CoreMethod.startLog);
  }

  @override
  FutureOr<void> stopLog() {
    _invokeMethod<bool>(method: CoreMethod.stopLog);
  }

  @override
  Future<bool> startListener() async {
    return await _invokeMethod<bool>(method: CoreMethod.startListener) ?? false;
  }

  @override
  Future<bool> stopListener() async {
    return await _invokeMethod<bool>(method: CoreMethod.stopListener) ?? false;
  }

  @override
  Future<String> asyncTestDelay(String url, String proxyName) async {
    final delayParams = {
      'proxy-name': proxyName,
      'timeout': httpTimeoutDuration.inMilliseconds,
      'test-url': url,
    };
    return await _invokeMethod<String>(
          method: CoreMethod.asyncTestDelay,
          arguments: delayParams,
          timeout: const Duration(seconds: 6),
        ) ??
        json.encode(Delay(name: proxyName, value: -1, url: url));
  }

  @override
  Future<String> getCountryCode(String ip) async {
    return await _invokeMethod<String>(
          method: CoreMethod.getCountryCode,
          arguments: ip,
        ) ??
        '';
  }

  @override
  Future<String> getMemory() async {
    return await _invokeMethod<String>(method: CoreMethod.getMemory) ?? '';
  }
}
