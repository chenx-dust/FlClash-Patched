import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'package:fl_clash/widgets/proxy_chain.dart';

class RuleProxyChain extends ConsumerWidget {
  final String target;
  final bool hideTooMany;
  final Widget? leading;
  final VoidCallback? onNavigate;

  const RuleProxyChain({
    super.key,
    required this.target,
    this.hideTooMany = true,
    this.leading,
    this.onNavigate,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groups = {
      for (final group in ref.watch(groupsProvider)) group.name: group,
    };
    final selected = ref.watch(selectedMapProvider);
    final mode = ref.watch(
      patchClashConfigProvider.select((state) => state.mode),
    );
    final chain = <String>[];
    final visited = <String>{};
    var name = target;
    while (name.isNotEmpty && visited.add(name)) {
      chain.add(name);
      final group = groups[name];
      if (group == null ||
          group.type == GroupType.LoadBalance ||
          group.type == GroupType.Relay) {
        break;
      }
      name = group.getCurrentSelectedName(selected[name] ?? '');
    }
    ({String groupName, String? proxyName})? destination(String name) {
      if (mode == Mode.direct) return null;
      if (const {
        'DIRECT',
        'REJECT',
        'REJECT-DROP',
        'PASS',
        'COMPATIBLE',
      }.contains(name)) {
        return null;
      }
      if (name == GroupName.GLOBAL.name && mode != Mode.global) {
        return null;
      }
      if (groups.containsKey(name)) {
        return (groupName: name, proxyName: null);
      }
      final index = chain.indexOf(name);
      if (index <= 0) return null;
      final parent = groups[chain[index - 1]];
      if (parent == null || !parent.all.any((proxy) => proxy.name == name)) {
        return null;
      }
      return (groupName: parent.name, proxyName: name);
    }

    return ProxyChain(
      hideTooMany:
          ref.watch(
            appSettingProvider.select((state) => state.collapseProxyChains),
          ) &&
          hideTooMany,
      chain: chain,
      leading: leading,
      showLeadingArrow: leading == null,
      canSelect: (name) => destination(name) != null,
      onSelected: (name) {
        final focus = destination(name);
        if (focus == null) return;
        ref.read(queryProvider(QueryTag.proxies).notifier).value = '';
        ref.read(proxyFocusProvider.notifier).value = focus;
        final actions = ref.read(proxiesActionProvider.notifier);
        actions.updateCurrentGroupName(focus.groupName);
        actions.updateCurrentUnfoldSet({
          ...ref.read(unfoldSetProvider),
          focus.groupName,
        });
        onNavigate?.call();
        ref.read(currentPageLabelProvider.notifier).toPage(PageLabel.proxies);
      },
    );
  }
}
