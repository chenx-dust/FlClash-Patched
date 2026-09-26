import 'package:fl_clash/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'EasyTier node routes and multiple connections preserve optional stats',
    () {
      final node = EasyTierNode.fromJson({
        'peer-id': 42,
        'path-latency-ms': 40,
        'latency-first-path-latency-ms': 25,
        'instance-id': 'remote-instance',
        'version': '2.5',
        'next-hop': 7,
        'cost': 2,
        'connection-type': 'relayed',
        'feature-flags': {
          'is_public_server': true,
          'avoid_relay_data': false,
          'need_p2p': true,
        },
        'proxy-cidrs': ['192.168.2.0/24'],
        'listeners': ['udp://127.0.0.1:1000'],
        'connections': [
          {
            'id': 'a',
            'protocol': 'udp',
            'local-endpoint': 'udp://127.0.0.1:1000',
            'remote-endpoint': 'udp://192.0.2.1:2000',
            'rx-bytes': 0,
            'tx-bytes': 1024,
            'rx-packets': 0,
            'tx-packets': 4,
            'loss-rate': 0.125,
          },
          {'id': 'b'},
        ],
      });
      expect(node.peerId, 42);
      expect(node.pathLatencyMs, 40);
      expect(node.latencyFirstPathLatencyMs, 25);
      expect(EasyTierNode.fromJson({}).pathLatencyMs, isNull);
      expect(node.nextHop, 7);
      expect(node.cost, 2);
      expect(node.connectionType, 'relayed');
      expect(node.isPublicServer, isTrue);
      expect(node.featureFlags, {
        'is_public_server': true,
        'avoid_relay_data': false,
        'need_p2p': true,
      });
      expect(EasyTierNode.fromJson({}).featureFlags, isEmpty);
      expect(EasyTierNode.fromJson({}).isPublicServer, isFalse);
      expect(node.proxyCidrs, ['192.168.2.0/24']);
      expect(node.connections.first.rxBytes, 0);
      expect(node.connections.first.lossRate, 0.125);
      expect(node.connections.last.rxBytes, isNull);
      expect(node.connections.last.lossRate, isNull);
      expect(EasyTierNode.fromJson({}).connections, isEmpty);
    },
  );

  test('EasyTier targets and details use the shared overlay protocol', () {
    const target = OverlayNetworkTarget(
      name: 'mesh',
      kind: OverlayNetworkKind.easytier,
      level: OverlayNetworkDetailLevel.details,
    );
    expect(target.toJson(), {
      'name': 'mesh',
      'kind': 'easytier',
      'level': 'details',
    });
    final status = OverlayNetworkStatus.fromJson({
      'name': 'mesh',
      'kind': 'easytier',
      'state': 'connected',
      'network-name': 'private-mesh',
      'details': {
        'instance-id': 'instance-1',
        'dns-zone': 'mesh.internal',
        'local': {'hostname': 'local', 'ipv4': '10.1.0.1'},
        'peers': [
          {'hostname': 'remote', 'ipv4': '10.1.0.2', 'latency-ms': 23},
        ],
      },
    });
    expect(status.kind, OverlayNetworkKind.easytier);
    expect(status.state, OverlayNetworkState.connected);
    expect(status.hasDetails, isTrue);
    expect(status.easyTierDetails!.instanceId, 'instance-1');
    expect(status.easyTierDetails!.dnsZone, 'mesh.internal');
    expect(status.easyTierDetails!.local.ipv4, '10.1.0.1');
    expect(status.easyTierDetails!.peers.single.hostname, 'remote');
    expect(status.easyTierDetails!.peers.single.latencyMs, 23);
    expect(status.easyTierDetails!.local.latencyMs, 0);
    final summary = OverlayNetworkStatus.fromJson({
      'name': 'mesh',
      'kind': 'easytier',
      'state': 'error',
      'error': 'timeout',
    });
    final retained = summary.retainDetailsFrom(status);
    expect(retained.easyTierDetails, same(status.easyTierDetails));
    expect(retained.state, OverlayNetworkState.error);
    expect(retained.error, 'timeout');
    expect(
      status.retainDetailsFrom(summary).easyTierDetails,
      same(status.easyTierDetails),
    );
  });

  test('EasyTier empty details and absent summary details are distinct', () {
    final summary = OverlayNetworkStatus.fromJson({'kind': 'easytier'});
    expect(summary.hasDetails, isFalse);
    expect(summary.state, OverlayNetworkState.unknown);
    final status = OverlayNetworkStatus.fromJson({
      'kind': 'easytier',
      'details': {},
    });
    expect(status.hasDetails, isTrue);
    expect(status.easyTierDetails!.local.hostname, isEmpty);
    expect(status.easyTierDetails!.peers, isEmpty);
    final other = OverlayNetworkStatus.fromJson({'kind': 'zerotier'});
    expect(other.retainDetailsFrom(status).hasDetails, isFalse);
  });
}
