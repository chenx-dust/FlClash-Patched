import 'dart:io';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/providers/config.dart';
import 'package:fl_clash/providers/state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class FlClashHttpOverrides extends HttpOverrides {
  final ProviderContainer _container;

  FlClashHttpOverrides(this._container);

  static String findProxyFor(ProviderContainer container, Uri url) {
    return findProxyForReader(container.read, url);
  }

  static bool acceptBadCertificateForReader(ProviderReader read) {
    return read(appSettingProvider).ignoreCertificateErrors;
  }

  static String findProxyForReader(ProviderReader read, Uri url) {
    if ([localhost].contains(url.host)) {
      return 'DIRECT';
    }
    final isStart = read(isStartProvider);
    final suspend = system.isIOS ? false : read(suspendProvider);
    commonPrint.log('find $url proxy: $isStart');
    if (!isStart || suspend) return 'DIRECT';
    final mixedPort = read(
      patchClashConfigProvider.select((state) => state.mixedPort),
    );
    return 'PROXY localhost:$mixedPort';
  }

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final client = super.createHttpClient(context);
    client.badCertificateCallback = (_, _, _) =>
        acceptBadCertificateForReader(_container.read);
    client.findProxy = (url) => findProxyFor(_container, url);
    return client;
  }
}
