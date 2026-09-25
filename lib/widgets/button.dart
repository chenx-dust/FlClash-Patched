import 'package:fl_clash/common/common.dart';
import 'package:material_ui/material_ui.dart';

import 'builder.dart';
import 'card.dart';

class FabFocusOutline extends StatefulWidget {
  const FabFocusOutline({super.key, required this.child});

  final Widget child;

  @override
  State<FabFocusOutline> createState() => _FabFocusOutlineState();
}

class _FabFocusOutlineState extends State<FabFocusOutline> {
  bool _focused = false;

  void _handleFocusChange(bool focused) {
    if (_focused == focused) {
      return;
    }
    setState(() => _focused = focused);
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onFocusChange: _handleFocusChange,
      child: Stack(
        children: [
          widget.child,
          if (_focused)
            const Positioned.fill(child: IgnorePointer(child: _FabFocusRing())),
        ],
      ),
    );
  }
}

class _FabFocusRing extends StatelessWidget {
  const _FabFocusRing();

  static const width = 2.0;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(width / 2),
      child: DecoratedBox(
        decoration: ShapeDecoration(
          shape: AppShape.all(AppCorner.md - width / 2).copyWith(
            side: BorderSide(
              color: context.colorScheme.onPrimaryContainer,
              width: width,
            ),
          ),
        ),
      ),
    );
  }
}

class CommonFloatingActionButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Icon icon;
  final String label;

  const CommonFloatingActionButton({
    super.key,
    this.onPressed,
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        floatingActionButtonTheme: Theme.of(context).floatingActionButtonTheme
            .copyWith(
              extendedIconLabelSpacing: 0,
              extendedPadding: const EdgeInsets.all(16),
            ),
      ),
      child: FloatingActionButtonExtendedBuilder(
        builder: (isExtended) {
          return FloatingActionButton.extended(
            heroTag: null,
            icon: icon,
            onPressed: onPressed,
            isExtended: true,
            label: AnimatedSize(
              alignment: Alignment.centerLeft,
              duration: midDuration,
              curve: Curves.easeOutBack,
              child: AnimatedOpacity(
                duration: midDuration,
                opacity: isExtended ? 1.0 : 0.4,
                curve: Curves.linear,
                child: isExtended
                    ? Padding(
                        padding: const EdgeInsets.only(left: 8.0),
                        child: Text(label, softWrap: false),
                      )
                    : const SizedBox.shrink(),
              ),
            ),
          );
        },
      ),
    );
  }
}

class MoreActionButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final String label;
  final Widget? trailing;

  const MoreActionButton({
    super.key,
    this.onPressed,
    required this.label,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: CommonCard(
        radius: AppCorner.xl,
        onPressed: onPressed,
        child: ListTile(
          minTileHeight: 0,
          minVerticalPadding: 0,
          titleTextStyle: context.textTheme.bodyMedium?.toJetBrainsMono,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
          title: Text(label, style: context.textTheme.bodyLarge),
          trailing: trailing ?? const Icon(Icons.arrow_forward_ios, size: 18),
        ),
      ),
    );
  }
}
