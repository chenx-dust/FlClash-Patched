import 'dart:io';

import 'package:flutter/foundation.dart';

import 'print.dart';

typedef NetworkInterfaceLister =
    Future<List<NetworkInterface>> Function({bool includeLoopback});

@visibleForTesting
NetworkInterfaceLister listNetworkInterfaces =
    ({bool includeLoopback = false}) =>
        NetworkInterface.list(includeLoopback: includeLoopback);

enum NetworkInterfaceType { physical, unknown, virtual }

extension NetworkInterfaceExt on NetworkInterface {
  bool get isWifi {
    final nameLowCase = name.toLowerCase();
    return nameLowCase.contains('wlan') ||
        nameLowCase.contains('wi-fi') ||
        nameLowCase == 'en0' ||
        nameLowCase == 'eth0';
  }

  NetworkInterfaceType get interfaceType {
    final nameLowCase = name.toLowerCase();
    if (nameLowCase.contains('wlan') ||
        nameLowCase.contains('wi-fi') ||
        nameLowCase.contains('ethernet') ||
        nameLowCase.startsWith(RegExp(r'^en\d+')) ||
        nameLowCase.startsWith(RegExp(r'^en(p|s|x)\d+')) ||
        nameLowCase.startsWith(RegExp(r'^eth\d+'))) {
      return NetworkInterfaceType.physical;
    }
    if (nameLowCase.contains('clash') ||
        nameLowCase.contains('meta') ||
        nameLowCase.contains('tailscale') ||
        nameLowCase.contains('zerotier') ||
        nameLowCase.contains('netbird') ||
        nameLowCase.contains('easytier') ||
        nameLowCase.contains('tunnel') ||
        nameLowCase.contains('docker') ||
        nameLowCase.contains('tap')) {
      return NetworkInterfaceType.virtual;
    }
    return NetworkInterfaceType.unknown;
  }

  bool get isPhysical {
    return interfaceType == NetworkInterfaceType.physical;
  }

  bool get includesIPv4 {
    return addresses.any((addr) => addr.isIPv4);
  }

  List<InternetAddress> get sortedAddresses {
    return List<InternetAddress>.from(addresses)..sort((a, b) {
      if (a.isIPv4 && !b.isIPv4) return -1;
      if (!a.isIPv4 && b.isIPv4) return 1;
      return 0;
    });
  }

  InternetAddress? get preferredAddress {
    final addresses = sortedAddresses;
    return addresses.isNotEmpty ? addresses.first : null;
  }
}

extension InternetAddressExt on InternetAddress {
  bool get isIPv4 {
    return type == InternetAddressType.IPv4;
  }
}

Future<String?> getLocalIpAddress() async {
  final interfaces = await getLocalNetworkInterfaces();
  return interfaces.isNotEmpty
      ? interfaces.first.preferredAddress?.address ?? ''
      : '';
}

Future<List<NetworkInterface>> getLocalNetworkInterfaces() async {
  final interfaces = await listNetworkInterfaces(includeLoopback: false)
    ..sort((a, b) {
      final typeCompare = a.interfaceType.index.compareTo(
        b.interfaceType.index,
      );
      if (typeCompare != 0) return typeCompare;
      if (a.isWifi && !b.isWifi) return -1;
      if (!a.isWifi && b.isWifi) return 1;
      if (a.includesIPv4 && !b.includesIPv4) return -1;
      if (!a.includesIPv4 && b.includesIPv4) return 1;
      return 0;
    });
  final sortedInterfaceNames = interfaces
      .map((interface) => '${interface.name}(${interface.interfaceType.name})')
      .join(', ');
  commonPrint.log('sorted network interfaces: $sortedInterfaceNames');
  return interfaces
      .where((interface) => interface.preferredAddress != null)
      .toList();
}
