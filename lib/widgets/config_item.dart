import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod/misc.dart' show ProviderListenable;

import 'input.dart';
import 'list.dart';

export 'package:riverpod/misc.dart' show ProviderListenable;

typedef ConfigLabel = String Function(AppLocalizations appLocalizations);

typedef ConfigWriter<T> = void Function(WidgetRef ref, T value);

abstract class _ConfigItem<T> extends ConsumerWidget {
  const _ConfigItem({
    super.key,
    required this.selector,
    required this.title,
    required this.onChanged,
    this.subtitle,
    this.leading,
  });

  final ProviderListenable<T> selector;
  final ConfigLabel title;
  final ConfigLabel? subtitle;
  final ConfigWriter<T> onChanged;
  final Widget? leading;

  Widget buildItem(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations appLocalizations,
    T value,
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appLocalizations = context.appLocalizations;
    return buildItem(context, ref, appLocalizations, ref.watch(selector));
  }

  Widget? buildSubtitle(AppLocalizations appLocalizations) {
    final subtitle = this.subtitle;
    return subtitle == null ? null : Text(subtitle(appLocalizations));
  }
}

class ConfigToggleItem extends _ConfigItem<bool> {
  const ConfigToggleItem({
    super.key,
    required super.selector,
    required super.title,
    required super.onChanged,
    super.subtitle,
    super.leading,
  });

  @override
  Widget buildItem(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations appLocalizations,
    bool value,
  ) {
    return ListItem.toggle(
      leading: leading,
      title: Text(title(appLocalizations)),
      subtitle: buildSubtitle(appLocalizations),
      value: value,
      onChanged: (value) => onChanged(ref, value),
    );
  }
}

class ConfigOptionsItem<T> extends _ConfigItem<T> {
  const ConfigOptionsItem({
    super.key,
    required super.selector,
    required super.title,
    required super.onChanged,
    required this.options,
    required this.textBuilder,
    super.subtitle,
    super.leading,
  });

  final List<T> options;
  final String Function(T value) textBuilder;

  @override
  Widget buildItem(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations appLocalizations,
    T value,
  ) {
    return ListItem<T>.options(
      leading: leading,
      title: Text(title(appLocalizations)),
      subtitle: Text(subtitle?.call(appLocalizations) ?? textBuilder(value)),
      dialogTitle: title(appLocalizations),
      options: options,
      value: value,
      textBuilder: textBuilder,
      onChanged: (value) {
        if (value == null) {
          return;
        }
        onChanged(ref, value);
      },
    );
  }
}

class ConfigTextItem extends _ConfigItem<String> {
  const ConfigTextItem({
    super.key,
    required super.selector,
    required super.title,
    required super.onChanged,
    this.maxLength,
    this.keyboardType,
    this.validator,
    this.normalize,
    this.showValueAsSubtitle = true,
    super.subtitle,
    super.leading,
  });

  final int? maxLength;
  final TextInputType? keyboardType;
  final String? Function(String? value, AppLocalizations appLocalizations)?
  validator;
  final String Function(String value)? normalize;
  final bool showValueAsSubtitle;

  String? _normalize(String? value) {
    if (value == null) {
      return null;
    }
    return normalize?.call(value) ?? value;
  }

  @override
  Widget buildItem(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations appLocalizations,
    String value,
  ) {
    final label = title(appLocalizations);
    final validator = this.validator;
    return ListItem.input(
      leading: leading,
      title: Text(label),
      subtitle: showValueAsSubtitle
          ? Text(value)
          : buildSubtitle(appLocalizations),
      dialogTitle: label,
      value: value,
      maxLength: maxLength,
      keyboardType: keyboardType,
      validator: (value) {
        final normalized = _normalize(value);
        if (normalized == null || normalized.isEmpty) {
          return appLocalizations.emptyTip(label);
        }
        return validator?.call(normalized, appLocalizations);
      },
      onChanged: (value) {
        final normalized = _normalize(value);
        if (normalized == null) {
          return;
        }
        onChanged(ref, normalized);
      },
    );
  }
}

class ConfigListInputItem extends _ConfigItem<List<String>> {
  const ConfigListInputItem({
    super.key,
    required super.selector,
    required super.title,
    required super.onChanged,
    this.itemMaxLength,
    this.maxWidth,
    this.itemValidator,
    super.subtitle,
    super.leading,
  });

  final int? itemMaxLength;
  final double? maxWidth;
  final String? Function(String item, AppLocalizations appLocalizations)?
  itemValidator;

  @override
  Widget buildItem(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations appLocalizations,
    List<String> value,
  ) {
    final label = title(appLocalizations);
    final itemValidator = this.itemValidator;
    return ListItem.open(
      leading: leading,
      title: Text(label),
      subtitle: buildSubtitle(appLocalizations),
      blur: false,
      maxWidth: maxWidth,
      widget: ListInputPage(
        title: label,
        items: value,
        itemMaxLength: itemMaxLength,
        itemValidator: itemValidator == null
            ? null
            : (item) => itemValidator(item, appLocalizations),
        titleBuilder: (item) => Text(item),
      ),
      onChanged: (items) {
        if (items is! List) return;
        onChanged(ref, List<String>.from(items));
      },
    );
  }
}

enum ConfigOverride { follow, enabled, disabled }

class ConfigOverrideToggleItem extends _ConfigItem<bool?> {
  const ConfigOverrideToggleItem({
    super.key,
    required super.selector,
    required super.title,
    required super.onChanged,
    super.leading,
  });

  @override
  Widget buildItem(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations appLocalizations,
    bool? value,
  ) {
    final current = switch (value) {
      null => ConfigOverride.follow,
      true => ConfigOverride.enabled,
      false => ConfigOverride.disabled,
    };
    String textBuilder(ConfigOverride option) => switch (option) {
      ConfigOverride.follow => appLocalizations.followProfile,
      ConfigOverride.enabled => appLocalizations.enabledText,
      ConfigOverride.disabled => appLocalizations.disabledText,
    };
    final label = title(appLocalizations);
    return ListItem<ConfigOverride>.options(
      leading: leading,
      title: Text(label),
      subtitle: Text(textBuilder(current)),
      dialogTitle: label,
      options: ConfigOverride.values,
      value: current,
      textBuilder: textBuilder,
      onChanged: (next) {
        if (next == null) return;
        onChanged(ref, switch (next) {
          ConfigOverride.follow => null,
          ConfigOverride.enabled => true,
          ConfigOverride.disabled => false,
        });
      },
    );
  }
}

class ConfigOverrideNumberItem extends _ConfigItem<int?> {
  const ConfigOverrideNumberItem({
    super.key,
    required super.selector,
    required super.title,
    required super.onChanged,
    required this.max,
    this.suffix,
    super.leading,
  });

  final int max;
  final ConfigLabel? suffix;

  @override
  Widget buildItem(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations appLocalizations,
    int? value,
  ) {
    final label = title(appLocalizations);
    return ListItem.input(
      leading: leading,
      title: Text(label),
      subtitle: Text(value?.toString() ?? appLocalizations.followProfile),
      dialogTitle: label,
      value: value?.toString() ?? '',
      resetValue: '',
      suffixText: suffix?.call(appLocalizations),
      maxLength: TextInputLimits.number,
      keyboardType: TextInputType.number,
      validator: (text) {
        final trimmed = text?.trim() ?? '';
        if (trimmed.isEmpty) return null;
        final parsed = int.tryParse(trimmed);
        return parsed == null || parsed < 0 || parsed > max
            ? appLocalizations.numberTip(label)
            : null;
      },
      onChanged: (text) {
        if (text == null) return;
        final trimmed = text.trim();
        final parsed = int.tryParse(trimmed);
        if (trimmed.isNotEmpty && parsed == null) return;
        onChanged(ref, parsed);
      },
    );
  }
}

class ConfigOverrideListItem extends _ConfigItem<List<String>?> {
  const ConfigOverrideListItem({
    super.key,
    required super.selector,
    required super.title,
    required super.onChanged,
    this.itemMaxLength,
    this.itemValidator,
    super.leading,
  });

  final int? itemMaxLength;
  final String? Function(
    String item,
    String label,
    AppLocalizations appLocalizations,
  )?
  itemValidator;

  @override
  Widget buildItem(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations appLocalizations,
    List<String>? value,
  ) {
    final label = title(appLocalizations);
    final itemValidator = this.itemValidator;
    return ListItem.open(
      leading: leading,
      title: Text(label),
      subtitle: Text(
        value == null ? appLocalizations.followProfile : value.join(', '),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      blur: false,
      maxWidth: 360,
      widget: ListInputPage(
        title: label,
        items: value ?? const [],
        itemMaxLength: itemMaxLength,
        itemValidator: itemValidator == null
            ? null
            : (item) => itemValidator(item, label, appLocalizations),
        titleBuilder: (item) => Text(item),
      ),
      onChanged: (items) {
        if (items is! List) return;
        final next = List<String>.from(items);
        onChanged(ref, next.isEmpty ? null : next);
      },
    );
  }
}
