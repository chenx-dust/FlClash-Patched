import 'package:fl_clash/common/clipboard.dart' as clipboard;
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:material_ui/material_ui.dart';

import 'chip.dart';
import 'list.dart';

class RecordTextStyles {
  final TextStyle? primary;
  final TextStyle? secondary;
  final TextStyle? muted;

  const RecordTextStyles._({this.primary, this.secondary, this.muted});

  factory RecordTextStyles.of(BuildContext context) {
    final colorScheme = context.colorScheme;
    final textTheme = context.textTheme;
    final secondary = textTheme.bodySmall?.copyWith(
      color: colorScheme.onSurfaceVariant,
    );
    return RecordTextStyles._(
      primary: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurface),
      secondary: secondary,
      muted: secondary?.copyWith(color: colorScheme.outline),
    );
  }
}

class RecordListItem extends StatelessWidget {
  final Widget header;
  final Widget body;
  final Widget? trailing;
  final RecordTone tone;
  final VoidCallback? onTap;

  const RecordListItem({
    super.key,
    required this.header,
    required this.body,
    this.trailing,
    this.tone = RecordTone.neutral,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final trailing = this.trailing;
    final item = ListItem(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      minVerticalPadding: 0,
      minTileHeight: 0,
      horizontalTitleGap: 12,
      color: tone.tintColor(context),
      onTap: onTap,
      title: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          header,
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: trailing == null
                ? body
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(child: body),
                      trailing,
                    ],
                  ),
          ),
        ],
      ),
    );
    final accentColor = tone.accentColor(context);
    if (accentColor == null) {
      return item;
    }
    return DecoratedBox(
      position: DecorationPosition.foreground,
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: accentColor, width: 3)),
      ),
      child: item,
    );
  }
}

class RecordHeader extends StatelessWidget {
  final List<Widget> children;
  final Widget? trailing;

  const RecordHeader({super.key, required this.children, this.trailing});

  @override
  Widget build(BuildContext context) {
    final trailing = this.trailing;
    return DefaultTextStyle.merge(
      style: context.textTheme.labelMedium?.copyWith(
        color: context.colorScheme.onSurfaceVariant,
        fontWeight: FontWeight.w400,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 4,
              children: children,
            ),
          ),
          if (trailing != null) const SizedBox(width: 12),
          ?trailing,
        ],
      ),
    );
  }
}

class RecordLabel extends StatelessWidget {
  final String label;
  final RecordTone tone;
  final VoidCallback? onPressed;

  const RecordLabel({
    super.key,
    required this.label,
    this.tone = RecordTone.neutral,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return TonalChip(
      label: label,
      color: tone.labelContainerColor(context),
      foregroundColor: tone.labelColor(context),
      onPressed: onPressed,
    );
  }
}

class RecordTimestamp extends StatelessWidget {
  final String dateTime;

  const RecordTimestamp(this.dateTime, {super.key});

  @override
  Widget build(BuildContext context) {
    final split = dateTime.lastIndexOf(' ');
    return Text.rich(
      TextSpan(
        children: [
          if (split > 0)
            TextSpan(
              text: dateTime.substring(0, split + 1),
              style: TextStyle(color: context.colorScheme.outline),
            ),
          TextSpan(text: split > 0 ? dateTime.substring(split + 1) : dateTime),
        ],
      ),
      maxLines: 1,
    );
  }
}

class RecordArrow extends StatelessWidget {
  const RecordArrow({super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      '→',
      style: RecordTextStyles.of(context).muted?.toJetBrainsMono,
    );
  }
}

class DetailRow extends StatelessWidget {
  final String title;
  final Widget? value;
  final String? copyText;

  const DetailRow({super.key, required this.title, this.value, this.copyText});

  DetailRow.text({super.key, required this.title, required String value})
    : value = Text(value),
      copyText = value;

  @override
  Widget build(BuildContext context) {
    final value = this.value;
    final copyText = this.copyText;
    return DecorationListItem(
      onPressed: copyText == null
          ? null
          : () => clipboard.copyText(context, copyText),
      title: value == null
          ? Text(title)
          : Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              spacing: 20,
              children: [
                Text(title),
                Expanded(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: DefaultTextStyle.merge(
                      textAlign: TextAlign.end,
                      style: context.textTheme.bodyMedium?.copyWith(
                        color: context.colorScheme.onSurfaceVariant,
                      ),
                      child: value,
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
