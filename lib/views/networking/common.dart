import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';

class OverlayNetworkLoginItem extends StatelessWidget {
  final String url;

  const OverlayNetworkLoginItem({super.key, required this.url});

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    return DecorationListItem(
      leading: const Icon(Symbols.login),
      title: Text(
        url,
        style: context.textTheme.bodyMedium?.copyWith(
          color: context.colorScheme.onSurfaceVariant,
        ),
      ),
      trailing: FilledButton.tonalIcon(
        onPressed: () {
          dialogs.openUrl(url);
        },
        icon: const Icon(Symbols.open_in_new),
        label: Text(appLocalizations.signIn),
      ),
    );
  }
}
