import 'dart:io';

import 'package:fl_clash/common/common.dart';
import 'package:material_ui/material_ui.dart';

class RuleQueryAdvanced extends StatelessWidget {
  final ExpansibleController controller;
  final Map<String, String> values;
  final bool enabled;

  const RuleQueryAdvanced({
    super.key,
    required this.controller,
    required this.values,
    required this.enabled,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.appLocalizations;
    final fields = [
      ('sourceIP', l10n.sourceIp, null),
      ('sourcePort', l10n.ruleQuerySourcePort, 65535),
      ('destinationIP', l10n.ruleQueryDestinationIP, null),
      ('process', l10n.process, null),
      ('processPath', l10n.ruleQueryProcessPath, null),
      ('uid', 'UID', 4294967295),
      ('inboundName', l10n.ruleQueryInboundName, null),
      ('inboundUser', l10n.ruleQueryInboundUser, null),
      ('sniffHost', l10n.ruleQuerySniffHost, null),
      ('dscp', 'DSCP', 63),
    ];
    return ExpansionTile(
      controller: controller,
      maintainState: true,
      shape: const Border(),
      title: Text(l10n.advancedConfig),
      children: [
        for (final (name, label, maximum) in fields)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: TextFormField(
              key: ValueKey(name),
              enabled: enabled,
              initialValue: values[name],
              decoration: InputDecoration(labelText: label),
              keyboardType: maximum == null
                  ? TextInputType.text
                  : TextInputType.number,
              onChanged: (value) => values[name] = value,
              validator: (value) {
                final text = value?.trim() ?? '';
                if (text.isEmpty) return null;
                if (name.endsWith('IP') &&
                    (InternetAddress.tryParse(text) == null ||
                        text.contains('%'))) {
                  return l10n.ruleQueryInvalidIP;
                }
                if (maximum != null) {
                  final number = int.tryParse(text);
                  if (number == null || number < 0 || number > maximum) {
                    return l10n.ruleQueryNumberRange(maximum);
                  }
                }
                return null;
              },
            ),
          ),
      ],
    );
  }
}
