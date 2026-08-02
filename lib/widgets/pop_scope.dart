import 'dart:async';

import 'package:fl_clash/providers/app.dart';
import 'package:fl_clash/state.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CommonPopScopeAttemptNotification extends Notification {
  final Future<void> completion;

  const CommonPopScopeAttemptNotification(this.completion);
}

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
    return PopScope(
      canPop: canPop ?? onPop == null,
      onPopInvokedWithResult: onPop == null
          ? null
          : (didPop, _) {
              if (didPop) {
                return;
              }
              CommonPopScopeAttemptNotification(
                _handlePop(context),
              ).dispatch(context);
            },
      child: child,
    );
  }
}

class SystemBackBlock extends ConsumerStatefulWidget {
  final Widget child;

  const SystemBackBlock({super.key, required this.child});

  @override
  ConsumerState<SystemBackBlock> createState() => _SystemBackBlockState();
}

class _SystemBackBlockState extends ConsumerState<SystemBackBlock> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      globalState.container.read(backBlockProvider.notifier).backBlock();
    });
  }

  @override
  void dispose() {
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
