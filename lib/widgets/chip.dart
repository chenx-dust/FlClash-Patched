import 'dart:ui' show lerpDouble;

import 'package:fl_clash/common/common.dart';
import 'package:flutter/gestures.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';

import 'text.dart';

class CommonChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final VoidCallback? onDeleted;
  final bool isLarge;

  const CommonChip({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.onDeleted,
    this.isLarge = false,
  });

  @override
  Widget build(BuildContext context) {
    final onDeleted = this.onDeleted;
    if (onDeleted != null) {
      return _ConfirmDeleteChip(label: label, icon: icon, onDeleted: onDeleted);
    }
    return _ChipSurface(
      label: label,
      icon: icon,
      onPressed: onPressed,
      isLarge: isLarge,
    );
  }
}

class _ConfirmDeleteChip extends StatefulWidget {
  final String label;
  final IconData? icon;
  final VoidCallback onDeleted;

  const _ConfirmDeleteChip({
    required this.label,
    required this.onDeleted,
    this.icon,
  });

  @override
  State<_ConfirmDeleteChip> createState() => _ConfirmDeleteChipState();
}

class _ConfirmDeleteChipState extends State<_ConfirmDeleteChip> {
  var _armed = false;
  var _hovered = false;
  var _focused = false;
  var _listening = false;

  void _onHover(bool hovering) {
    if (_hovered == hovering) {
      return;
    }
    _hovered = hovering;
    setState(() {});
  }

  void _onFocusChange(bool focused) {
    if (_focused == focused) {
      return;
    }
    _focused = focused;
    setState(() {});
  }

  void _onTap() {
    if (_hovered || _focused || _armed) {
      widget.onDeleted();
      return;
    }
    _armed = true;
    _ensurePointerRoute();
    setState(() {});
  }

  // Touch never leaves the chip, so the next press outside it drops the stage.
  void _onPointer(PointerEvent event) {
    if (event is! PointerDownEvent || !_armed || !mounted) {
      return;
    }
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) {
      return;
    }
    if (box.size.contains(box.globalToLocal(event.position))) {
      return;
    }
    _armed = false;
    _removePointerRoute();
    setState(() {});
  }

  void _ensurePointerRoute() {
    if (_listening) {
      return;
    }
    _listening = true;
    GestureBinding.instance.pointerRouter.addGlobalRoute(_onPointer);
  }

  void _removePointerRoute() {
    if (!_listening) {
      return;
    }
    _listening = false;
    GestureBinding.instance.pointerRouter.removeGlobalRoute(_onPointer);
  }

  @override
  void dispose() {
    _removePointerRoute();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _ChipSurface(
      label: widget.label,
      icon: widget.icon,
      onPressed: _onTap,
      onHover: _onHover,
      onFocusChange: _onFocusChange,
      armed: _hovered || _focused || _armed,
      isLarge: true,
    );
  }
}

class _ChipSurface extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final ValueChanged<bool>? onHover;
  final ValueChanged<bool>? onFocusChange;
  final bool armed;
  final bool isLarge;

  const _ChipSurface({
    required this.label,
    this.icon,
    this.onPressed,
    this.onHover,
    this.onFocusChange,
    this.armed = false,
    this.isLarge = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final duration = context.motionDuration(midDuration);
    final foregroundColor = armed
        ? colorScheme.onErrorContainer
        : colorScheme.onSurfaceVariant;
    return TweenAnimationBuilder<double>(
      tween: Tween(end: armed ? 1 : 0),
      duration: duration,
      curve: Curves.fastOutSlowIn,
      builder: (context, t, _) {
        final content = Padding(
          padding: EdgeInsets.only(
            left: icon != null ? (isLarge ? 9 : 6) : (isLarge ? 12 : 8),
            right: lerpDouble(isLarge ? 12 : 8, isLarge ? 9 : 6, t)!,
            top: isLarge ? 5 : 3,
            bottom: isLarge ? 5 : 3,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                ExcludeSemantics(
                  child: Icon(
                    icon,
                    size: isLarge ? 16 : 14,
                    color: foregroundColor,
                  ),
                ),
                SizedBox(width: isLarge ? 6 : 4),
              ],
              Flexible(
                fit: FlexFit.loose,
                child: EmojiText(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.textTheme.labelMedium?.copyWith(
                    color: foregroundColor,
                    height: 1,
                    fontSize: isLarge
                        ? (context.textTheme.labelMedium?.fontSize ?? 14) + 1
                        : null,
                  ),
                ),
              ),
              if (t > 0)
                ClipRect(
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    widthFactor: t,
                    child: Padding(
                      padding: const EdgeInsetsDirectional.only(start: 4),
                      child: Icon(
                        Symbols.close,
                        size: 14,
                        color: foregroundColor,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
        return Material(
          // Material also animates shape. Updating the border every frame
          // makes that animation chase the target, so the stroke lags the fill.
          animationDuration: Duration.zero,
          color: Color.lerp(
            colorScheme.surfaceContainerHighest,
            colorScheme.errorContainer,
            t,
          ),
          shape: (isLarge ? AppShape.md : AppShape.sm).copyWith(
            side: BorderSide(
              color: Color.lerp(
                colorScheme.outlineVariant,
                colorScheme.error,
                t,
              )!,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: onPressed == null
              ? content
              : InkWell(
                  onTap: onPressed,
                  onHover: onHover,
                  onFocusChange: onFocusChange,
                  mouseCursor: SystemMouseCursors.click,
                  child: content,
                ),
        );
      },
    );
  }
}

class TonalChip extends StatelessWidget {
  final String label;
  final Color color;
  final Color foregroundColor;
  final VoidCallback? onPressed;

  const TonalChip({
    super.key,
    required this.label,
    required this.color,
    required this.foregroundColor,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            fit: FlexFit.loose,
            child: EmojiText(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.textTheme.bodySmall?.copyWith(
                color: foregroundColor,
              ),
            ),
          ),
        ],
      ),
    );
    return Material(
      animationDuration: Duration.zero,
      color: color,
      shape: AppShape.sm,
      clipBehavior: Clip.antiAlias,
      child: onPressed == null
          ? content
          : InkWell(
              onTap: onPressed,
              mouseCursor: SystemMouseCursors.click,
              child: content,
            ),
    );
  }
}

class MetaChip extends StatelessWidget {
  final String label;

  const MetaChip({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: colorScheme.surfaceContainerHighest,
        shape: AppShape.sm.copyWith(
          side: BorderSide(color: colorScheme.outlineVariant),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: EmojiText(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: context.textTheme.labelSmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
