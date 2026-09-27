import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/config.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

typedef _NtpUpdate<T> =
    PatchClashConfig Function(PatchClashConfig state, T value);

ProviderListenable<T> _ntpSelector<T>(T Function(Ntp ntp) select) {
  return patchClashConfigProvider.select((state) => select(state.ntp));
}

ConfigWriter<T> _ntpWriter<T>(_NtpUpdate<T> update) {
  return (ref, value) => ref
      .read(patchClashConfigProvider.notifier)
      .update((state) => update(state, value));
}

ConfigToggleItem _ntpToggle({
  required ConfigLabel title,
  required bool Function(Ntp ntp) select,
  required _NtpUpdate<bool> update,
  ConfigLabel? subtitle,
}) {
  return ConfigToggleItem(
    title: title,
    subtitle: subtitle,
    selector: _ntpSelector(select),
    onChanged: _ntpWriter(update),
  );
}

ConfigTextItem _ntpText({
  required ConfigLabel title,
  required String Function(Ntp ntp) select,
  required _NtpUpdate<String> update,
  required int maxLength,
}) {
  return ConfigTextItem(
    title: title,
    selector: _ntpSelector(select),
    onChanged: _ntpWriter(update),
    maxLength: maxLength,
  );
}

ConfigTextItem _ntpNumber({
  required ConfigLabel title,
  required int Function(Ntp ntp) select,
  required _NtpUpdate<int> update,
  required int maxLength,
  required int min,
  required int max,
}) {
  return ConfigTextItem(
    title: title,
    selector: _ntpSelector((ntp) => '${select(ntp)}'),
    onChanged: _ntpWriter<String>(
      (state, value) => update(state, int.parse(value)),
    ),
    maxLength: maxLength,
    keyboardType: TextInputType.number,
    normalize: (value) => value.trim(),
    validator: (value, l) {
      final number = int.tryParse(value ?? '');
      return number == null || number < min || number > max
          ? l.numberTip(title(l))
          : null;
    },
  );
}

class _DialerProxyItem extends ConsumerWidget {
  const _DialerProxyItem();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.appLocalizations;
    final value = ref.watch(_ntpSelector((ntp) => ntp.dialerProxy));
    return ListItem.input(
      title: Text(l.dialerProxy),
      subtitle: Text(value.isEmpty ? l.dialerProxyDesc : value),
      dialogTitle: l.dialerProxy,
      value: value,
      maxLength: TextInputLimits.groupName,
      onChanged: (value) {
        if (value == null) {
          return;
        }
        ref
            .read(patchClashConfigProvider.notifier)
            .update((state) => state.copyWith.ntp(dialerProxy: value));
      },
    );
  }
}

class OverrideNtpItem extends ConsumerWidget {
  const OverrideNtpItem({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ConfigToggleItem(
      title: (l) => l.overrideNtp,
      subtitle: (l) => l.overrideNtpDesc,
      selector: overrideNtpProvider,
      onChanged: (ref, value) =>
          ref.read(overrideNtpProvider.notifier).value = value,
    );
  }
}

class NtpListView extends StatelessWidget {
  const NtpListView({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: sectionPagePadding,
      children: [
        generateSectionV3(isFirst: true, items: const [OverrideNtpItem()]),
        generateSectionV3(
          title: context.appLocalizations.options,
          items: [
            _ntpToggle(
              title: (l) => l.status,
              subtitle: (l) => l.ntpStatusDesc,
              select: (ntp) => ntp.enable,
              update: (state, value) => state.copyWith.ntp(enable: value),
            ),
            _ntpText(
              title: (l) => l.server,
              select: (ntp) => ntp.server,
              update: (state, value) => state.copyWith.ntp(server: value),
              maxLength: TextInputLimits.domain,
            ),
            _ntpNumber(
              title: (l) => l.port,
              select: (ntp) => ntp.port,
              update: (state, value) => state.copyWith.ntp(port: value),
              maxLength: TextInputLimits.port,
              min: 1,
              max: 65535,
            ),
            _ntpNumber(
              title: (l) => l.ntpInterval,
              select: (ntp) => ntp.interval,
              update: (state, value) => state.copyWith.ntp(interval: value),
              maxLength: TextInputLimits.number,
              min: 1,
              max: 0x7fffffff,
            ),
            const _DialerProxyItem(),
            if (!system.isMobile)
              _ntpToggle(
                title: (l) => l.writeToSystem,
                subtitle: (l) => l.writeToSystemDesc,
                select: (ntp) => ntp.writeToSystem,
                update: (state, value) =>
                    state.copyWith.ntp(writeToSystem: value),
              ),
          ],
        ),
      ],
    );
  }
}
