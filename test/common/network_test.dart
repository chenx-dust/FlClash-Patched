import 'dart:io';

import 'package:fl_clash/common/network.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeAddress implements InterfaceAddress {
  _FakeAddress(this.address, this.type);

  @override
  final String address;

  @override
  final InternetAddressType type;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeInterface implements NetworkInterface {
  _FakeInterface(this.name, this.addresses);

  @override
  final String name;

  @override
  final List<InterfaceAddress> addresses;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

InterfaceAddress _v4(String address) =>
    _FakeAddress(address, InternetAddressType.IPv4);

InterfaceAddress _v6(String address) =>
    _FakeAddress(address, InternetAddressType.IPv6);

void main() {
  tearDown(() {
    listNetworkInterfaces = ({bool includeLoopback = false}) =>
        NetworkInterface.list(includeLoopback: includeLoopback);
  });

  void listing(List<NetworkInterface> interfaces) {
    listNetworkInterfaces = ({bool includeLoopback = false}) async =>
        interfaces;
  }

  group('interfaceType', () {
    test('recognises physical interface names', () {
      for (final name in [
        'wlan0',
        'Wi-Fi',
        'WLAN1',
        'Ethernet 2',
        'en0',
        'enp3s0',
        'ens5',
        'enx001122',
        'eth0',
        'ETH1',
      ]) {
        expect(
          _FakeInterface(name, const []).interfaceType,
          NetworkInterfaceType.physical,
          reason: name,
        );
      }
    });

    test('recognises common virtual interface names', () {
      for (final name in [
        'FlClash',
        'Meta Tunnel',
        'tailscale0',
        'ZeroTier One',
        'netbird0',
        'easytier',
        'docker0',
        'tap0',
      ]) {
        expect(
          _FakeInterface(name, const []).interfaceType,
          NetworkInterfaceType.virtual,
          reason: name,
        );
      }
    });

    test('leaves unrecognised interface names as unknown', () {
      for (final name in ['utun3', 'lo0', 'ppp0', '']) {
        expect(
          _FakeInterface(name, const []).interfaceType,
          NetworkInterfaceType.unknown,
          reason: name,
        );
      }
    });
  });

  test('includesIPv4 only counts IPv4 addresses', () {
    expect(_FakeInterface('en1', [_v4('10.0.0.2')]).includesIPv4, isTrue);
    expect(_FakeInterface('en1', [_v6('fe80::1')]).includesIPv4, isFalse);
    expect(_FakeInterface('en1', const []).includesIPv4, isFalse);
  });

  test('isIPv4 reads the address type', () {
    expect(_v4('10.0.0.2').isIPv4, isTrue);
    expect(_v6('fe80::1').isIPv4, isFalse);
  });

  group('getLocalIpAddress', () {
    test('prefers a wireless interface over a wired one', () async {
      listing([
        _FakeInterface('utun0', [_v4('10.9.0.1')]),
        _FakeInterface('wlan0', [_v4('192.168.1.20')]),
      ]);

      expect(await getLocalIpAddress(), '192.168.1.20');
    });

    test(
      'prefers an IPv4-carrying interface when neither is wireless',
      () async {
        listing([
          _FakeInterface('utun0', [_v6('fe80::1')]),
          _FakeInterface('utun1', [_v4('10.9.0.1')]),
        ]);

        expect(await getLocalIpAddress(), '10.9.0.1');
      },
    );

    test('sorts physical, unknown, then virtual interfaces', () async {
      listing([
        _FakeInterface('tailscale0', [_v4('100.64.0.1')]),
        _FakeInterface('utun0', [_v4('10.9.0.1')]),
        _FakeInterface('en1', [_v4('192.168.1.20')]),
      ]);

      final interfaces = await getLocalNetworkInterfaces();

      expect(interfaces.map((interface) => interface.name), [
        'en1',
        'utun0',
        'tailscale0',
      ]);
    });

    test('prefers the IPv4 address inside the chosen interface', () async {
      listing([
        _FakeInterface('wlan0', [_v6('fe80::1'), _v4('192.168.1.20')]),
      ]);

      expect(await getLocalIpAddress(), '192.168.1.20');
    });

    test('skips an interface that carries no address at all', () async {
      listing([
        _FakeInterface('wlan0', const []),
        _FakeInterface('utun0', [_v4('10.9.0.1')]),
      ]);

      expect(await getLocalIpAddress(), '10.9.0.1');
    });

    test('returns an empty string when nothing is listed', () async {
      listing([]);

      expect(await getLocalIpAddress(), '');
    });

    test('never asks for the loopback interface', () async {
      bool? asked;
      listNetworkInterfaces = ({bool includeLoopback = false}) async {
        asked = includeLoopback;
        return [];
      };

      await getLocalIpAddress();

      expect(asked, isFalse);
    });
  });
}
