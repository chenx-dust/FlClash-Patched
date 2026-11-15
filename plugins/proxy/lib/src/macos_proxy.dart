import 'dart:io';

import 'proxy_command.dart';

class MacosProxy {
  final ProxyCommandRunner _commandRunner;
  bool _needsCleanup = false;

  MacosProxy({required ProxyCommandRunner commandRunner})
    : _commandRunner = commandRunner;

  Future<bool> start(int port, List<String> bypassDomain) async {
    final services = await _networkServices();
    if (services.isEmpty) return false;
    _needsCleanup = true;
    return _commandRunner.run(
      services.expand(
        (service) => MacosProxyCommands.buildStart(service, port, bypassDomain),
      ),
    );
  }

  Future<bool> stop({bool onlyIfNeeded = false}) async {
    if (onlyIfNeeded && !_needsCleanup) return true;
    _needsCleanup = true;
    final services = await _networkServices();
    final stopped = await _commandRunner.run(
      services.expand(MacosProxyCommands.buildStop),
    );
    if (stopped) _needsCleanup = false;
    return stopped;
  }

  Future<List<String>> _networkServices() async {
    try {
      final result = await _commandRunner.process('/usr/sbin/networksetup', [
        '-listallnetworkservices',
      ]);
      if (result.exitCode != 0) {
        return [];
      }
      return MacosProxyCommands.parseNetworkServices(result.stdout.toString());
    } on ProcessException {
      return [];
    }
  }
}

class MacosProxyCommands {
  static List<ProxyCommand> buildStart(
    String service,
    int port,
    List<String> bypassDomain,
  ) {
    return [
      ProxyCommand('/usr/sbin/networksetup', [
        '-setwebproxy',
        service,
        proxyHost,
        '$port',
      ]),
      ProxyCommand('/usr/sbin/networksetup', [
        '-setsecurewebproxy',
        service,
        proxyHost,
        '$port',
      ]),
      ProxyCommand('/usr/sbin/networksetup', [
        '-setsocksfirewallproxy',
        service,
        proxyHost,
        '$port',
      ]),
      buildProxyBypass(service, bypassDomain),
      ProxyCommand('/usr/sbin/networksetup', [
        '-setwebproxystate',
        service,
        'on',
      ]),
      ProxyCommand('/usr/sbin/networksetup', [
        '-setsecurewebproxystate',
        service,
        'on',
      ]),
      ProxyCommand('/usr/sbin/networksetup', [
        '-setsocksfirewallproxystate',
        service,
        'on',
      ]),
    ];
  }

  static List<ProxyCommand> buildStop(String service) {
    return [
      ProxyCommand('/usr/sbin/networksetup', [
        '-setautoproxystate',
        service,
        'off',
      ]),
      ProxyCommand('/usr/sbin/networksetup', [
        '-setwebproxystate',
        service,
        'off',
      ]),
      ProxyCommand('/usr/sbin/networksetup', [
        '-setsecurewebproxystate',
        service,
        'off',
      ]),
      ProxyCommand('/usr/sbin/networksetup', [
        '-setsocksfirewallproxystate',
        service,
        'off',
      ]),
      buildProxyBypass(service, const []),
    ];
  }

  static ProxyCommand buildProxyBypass(
    String service,
    List<String> bypassDomain,
  ) {
    final domains = withoutWininetLocal(bypassDomain);
    return ProxyCommand('/usr/sbin/networksetup', [
      '-setproxybypassdomains',
      service,
      if (domains.isEmpty) 'Empty' else ...domains,
    ]);
  }

  static List<String> parseNetworkServices(String stdout) {
    return stdout
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .where((line) => !line.startsWith('*'))
        .where((line) => !line.startsWith('An asterisk '))
        .toList();
  }
}
