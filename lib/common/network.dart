import 'dart:io';

enum NetworkInterfaceType { physical, unknown, virtual }

extension NetworkInterfaceExt on NetworkInterface {
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
