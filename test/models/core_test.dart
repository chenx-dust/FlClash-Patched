import 'dart:convert';

import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:test/test.dart';

void main() {
  group('SetupParams', () {
    test('fromJson uses snake-case keys', () {
      final json = {
        'selected-map': {'G1': 'P1'},
        'test-url': 'http://test.com',
      };
      final params = SetupParams.fromJson(json);
      expect(params.selectedMap, {'G1': 'P1'});
      expect(params.testUrl, 'http://test.com');
    });

    test('toJson uses snake-case keys', () {
      const params = SetupParams(
        selectedMap: {'G1': 'P1'},
        testUrl: 'http://t.com',
      );
      final json = params.toJson();
      expect(json['selected-map'], {'G1': 'P1'});
      expect(json['test-url'], 'http://t.com');
    });
  });

  group('UpdateParams', () {
    test('fromJson with all fields', () {
      final json = {
        'tun': {'enable': true},
        'mixed-port': 7890,
        'allow-lan': true,
        'find-process-mode': 'off',
        'mode': 'rule',
        'log-level': 'info',
        'ipv6': false,
        'tcp-concurrent': false,
        'external-controller': '0.0.0.0:9091',
        'secret': 'test-secret',
        'unified-delay': false,
      };
      final params = UpdateParams.fromJson(json);
      expect(params.mixedPort, 7890);
      expect(params.allowLan, true);
      expect(params.mode, Mode.rule);
      expect(params.logLevel, LogLevel.info);
      expect(params.externalController, '0.0.0.0:9091');
      expect(params.secret, 'test-secret');
    });
  });

  group('VpnOptions', () {
    test('serializes mobile TUN behavior flags', () {
      final options = VpnOptions.fromJson({
        'enable': true,
        'port': 7890,
        'ipv6': true,
        'captureDns': true,
        'accessControlProps': const AccessControlProps().toJson(),
        'allowBypass': true,
        'systemProxy': false,
        'suspendSupport': true,
        'bypassDomain': <String>[],
        'stack': 'mixed',
        'routeAddress': ['0.0.0.0/0'],
        'disableIcmpForwarding': true,
        'endpointIndependentNat': true,
      });

      expect(options.disableIcmpForwarding, true);
      expect(options.endpointIndependentNat, true);
      expect(options.captureDns, true);
      expect(options.toJson()['captureDns'], true);
      expect(options.toJson()['disableIcmpForwarding'], true);
      expect(options.toJson()['endpointIndependentNat'], true);
    });
  });

  group('InitParams', () {
    test('fromJson and toJson', () {
      final json = {'home-dir': '/data/clash', 'version': 3};
      final params = InitParams.fromJson(json);
      expect(params.homeDir, '/data/clash');
      expect(params.version, 3);
      final restored = jsonDecode(jsonEncode(params.toJson()));
      expect(restored['home-dir'], '/data/clash');
      expect(restored['version'], 3);
    });
  });

  group('ChangeProxyParams', () {
    test('fromJson and toJson use snake-case', () {
      final json = {'group-name': 'Proxy', 'proxy-name': 'auto'};
      final params = ChangeProxyParams.fromJson(json);
      expect(params.groupName, 'Proxy');
      expect(params.proxyName, 'auto');
      final out = params.toJson();
      expect(out['group-name'], 'Proxy');
      expect(out['proxy-name'], 'auto');
    });
  });

  group('UpdateGeoDataParams', () {
    test('fromJson with snake-case keys', () {
      final json = {'geo-type': 'mmdb', 'geo-name': 'Country'};
      final params = UpdateGeoDataParams.fromJson(json);
      expect(params.geoType, 'mmdb');
      expect(params.geoName, 'Country');
    });
  });

  group('Delay', () {
    test('fromJson and toJson', () {
      final json = {'name': 'P1', 'url': 'test.com', 'value': 42};
      final delay = Delay.fromJson(json);
      expect(delay.name, 'P1');
      expect(delay.url, 'test.com');
      expect(delay.value, 42);
      final out = delay.toJson();
      expect(out['value'], 42);
    });

    test('null value', () {
      final delay = Delay.fromJson({'name': 'P1', 'url': 'test.com'});
      expect(delay.value, null);
    });
  });

  group('Now', () {
    test('fromJson and toJson', () {
      final now = Now.fromJson({'name': 'test', 'value': '123'});
      expect(now.name, 'test');
      expect(now.value, '123');
    });
  });

  group('ProxiesData', () {
    test('fromJson with proxies and all list', () {
      final json = {
        'proxies': {
          'G1': {
            'type': 'Selector',
            'now': 'auto',
            'all': ['auto', 'P1'],
          },
        },
        'all': ['G1'],
      };
      final data = ProxiesData.fromJson(json);
      expect(data.all, ['G1']);
      expect(data.proxies['G1'], isA<Map>());
    });
  });

  group('ExternalProvider', () {
    test('fromJson with subscription info', () {
      final json = {
        'name': 'TestProvider',
        'type': 'Proxy',
        'count': 10,
        'vehicle-type': 'HTTP',
        'update-at': '2024-01-01T00:00:00.000Z',
        'subscription-info': {
          'Upload': 100,
          'Download': 200,
          'Total': 1000,
          'Expire': 1700000000,
        },
      };
      final provider = ExternalProvider.fromJson(json);
      expect(provider.name, 'TestProvider');
      expect(provider.count, 10);
      expect(provider.subscriptionInfo!.upload, 100);
      expect(provider.subscriptionInfo!.download, 200);
      expect(provider.subscriptionInfo!.total, 1000);
      expect(provider.subscriptionInfo!.expire, 1700000000);
    });

    test('updatingKey uses provider_ prefix', () {
      final provider = ExternalProvider(
        name: 'MyProvider',
        type: 'Proxy',
        count: 5,
        vehicleType: 'HTTP',
        updateAt: DateTime.now(),
      );
      expect(provider.updatingKey, 'provider_MyProvider');
    });

    test('allows only text rule providers to be edited as text', () {
      final textRuleProvider = ExternalProvider(
        name: 'TextRules',
        type: 'Rule',
        format: 'TextRule',
        count: 5,
        vehicleType: 'HTTP',
        updateAt: DateTime.now(),
      );
      final mrsRuleProvider = textRuleProvider.copyWith(format: 'MrsRule');

      expect(textRuleProvider.canEditAsText, isTrue);
      expect(mrsRuleProvider.canEditAsText, isFalse);
    });
  });

  group('Overlay network status', () {
    test('parses uninitialized state', () {
      final status = OverlayNetworkStatus.fromJson({
        'name': 'tailnet',
        'kind': 'tailscale',
        'state': 'uninitialized',
        'raw-state': 'NoState',
      });

      expect(status.state, OverlayNetworkState.uninitialized);
    });

    test('parses Tailscale summary and node details', () {
      final status = OverlayNetworkStatus.fromJson({
        'name': 'tailnet',
        'kind': 'tailscale',
        'state': 'connected',
        'raw-state': 'Running',
        'auth-url': 'https://login.tailscale.com/a/test',
        'network-name': 'example.com',
        'details': {
          'magic-dns-suffix': 'example.com',
          'auth-key-configured': true,
          'health': ['warning'],
          'nodes': [
            {
              'id': 'node-1',
              'public-key': 'nodekey:test',
              'hostname': 'device',
              'dns-name': 'device.example.com.',
              'os': 'linux',
              'ips': ['100.64.0.1'],
              'tags': ['tag:server'],
              'endpoints': ['192.0.2.1:41641'],
              'current-endpoint': '192.0.2.1:41641',
              'relay': 'sfo',
              'rx-bytes': 12,
              'tx-bytes': 34,
              'online': false,
              'active': false,
              'self': false,
              'exit-node': true,
              'exit-node-option': true,
              'expired': false,
              'last-seen': '2026-08-18T00:00:00Z',
            },
          ],
        },
      });

      expect(status.name, 'tailnet');
      expect(status.kind, OverlayNetworkKind.tailscale);
      expect(status.state, OverlayNetworkState.connected);
      expect(status.networkName, 'example.com');
      expect(status.tailscaleDetails?.magicDnsSuffix, 'example.com');
      expect(status.tailscaleDetails?.authKeyConfigured, isTrue);
      expect(status.tailscaleDetails?.health, ['warning']);
      expect(status.tailscaleDetails?.nodes.single.hostName, 'device');
      expect(
        status.tailscaleDetails?.nodes.single.dnsName,
        'device.example.com.',
      );
      expect(status.tailscaleDetails?.nodes.single.exitNode, isTrue);
      expect(status.tailscaleDetails?.nodes.single.publicKey, 'nodekey:test');
      expect(status.tailscaleDetails?.nodes.single.tags, ['tag:server']);
      expect(status.tailscaleDetails?.nodes.single.endpoints, [
        '192.0.2.1:41641',
      ]);
      expect(status.tailscaleDetails?.nodes.single.rxBytes, 12);
      expect(
        status.tailscaleDetails?.nodes.single.lastSeen,
        DateTime.utc(2026, 8, 18),
      );
    });

    test('parses ZeroTier summary and peer details', () {
      final status = OverlayNetworkStatus.fromJson({
        'name': 'zerotier',
        'kind': 'zerotier',
        'state': 'needs-login',
        'raw-state': 'authentication-required',
        'network-name': 'example',
        'auth-url': 'https://example.com/login',
        'details': {
          'network-id': '8056c2e21c000001',
          'node': 'abcdef1234',
          'online': true,
          'addresses': ['10.0.0.2/24'],
          'routes': ['10.0.0.0/24'],
          'dns': ['10.0.0.1:53'],
          'mtu': 2800,
          'peers': [
            {
              'address': '1234567890',
              'role': 'leaf',
              'version': '1.14.2',
              'direct': true,
              'endpoints': ['192.0.2.1:9993'],
              'latency-ms': 12,
            },
          ],
        },
      });

      expect(status.state, OverlayNetworkState.needsLogin);
      expect(status.authUrl, 'https://example.com/login');
      expect(status.zeroTierDetails?.networkId, '8056c2e21c000001');
      expect(status.zeroTierDetails?.peers.single.direct, isTrue);
      expect(status.zeroTierDetails?.peers.single.latencyMs, 12);
    });

    test('keeps details distinct from an empty summary', () {
      final summary = OverlayNetworkStatus.fromJson({
        'name': 'tailnet',
        'kind': 'tailscale',
        'state': 'stopped',
      });

      expect(summary.hasDetails, isFalse);
      expect(summary.tailscaleDetails, isNull);
    });
  });

  group('CoreEvent', () {
    test('fromJson with type and data', () {
      final event = CoreEvent.fromJson({'type': 'log', 'data': 'test log'});
      expect(event.type, CoreEventType.log);
      expect(event.data, 'test log');
    });
  });

  group('InvokeMessage', () {
    test('fromJson', () {
      final msg = InvokeMessage.fromJson({
        'type': 'protect',
        'data': {'method': 'test'},
      });
      expect(msg.type, InvokeMessageType.protect);
    });
  });
}
