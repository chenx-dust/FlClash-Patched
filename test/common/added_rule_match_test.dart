import 'package:fl_clash/common/added_rule_match.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const added = Rule(content: 'example.com', ruleTarget: 'DIRECT');
  const core = CoreRule(
    index: 0,
    type: 'Domain',
    payload: 'example.com',
    proxy: 'DIRECT',
  );

  test('requires position, type, content and target to match', () {
    expect(matchesAddedRule(core, [added]), isTrue);
    for (final other in [
      core.copyWith(index: -1),
      core.copyWith(index: 1),
      core.copyWith(type: 'DomainSuffix'),
      core.copyWith(payload: 'other.com'),
      core.copyWith(proxy: 'REJECT'),
    ]) {
      expect(matchesAddedRule(other, [added]), isFalse, reason: '$other');
    }
    expect(matchesAddedRule(core, []), isFalse);
    expect(matchesAddedRule(core.copyWith(disabled: true), [added]), isTrue);
  });

  test('resolves MATCH without accepting an arbitrary target', () {
    final placeholder = added.copyWith(ruleTarget: 'MATCH');
    expect(matchesAddedRule(core, [placeholder]), isFalse);
    expect(
      matchesAddedRule(core, [placeholder], matchTarget: 'DIRECT'),
      isTrue,
    );
    expect(
      matchesAddedRule(core, [placeholder], matchTarget: 'REJECT'),
      isFalse,
    );
  });

  test(
    'normalizes domain casing without folding regex or process payloads',
    () {
      expect(
        matchesAddedRule(core, [added.copyWith(content: ' EXAMPLE.COM ')]),
        isTrue,
      );
      for (final (action, type) in [
        (RuleAction.DOMAIN_REGEX, 'DomainRegex'),
        (RuleAction.PROCESS_PATH, 'ProcessPath'),
      ]) {
        expect(
          matchesAddedRule(core.copyWith(type: type), [
            added.copyWith(ruleAction: action, content: 'EXAMPLE.COM'),
          ]),
          isFalse,
        );
      }
    },
  );

  test(
    'handles IPv6 aliases and source flags without broadening the prefix',
    () {
      final cidr = added.copyWith(
        ruleAction: RuleAction.IP_CIDR6,
        content: '2001:0db8:0000:0000:0000:0000:0000:0000/32',
        src: true,
        noResolve: true,
      );
      final runtime = core.copyWith(
        type: 'SrcIPCIDR',
        payload: '2001:db8::/32',
      );
      expect(matchesAddedRule(runtime, [cidr]), isTrue);
      expect(
        matchesAddedRule(runtime.copyWith(type: 'IPCIDR'), [cidr]),
        isFalse,
      );
      expect(
        matchesAddedRule(runtime.copyWith(payload: '2001:db8::/64'), [cidr]),
        isFalse,
      );
      expect(
        matchesAddedRule(runtime.copyWith(payload: '2001:db9::/32'), [cidr]),
        isFalse,
      );
    },
  );
}
