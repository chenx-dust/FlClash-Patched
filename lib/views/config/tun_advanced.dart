import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/config.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const _maxPort = 65535;
const _maxUint32 = 0xFFFFFFFF;

ProviderListenable<T> _tun<T>(T Function(Tun tun) read) =>
    patchClashConfigProvider.select((state) => read(state.tun));

ConfigWriter<T> _tunWriter<T>(Tun Function(Tun tun, T value) write) =>
    (ref, value) => ref
        .read(patchClashConfigProvider.notifier)
        .update((state) => state.copyWith(tun: write(state.tun, value)));

String? _numberError(
  String value,
  String label,
  int max,
  AppLocalizations appLocalizations,
) {
  final parsed = int.tryParse(value);
  return parsed == null || parsed < 0 || parsed > max
      ? appLocalizations.numberTip(label)
      : null;
}

String? _rangeError(
  String value,
  String label,
  int max,
  AppLocalizations appLocalizations,
) {
  final bounds = value.split(':');
  if (bounds.length != 2 ||
      bounds.any(
        (bound) => _numberError(bound, label, max, appLocalizations) != null,
      )) {
    return appLocalizations.numberTip(label);
  }
  return null;
}

ConfigOverrideToggleItem _toggle({
  required ConfigLabel title,
  required bool? Function(Tun tun) read,
  required Tun Function(Tun tun, bool? value) write,
}) => ConfigOverrideToggleItem(
  title: title,
  selector: _tun(read),
  onChanged: _tunWriter(write),
);

ConfigOverrideNumberItem _number({
  required ConfigLabel title,
  required int? Function(Tun tun) read,
  required Tun Function(Tun tun, int? value) write,
  int max = _maxUint32,
  ConfigLabel? suffix,
}) => ConfigOverrideNumberItem(
  title: title,
  max: max,
  suffix: suffix,
  selector: _tun(read),
  onChanged: _tunWriter(write),
);

ConfigOverrideListItem _list({
  required ConfigLabel title,
  required List<String>? Function(Tun tun) read,
  required Tun Function(Tun tun, List<String>? value) write,
}) => ConfigOverrideListItem(
  title: title,
  itemMaxLength: TextInputLimits.cidr,
  selector: _tun(read),
  onChanged: _tunWriter(write),
);

ConfigOverrideListItem _numberList({
  required ConfigLabel title,
  required List<int>? Function(Tun tun) read,
  required Tun Function(Tun tun, List<int>? value) write,
  int max = _maxUint32,
}) => ConfigOverrideListItem(
  title: title,
  itemMaxLength: TextInputLimits.number,
  itemValidator: (item, label, l) => _numberError(item, label, max, l),
  selector: _tun((tun) => read(tun)?.map((item) => '$item').toList()),
  onChanged: _tunWriter(
    (tun, List<String>? value) => write(tun, value?.map(int.parse).toList()),
  ),
);

ConfigOverrideListItem _rangeList({
  required ConfigLabel title,
  required List<String>? Function(Tun tun) read,
  required Tun Function(Tun tun, List<String>? value) write,
  int max = _maxUint32,
}) => ConfigOverrideListItem(
  title: title,
  itemMaxLength: TextInputLimits.cidr,
  itemValidator: (item, label, l) => _rangeError(item, label, max, l),
  selector: _tun(read),
  onChanged: _tunWriter(write),
);

List<Widget> tunAdvancedGeneralItems() => [
  _toggle(
    title: (l) => l.tunAutoDetectInterface,
    read: (tun) => tun.autoDetectInterface,
    write: (tun, value) => tun.copyWith(autoDetectInterface: value),
  ),
  _number(
    title: (l) => l.tunUdpTimeout,
    suffix: (l) => l.seconds,
    read: (tun) => tun.udpTimeout,
    write: (tun, value) => tun.copyWith(udpTimeout: value),
  ),
  _number(
    title: (l) => l.tunIcmpTimeout,
    suffix: (l) => l.seconds,
    read: (tun) => tun.icmpTimeout,
    write: (tun, value) => tun.copyWith(icmpTimeout: value),
  ),
  _list(
    title: (l) => l.tunInet6Address,
    read: (tun) => tun.inet6Address,
    write: (tun, value) => tun.copyWith(inet6Address: value),
  ),
  _list(
    title: (l) => l.tunLoopbackAddress,
    read: (tun) => tun.loopbackAddress,
    write: (tun, value) => tun.copyWith(loopbackAddress: value),
  ),
  _list(
    title: (l) => l.tunRouteExcludeAddress,
    read: (tun) => tun.routeExcludeAddress,
    write: (tun, value) => tun.copyWith(routeExcludeAddress: value),
  ),
];

List<Widget> tunAdvancedFilterItems() => [
  _list(
    title: (l) => l.tunIncludeInterface,
    read: (tun) => tun.includeInterface,
    write: (tun, value) => tun.copyWith(includeInterface: value),
  ),
  _list(
    title: (l) => l.tunExcludeInterface,
    read: (tun) => tun.excludeInterface,
    write: (tun, value) => tun.copyWith(excludeInterface: value),
  ),
  _numberList(
    title: (l) => l.tunIncludeUid,
    read: (tun) => tun.includeUid,
    write: (tun, value) => tun.copyWith(includeUid: value),
  ),
  _rangeList(
    title: (l) => l.tunIncludeUidRange,
    read: (tun) => tun.includeUidRange,
    write: (tun, value) => tun.copyWith(includeUidRange: value),
  ),
  _numberList(
    title: (l) => l.tunExcludeUid,
    read: (tun) => tun.excludeUid,
    write: (tun, value) => tun.copyWith(excludeUid: value),
  ),
  _rangeList(
    title: (l) => l.tunExcludeUidRange,
    read: (tun) => tun.excludeUidRange,
    write: (tun, value) => tun.copyWith(excludeUidRange: value),
  ),
  _numberList(
    title: (l) => l.tunExcludeSrcPort,
    max: _maxPort,
    read: (tun) => tun.excludeSrcPort,
    write: (tun, value) => tun.copyWith(excludeSrcPort: value),
  ),
  _rangeList(
    title: (l) => l.tunExcludeSrcPortRange,
    max: _maxPort,
    read: (tun) => tun.excludeSrcPortRange,
    write: (tun, value) => tun.copyWith(excludeSrcPortRange: value),
  ),
  _numberList(
    title: (l) => l.tunExcludeDstPort,
    max: _maxPort,
    read: (tun) => tun.excludeDstPort,
    write: (tun, value) => tun.copyWith(excludeDstPort: value),
  ),
  _rangeList(
    title: (l) => l.tunExcludeDstPortRange,
    max: _maxPort,
    read: (tun) => tun.excludeDstPortRange,
    write: (tun, value) => tun.copyWith(excludeDstPortRange: value),
  ),
  _list(
    title: (l) => l.tunIncludeMacAddress,
    read: (tun) => tun.includeMacAddress,
    write: (tun, value) => tun.copyWith(includeMacAddress: value),
  ),
  _list(
    title: (l) => l.tunExcludeMacAddress,
    read: (tun) => tun.excludeMacAddress,
    write: (tun, value) => tun.copyWith(excludeMacAddress: value),
  ),
];

List<Widget> tunAdvancedLinuxItems() => [
  _list(
    title: (l) => l.tunRouteAddressSet,
    read: (tun) => tun.routeAddressSet,
    write: (tun, value) => tun.copyWith(routeAddressSet: value),
  ),
  _list(
    title: (l) => l.tunRouteExcludeAddressSet,
    read: (tun) => tun.routeExcludeAddressSet,
    write: (tun, value) => tun.copyWith(routeExcludeAddressSet: value),
  ),
  _toggle(
    title: (l) => 'GSO',
    read: (tun) => tun.gso,
    write: (tun, value) => tun.copyWith(gso: value),
  ),
  _number(
    title: (l) => l.tunGsoMaxSize,
    read: (tun) => tun.gsoMaxSize,
    write: (tun, value) => tun.copyWith(gsoMaxSize: value),
  ),
  _toggle(
    title: (l) => l.tunMultiQueue,
    read: (tun) => tun.multiQueue,
    write: (tun, value) => tun.copyWith(multiQueue: value),
  ),
  _toggle(
    title: (l) => l.tunAutoRedirect,
    read: (tun) => tun.autoRedirect,
    write: (tun, value) => tun.copyWith(autoRedirect: value),
  ),
  _number(
    title: (l) => l.tunAutoRedirectInputMark,
    read: (tun) => tun.autoRedirectInputMark,
    write: (tun, value) => tun.copyWith(autoRedirectInputMark: value),
  ),
  _number(
    title: (l) => l.tunAutoRedirectOutputMark,
    read: (tun) => tun.autoRedirectOutputMark,
    write: (tun, value) => tun.copyWith(autoRedirectOutputMark: value),
  ),
  _number(
    title: (l) => l.tunAutoRedirectFallbackRuleIndex,
    read: (tun) => tun.autoRedirectIproute2FallbackRuleIndex,
    write: (tun, value) =>
        tun.copyWith(autoRedirectIproute2FallbackRuleIndex: value),
  ),
  _number(
    title: (l) => l.tunIproute2TableIndex,
    read: (tun) => tun.iproute2TableIndex,
    write: (tun, value) => tun.copyWith(iproute2TableIndex: value),
  ),
  _number(
    title: (l) => l.tunIproute2RuleIndex,
    read: (tun) => tun.iproute2RuleIndex,
    write: (tun, value) => tun.copyWith(iproute2RuleIndex: value),
  ),
];

class TunAdvancedListView extends StatelessWidget {
  const TunAdvancedListView({super.key, this.isLinux});

  final bool? isLinux;

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    final isLinux = this.isLinux ?? system.isLinux;
    return ListView(
      padding: sectionPagePadding,
      children: [
        generateSectionV3(
          title: appLocalizations.general,
          isFirst: true,
          items: tunAdvancedGeneralItems(),
        ),
        if (isLinux) ...[
          generateSectionV3(
            title: appLocalizations.tunFilter,
            items: tunAdvancedFilterItems(),
          ),
          generateSectionV3(title: 'Linux', items: tunAdvancedLinuxItems()),
        ],
      ],
    );
  }
}

class TunAdvancedResetButton extends ConsumerWidget {
  const TunAdvancedResetButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.appLocalizations;
    return IconButton(
      tooltip: l.reset,
      onPressed: () async {
        final confirmed = await dialogs.showMessage(
          title: l.reset,
          message: TextSpan(text: l.resetTip),
        );
        if (confirmed != true) return;
        ref
            .read(patchClashConfigProvider.notifier)
            .update(
              (state) =>
                  state.copyWith(tun: state.tun.withoutProfileOverrides()),
            );
      },
      icon: const Icon(Symbols.replay),
    );
  }
}

class TunAdvancedItem extends StatelessWidget {
  const TunAdvancedItem({super.key});

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    return ListItem.open(
      title: Text(appLocalizations.tunAdvanced),
      subtitle: Text(appLocalizations.tunAdvancedDesc),
      blur: false,
      widget: BaseScaffold(
        title: appLocalizations.tunAdvanced,
        actions: const [TunAdvancedResetButton()],
        body: const TunAdvancedListView(),
      ),
    );
  }
}
