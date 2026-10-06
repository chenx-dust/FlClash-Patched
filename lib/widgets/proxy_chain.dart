import 'package:fl_clash/common/common.dart';
import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

import 'chip.dart';
import 'record.dart';

class ProxyChain extends StatefulWidget {
  final Iterable<String> chain;
  final Widget? leading;
  final bool showLeadingArrow;
  final bool hideTooMany;
  final ValueChanged<String>? onSelected;
  final bool Function(String)? canSelect;

  const ProxyChain({
    super.key,
    required this.chain,
    this.leading,
    this.showLeadingArrow = false,
    this.hideTooMany = true,
    this.onSelected,
    this.canSelect,
  });

  @override
  State<ProxyChain> createState() => _ProxyChainState();
}

class _ProxyChainState extends State<ProxyChain> {
  bool _expanded = false;

  @override
  void didUpdateWidget(covariant ProxyChain oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!listEquals(oldWidget.chain.toList(), widget.chain.toList())) {
      _expanded = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final onSelected = widget.onSelected;
    final chain = widget.chain.toList();
    final visible = !_expanded && chain.length > 2 && widget.hideTooMany
        ? <String?>[chain.first, null, chain.last]
        : chain;
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        ?widget.leading,
        for (final (index, name) in visible.indexed)
          Row(
            mainAxisSize: MainAxisSize.min,
            spacing: 6,
            children: [
              if (index > 0 ||
                  widget.leading != null ||
                  widget.showLeadingArrow)
                const RecordArrow(),
              Flexible(
                child: name == null
                    ? Tooltip(
                        message: context.appLocalizations.expand,
                        child: TonalChip(
                          label: '...',
                          color: colorScheme.secondaryContainer,
                          foregroundColor: colorScheme.onSecondaryContainer,
                          onPressed: () => setState(() => _expanded = true),
                        ),
                      )
                    : TonalChip(
                        label: name,
                        color: colorScheme.secondaryContainer,
                        foregroundColor: colorScheme.onSecondaryContainer,
                        onPressed:
                            onSelected == null ||
                                !(widget.canSelect?.call(name) ?? true)
                            ? null
                            : () => onSelected(name),
                      ),
              ),
            ],
          ),
      ],
    );
  }
}
