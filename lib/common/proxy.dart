import 'package:fl_clash/common/system.dart';
import 'package:proxy/proxy.dart';

final proxy = system.isDesktop ? Proxy() : null;

String proxyEnvCommand(int port, {required bool isWindows}) {
  final url = 'http://127.0.0.1:$port';
  return isWindows
      ? '\$env:http_proxy="$url"; \$env:https_proxy="$url"; '
            '\$env:all_proxy="$url"; '
            '\$env:no_proxy="localhost,::1,127.0.0.1"'
      : 'export http_proxy="$url"; export https_proxy="$url"; '
            'export all_proxy="$url"; '
            'export no_proxy="localhost,::1,127.0.0.1"';
}
