import 'dart:async';

import 'package:fl_clash/providers/app.dart';
import 'package:fl_clash/state.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CommonPopScope extends StatelessWidget {
  final Widget child;
  final bool? canPop;
  final FutureOr<bool> Function(BuildContext context)? onPop;
  final FutureOr<void> Function()? onPopSuccess;

  const CommonPopScope({
    super.key,
    required this.child,
    this.canPop,
    this.onPop,
    this.onPopSuccess,
  });

  Future<void> _handlePop(BuildContext context) async {
    final res = await onPop!(context);
    if (!context.mounted || !res) {
      return;
    }
    Navigator.of(context).pop();
    if (onPopSuccess != null) {
      await onPopSuccess!();
    }
  }

  @override
  Widget build(BuildContext context) {
    final canPopValue = canPop ?? onPop == null;
    final popScope = PopScope(
      canPop: canPop ?? onPop == null,
      onPopInvokedWithResult: onPop == null
          ? null
          : (didPop, _) async {
              if (didPop) {
                return;
              }
              await _handlePop(context);
            },
      child: child,
    );
    if (onPop == null || canPopValue) {
      return popScope;
    }
    return Focus(
      canRequestFocus: false,
      onKeyEvent: (_, event) {
        if (event is! KeyDownEvent ||
            event.logicalKey != LogicalKeyboardKey.escape) {
          return KeyEventResult.ignored;
        }
        _handlePop(context);
        return KeyEventResult.handled;
      },
      child: popScope,
    );
  }
}

class SystemBackBlock extends ConsumerStatefulWidget {
  static final List<_SystemBackBlockState> _states = [];

  final Widget child;
  final FutureOr<void> Function()? onBack;

  const SystemBackBlock({super.key, required this.child, this.onBack});

  static Future<bool> maybeHandleBack() async {
    final states = List<_SystemBackBlockState>.from(_states.reversed);
    for (final state in states) {
      if (!state.mounted || state.widget.onBack == null) {
        continue;
      }
      await state.widget.onBack!();
      return true;
    }
    return false;
  }

  @override
  ConsumerState<SystemBackBlock> createState() => _SystemBackBlockState();
}

class _SystemBackBlockState extends ConsumerState<SystemBackBlock> {
  @override
  void initState() {
    super.initState();
    SystemBackBlock._states.add(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      globalState.container.read(backBlockProvider.notifier).backBlock();
    });
  }

  @override
  void dispose() {
    SystemBackBlock._states.remove(this);
    super.dispose();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      globalState.container.read(backBlockProvider.notifier).unBackBlock();
    });
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
