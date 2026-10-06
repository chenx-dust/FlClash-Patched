import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:material_ui/material_ui.dart';

import 'proxy_chain.dart';
import 'query_advanced.dart';

class RuleQueryDialog extends StatefulWidget {
  final Future<RuleQuery> Function(RuleQueryParams params) onQuery;

  const RuleQueryDialog({super.key, required this.onQuery});

  @override
  State<RuleQueryDialog> createState() => _RuleQueryDialogState();
}

class _RuleQueryDialogState extends State<RuleQueryDialog> {
  final _formKey = GlobalKey<FormState>();
  final _targetController = TextEditingController();
  final _portController = TextEditingController(text: '443');
  final _advancedController = ExpansibleController();
  final _advancedValues = <String, String>{};
  Network _network = Network.tcp;
  bool _querying = false;
  String? _error;
  RuleQuery? _result;

  @override
  void dispose() {
    _targetController.dispose();
    _portController.dispose();
    _advancedController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_querying) return;
    if (!(_formKey.currentState?.validate() ?? false)) {
      if (_advancedValues.values.any((value) => value.trim().isNotEmpty)) {
        _advancedController.expand();
      }
      return;
    }
    String? value(String name) {
      final text = _advancedValues[name]?.trim();
      return text == null || text.isEmpty ? null : text;
    }

    setState(() {
      _querying = true;
      _error = null;
      _result = null;
    });
    try {
      final result = await widget.onQuery(
        RuleQueryParams(
          target: _targetController.text.trim(),
          port: int.parse(_portController.text.trim()),
          network: _network,
          sourceIP: value('sourceIP'),
          sourcePort: int.tryParse(value('sourcePort') ?? ''),
          destinationIP: value('destinationIP'),
          process: value('process'),
          processPath: value('processPath'),
          uid: int.tryParse(value('uid') ?? ''),
          inboundName: value('inboundName'),
          inboundUser: value('inboundUser'),
          sniffHost: value('sniffHost'),
          dscp: int.tryParse(value('dscp') ?? ''),
        ),
      );
      if (mounted) _result = result;
    } catch (error) {
      if (mounted) {
        _error = userFacingErrorMessage(error, context.appLocalizations);
      }
    } finally {
      if (mounted) setState(() => _querying = false);
    }
  }

  String _ruleText(RuleQuery result) {
    final rule = result.rule;
    final rulePayload = result.rulePayload;
    if (rulePayload.isNotEmpty) {
      return '$rule($rulePayload)';
    } else {
      return rule;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.appLocalizations;
    final result = _result;
    return CommonDialog(
      title: l10n.queryRule,
      maxWidth: 360,
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.close),
        ),
        TextButton(
          onPressed: _querying ? null : _submit,
          child: _querying
              ? const SizedBox.square(
                  dimension: 18,
                  child: CommonCircleLoading(),
                )
              : Text(l10n.query),
        ),
      ],
      child: Form(
        key: _formKey,
        child: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                spacing: 16,
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    autofocus: true,
                    enabled: !_querying,
                    controller: _targetController,
                    keyboardType: TextInputType.url,
                    inputFormatters: TextInputLimits.limit(
                      TextInputLimits.domain,
                    ),
                    decoration: InputDecoration(
                      labelText: l10n.ruleQueryTarget,
                    ),
                    onFieldSubmitted: (_) => _submit(),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? l10n.emptyTip(l10n.ruleQueryTarget)
                        : null,
                  ),
                  TextFormField(
                    enabled: !_querying,
                    controller: _portController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(labelText: l10n.port),
                    onFieldSubmitted: (_) => _submit(),
                    validator: (value) {
                      final port = int.tryParse(value?.trim() ?? '');
                      return port == null || port < 1 || port > 65535
                          ? l10n.ruleQueryPortInvalid
                          : null;
                    },
                  ),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final network in Network.values)
                        ChoiceChip(
                          label: Text(network.name.toUpperCase()),
                          selected: _network == network,
                          onSelected: _querying
                              ? null
                              : (_) => setState(() => _network = network),
                        ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              RuleQueryAdvanced(
                controller: _advancedController,
                values: _advancedValues,
                enabled: !_querying,
              ),
              if (_error != null || result != null) ...[
                const Divider(),
                const SizedBox(height: 8),
              ],
              if (_error != null)
                Text(
                  _error!,
                  style: TextStyle(color: context.colorScheme.error),
                ),
              if (result != null)
                Column(
                  spacing: 16,
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: 4,
                      children: [
                        Text(
                          l10n.proxyChains,
                          style: context.textTheme.labelMedium,
                        ),
                        RuleProxyChain(
                          target: result.proxy,
                          hideTooMany: false,
                          leading: result.rule.isNotEmpty
                              ? Text(
                                  _ruleText(result),
                                  style: context.textTheme.labelMedium,
                                )
                              : null,
                          onNavigate: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                    for (final (label, value) in [
                      (
                        l10n.destination,
                        result.target.contains(':')
                            ? '[${result.target}]:${result.port}'
                            : '${result.target}:${result.port}',
                      ),
                      (l10n.network, result.network.name.toUpperCase()),
                      (l10n.mode, result.mode.label),
                      (
                        l10n.rule,
                        result.rule.isEmpty
                            ? l10n.ruleQueryNoMatch
                            : _ruleText(result),
                      ),
                      if (result.ip.isNotEmpty) ('IP', result.ip),
                    ])
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(label, style: context.textTheme.labelMedium),
                          SelectableText(value),
                        ],
                      ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
