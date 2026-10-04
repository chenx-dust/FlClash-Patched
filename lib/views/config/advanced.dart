import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/models/clash_config.dart';
import 'package:fl_clash/providers/config.dart';
import 'package:fl_clash/views/config/dns.dart';
import 'package:fl_clash/views/config/network.dart';
import 'package:fl_clash/views/config/ntp.dart';
import 'package:fl_clash/views/config/scripts.dart';
import 'package:fl_clash/widgets/list.dart';
import 'package:fl_clash/widgets/scaffold.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'rules.dart';

class AdvancedConfigView extends StatelessWidget {
  const AdvancedConfigView({super.key});

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    final List<Widget> items = [
      ListItem.open(
        title: Text(appLocalizations.network),
        subtitle: Text(appLocalizations.networkDesc),
        leading: const Icon(Symbols.link),
        blur: false,
        widget: BaseScaffold(
          title: appLocalizations.network,
          actions: const [NetworkResetButton()],
          body: const NetworkListView(),
        ),
      ),
      ListItem.open(
        title: const Text('DNS'),
        subtitle: Text(appLocalizations.dnsDesc),
        leading: const Icon(Symbols.dns),
        widget: BaseScaffold(
          title: 'DNS',
          actions: [
            Consumer(
              builder: (_, ref, _) {
                return IconButton(
                  onPressed: () async {
                    final res = await dialogs.showMessage(
                      title: appLocalizations.reset,
                      message: TextSpan(text: appLocalizations.resetTip),
                    );
                    if (res != true) {
                      return;
                    }
                    ref
                        .read(patchClashConfigProvider.notifier)
                        .update((state) => state.copyWith(dns: defaultDns));
                  },
                  tooltip: appLocalizations.reset,
                  icon: const Icon(Symbols.replay),
                );
              },
            ),
          ],
          body: const DnsListView(),
        ),
        blur: false,
      ),
      ListItem.open(
        title: const Text('NTP'),
        subtitle: Text(appLocalizations.ntpDesc),
        leading: const Icon(Symbols.schedule),
        widget: BaseScaffold(
          title: 'NTP',
          actions: [
            Consumer(
              builder: (_, ref, _) {
                return IconButton(
                  onPressed: () async {
                    final res = await dialogs.showMessage(
                      title: appLocalizations.reset,
                      message: TextSpan(text: appLocalizations.resetTip),
                    );
                    if (res != true) {
                      return;
                    }
                    ref
                        .read(patchClashConfigProvider.notifier)
                        .update((state) => state.copyWith(ntp: defaultNtp));
                  },
                  tooltip: appLocalizations.reset,
                  icon: const Icon(Symbols.replay),
                );
              },
            ),
          ],
          body: const NtpListView(),
        ),
        blur: false,
      ),
      ListItem.open(
        title: Text(appLocalizations.addedRules),
        subtitle: Text(appLocalizations.controlGlobalAddedRules),
        leading: const Icon(Symbols.library_books),
        widget: const AddedRulesView(),
        blur: false,
      ),
      ListItem.open(
        title: Text(appLocalizations.script),
        subtitle: Text(appLocalizations.overrideScript),
        leading: const Icon(Symbols.code_xml),
        widget: const ScriptsView(),
        blur: false,
      ),
    ];
    return BaseScaffold(
      title: appLocalizations.advancedConfig,
      body: ListView(
        padding: sectionPagePadding,
        children: [generateSectionV3(isFirst: true, items: items)],
      ),
    );
  }
}
