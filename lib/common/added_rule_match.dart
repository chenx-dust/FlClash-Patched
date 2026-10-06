import 'dart:io';

import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';

bool matchesAddedRule(
  CoreRule rule,
  List<Rule> addedRules, {
  String? matchTarget,
}) {
  if (rule.index < 0 || rule.index >= addedRules.length) return false;
  final added = addedRules[rule.index];
  final target = added.realTarget?.trim();
  final resolvedTarget = target?.toUpperCase() == 'MATCH'
      ? matchTarget
      : target;
  if (resolvedTarget == null || rule.proxy != resolvedTarget) return false;

  var type = switch (added.ruleAction) {
    RuleAction.IP_CIDR6 => 'IPCIDR',
    RuleAction.SUB_RULE => 'SUBRULES',
    _ => added.ruleAction.value.replaceAll('-', ''),
  };
  if (added.src &&
      const {'GEOIP', 'IPASN', 'IPCIDR', 'IPSUFFIX'}.contains(type)) {
    type = 'SRC$type';
  }
  if (rule.type.toUpperCase() != type) return false;

  final payload = (added.realContent ?? '')
      .split(',')
      .map((part) => part.trim())
      .join(',');
  return _normalizePayload(type, payload) ==
      _normalizePayload(type, rule.payload);
}

String _normalizePayload(String type, String payload) {
  switch (type) {
    case 'DOMAIN':
    case 'DOMAINSUFFIX':
    case 'DOMAINKEYWORD':
    case 'DOMAINWILDCARD':
    case 'GEOIP':
    case 'SRCGEOIP':
    case 'NETWORK':
    case 'INTYPE':
      return payload.toLowerCase();
    case 'IPCIDR':
    case 'SRCIPCIDR':
      final parts = payload.split('/');
      if (parts.length != 2) return payload;
      final address = InternetAddress.tryParse(parts[0]);
      final prefix = int.tryParse(parts[1]);
      if (address == null || prefix == null) return payload;
      return '${address.rawAddress.join('.')}/$prefix';
    default:
      return payload;
  }
}
