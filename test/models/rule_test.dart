import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:test/test.dart';

void main() {
  group('Rule parsing and serialization', () {
    const payloads = {
      'AND': '((DOMAIN,example.com),(NETWORK,TCP))',
      'OR': '((DOMAIN,example.com),(AND,((NETWORK,TCP),(DST-PORT,443))))',
      'NOT': '((DOMAIN,example.com))',
      'SUB-RULE': '(AND,((NETWORK,TCP),(DST-PORT,443)))',
      'DOMAIN-REGEX': r'^(src|no-resolve)[a-z]{1,3}\.example\.com$',
      'PROCESS-NAME-REGEX': r'^(app|helper){1,2}\(test\)$',
      'PROCESS-PATH-REGEX': r'^/apps/[(]test/app{1,2}$',
    };

    for (final entry in payloads.entries) {
      test('${entry.key} preserves its complete payload when editing', () {
        final raw = '${entry.key},${entry.value},DIRECT';
        final rule = Rule.parse(raw, id: 42);

        expect(rule.ruleAction.value, entry.key);
        expect(rule.content, entry.value);
        expect(rule.realTarget, 'DIRECT');
        expect(rule.src, isFalse);
        expect(rule.noResolve, isFalse);
        expect(rule.rawValue, raw);
        final edited = rule.ruleAction == RuleAction.SUB_RULE
            ? rule.copyWith(subRule: 'other')
            : rule.copyWith(ruleTarget: 'other');
        expect(edited.rawValue, '${entry.key},${entry.value},other');
        expect(Rule.parse(edited.rawValue, id: 42), edited);
      });
    }

    test('inner parameters do not become outer parameters', () {
      const raw =
          'AND,((IP-CIDR,10.0.0.0/8,src,no-resolve),(NETWORK,TCP)),DIRECT';
      final rule = Rule.parse(raw, id: 1);

      expect(rule.src, isFalse);
      expect(rule.noResolve, isFalse);
      expect(rule.rawValue, raw);
    });

    test('only trailing fields are interpreted as parameters', () {
      final rule = Rule.parse(
        ' RULE-SET , src-no-resolve , src , src , no-resolve ',
        id: 1,
      );

      expect(rule.ruleProvider, 'src-no-resolve');
      expect(rule.ruleTarget, 'src');
      expect(rule.src, isTrue);
      expect(rule.noResolve, isTrue);
      expect(rule.rawValue, 'RULE-SET,src-no-resolve,src,src,no-resolve');
    });

    for (final raw in [
      'DOMAIN,src.example.com,no-resolve',
      'PROCESS-PATH,/apps/(test)/app,DIRECT',
      'IP-CIDR,10.0.0.0/8,DIRECT,src,no-resolve',
      'MATCH,DIRECT',
    ]) {
      test('round-trips $raw', () {
        expect(Rule.parse(raw, id: 1).rawValue, raw);
      });
    }

    test('MATCH has no content', () {
      final rule = Rule.parse('MATCH,DIRECT', id: 1);

      expect(rule.content, isNull);
      expect(rule.ruleTarget, 'DIRECT');
    });

    test('configuration decoding preserves nested rules', () {
      const raw = 'AND,((DOMAIN,example.com),(NETWORK,TCP)),DIRECT';
      final config = ClashConfig.fromJson({
        'rules': [raw, 'MATCH,DIRECT'],
      });

      expect(config.rules.map((rule) => rule.rawValue), [raw, 'MATCH,DIRECT']);
    });
  });
}
