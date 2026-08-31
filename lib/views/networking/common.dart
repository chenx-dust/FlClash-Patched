import 'dart:math';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:material_ui/material_ui.dart';

typedef OverlayNetworkDetailItem = ({String name, String value, bool copyable});

class OverlayNetworkLoginItem extends StatelessWidget {
  final String url;

  const OverlayNetworkLoginItem({super.key, required this.url});

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    return ListItem(
      leading: const Icon(Icons.login),
      title: Text(url),
      titleTextStyle: context.textTheme.bodyMedium?.copyWith(
        color: context.colorScheme.onSurfaceVariant,
      ),
      trailing: FilledButton.tonalIcon(
        onPressed: () {
          dialogs.openUrl(url);
        },
        icon: const Icon(Icons.open_in_new),
        label: Text(appLocalizations.signIn),
      ),
    );
  }
}

class OverlayNetworkDetailsDialog extends StatelessWidget {
  final String title;
  final List<OverlayNetworkDetailItem> items;

  const OverlayNetworkDetailsDialog({
    super.key,
    required this.title,
    required this.items,
  });

  Widget _buildItem(
    BuildContext context,
    OverlayNetworkDetailItem item,
    double nameWidth,
    TextStyle? nameStyle,
  ) {
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      title: Row(
        children: [
          SizedBox(
            width: nameWidth,
            child: TooltipText(
              text: Text(
                item.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: nameStyle,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: TooltipText(
              text: Text(
                item.value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.end,
                style: context.textTheme.bodyMedium?.toLight,
              ),
            ),
          ),
        ],
      ),
      trailing: item.copyable
          ? IconButton(
              tooltip: context.appLocalizations.copy,
              icon: const Icon(Icons.content_copy, size: 14),
              onPressed: () => copyText(context, item.value),
            )
          : null,
    );
  }

  double _getMaxNameWidth(TextStyle? nameStyle, BoxConstraints constraints) {
    double maxWidth = 0;
    for (final item in items) {
      final width = globalState.measure
          .computeTextSize(Text(item.name, style: nameStyle))
          .width;
      if (width > maxWidth) {
        maxWidth = width;
      }
    }
    return min(maxWidth + 18, constraints.maxWidth * 0.4);
  }

  @override
  Widget build(BuildContext context) {
    final nameStyle = context.textTheme.bodyMedium;
    return CommonDialog(
      title: title,
      maxWidth: 400,
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: Text(context.appLocalizations.confirm),
        ),
      ],
      child: Material(
        type: MaterialType.transparency,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final nameWidth = _getMaxNameWidth(nameStyle, constraints);
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var index = 0; index < items.length; index++) ...[
                  if (index > 0) const Divider(height: 0),
                  _buildItem(context, items[index], nameWidth, nameStyle),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}
