import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/common.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class BackManager extends StatefulWidget {
  final Widget child;

  const BackManager({super.key, required this.child});

  @override
  State<BackManager> createState() => _BackManagerState();
}

class _BackManagerState extends State<BackManager> {
  Future<void> _handleBack() async {
    // ignore: invalid_use_of_visible_for_testing_member, invalid_use_of_protected_member
    await WidgetsBinding.instance.handlePopRoute();
  }

  void _invokeBack() {
    throttler.call(
      FunctionTag.handleBack,
      _handleBack,
      fire: true,
      duration: const Duration(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.escape): BackIntent(),
        SingleActivator(LogicalKeyboardKey.gameButtonB): BackIntent(),
      },
      child: Actions(
        actions: {
          BackIntent: CallbackAction<BackIntent>(
            onInvoke: (_) {
              _invokeBack();
              return null;
            },
          ),
        },
        child: Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: (event) {
            if (event.kind != PointerDeviceKind.mouse ||
                (event.buttons & kBackMouseButton) == 0) {
              return;
            }
            _invokeBack();
          },
          child: widget.child,
        ),
      ),
    );
  }
}
