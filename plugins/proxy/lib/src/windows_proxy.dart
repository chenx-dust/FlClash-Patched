import 'dart:io';

/// WinINet rejects the whole list over one unbracketed IPv6 literal, CIDR
/// suffix or not, so the system proxy is not set at all. Zone IDs never appear
/// in the host WinINet matches against.
List<String> windowsBypassList(List<String> bypassDomain) {
  final entries = <String>{};
  for (final domain in bypassDomain) {
    final entry = domain.trim();
    if (entry.isEmpty) continue;
    entries.add(_bracketIPv6(entry));
  }
  return entries.toList();
}

String _bracketIPv6(String entry) {
  final prefixStart = entry.indexOf('/');
  final address = prefixStart < 0 ? entry : entry.substring(0, prefixStart);
  final prefix = prefixStart < 0 ? '' : entry.substring(prefixStart);
  final zoneStart = address.indexOf('%');
  final host = zoneStart < 0 ? address : address.substring(0, zoneStart);
  final isIPv6 =
      InternetAddress.tryParse(host)?.type == InternetAddressType.IPv6;
  return isIPv6 ? '[$host]$prefix' : entry;
}
