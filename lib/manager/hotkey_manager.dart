import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/common.dart';
import 'package:fl_clash/providers/action.dart';
import 'package:fl_clash/providers/config.dart';
import 'package:fl_clash/state.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hotkey_manager/hotkey_manager.dart';

class HotKeyManager extends ConsumerStatefulWidget {
  final Widget child;

  const HotKeyManager({super.key, required this.child});

  @override
  ConsumerState<HotKeyManager> createState() => _HotKeyManagerState();
}

class _HotKeyManagerState extends ConsumerState<HotKeyManager> {
  bool _isHandlingBack = false;

  @override
  void initState() {
    super.initState();
    ref.listenManual(hotKeyActionsProvider, (prev, next) {
      if (!hotKeyActionListEquality.equals(prev, next)) {
        _updateHotKeys(hotKeyActions: next);
      }
    }, fireImmediately: true);
  }

  Future<void> _handleBack() async {
    if (_isHandlingBack) {
      return;
    }
    _isHandlingBack = true;
    try {
      final navigator = globalState.navigatorKey.currentState;
      final didPop = await navigator?.maybePop() ?? false;
      if (didPop) {
        return;
      }
      await globalState.container
          .read(systemActionProvider.notifier)
          .handleClose();
    } finally {
      _isHandlingBack = false;
    }
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent ||
        event.logicalKey != LogicalKeyboardKey.escape) {
      return KeyEventResult.ignored;
    }
    _handleBack();
    return KeyEventResult.handled;
  }

  void _handlePointerDown(PointerDownEvent event) {
    if (event.kind != PointerDeviceKind.mouse ||
        event.buttons & kBackMouseButton == 0) {
      return;
    }
    _handleBack();
  }

  Future<void> _handleHotKeyAction(HotAction action) async {
    final ref = globalState.container;
    final commonAction = ref.read(commonActionProvider.notifier);
    final systemAction = ref.read(systemActionProvider.notifier);
    switch (action) {
      case HotAction.mode:
        commonAction.updateMode();
      case HotAction.start:
        commonAction.updateStart();
      case HotAction.view:
        systemAction.updateVisible();
      case HotAction.proxy:
        systemAction.updateSystemProxy();
      case HotAction.tun:
        systemAction.updateTun();
    }
  }

  Future<void> _updateHotKeys({
    required List<HotKeyAction> hotKeyActions,
  }) async {
    await hotKeyManager.unregisterAll();
    final hotkeyActionHandles = hotKeyActions
        .where((hotKeyAction) {
          return hotKeyAction.key != null && hotKeyAction.modifiers.isNotEmpty;
        })
        .map<Future>((hotKeyAction) async {
          final modifiers = hotKeyAction.modifiers
              .map((item) => item.toHotKeyModifier())
              .toList();
          final hotKey = HotKey(
            key: PhysicalKeyboardKey(hotKeyAction.key!),
            modifiers: modifiers,
          );
          return hotKeyManager.register(
            hotKey,
            keyDownHandler: (_) {
              _handleHotKeyAction(hotKeyAction.action);
            },
          );
        });
    await Future.wait(hotkeyActionHandles);
  }

  Shortcuts _buildCloseShortcuts(Widget child) {
    return Shortcuts(
      shortcuts: {
        utils.controlSingleActivator(LogicalKeyboardKey.keyW):
            const CloseWindowIntent(),
      },
      child: Actions(
        actions: {
          CloseWindowIntent: CallbackAction<CloseWindowIntent>(
            onInvoke: (_) => globalState.container
                .read(systemActionProvider.notifier)
                .handleClose(false),
          ),
          DoNothingIntent: CallbackAction<DoNothingIntent>(
            onInvoke: (_) => null,
          ),
        },
        child: child,
      ),
    );
  }

  Widget _buildBackActionListener(Widget child) {
    return Focus(
      canRequestFocus: false,
      onKeyEvent: _handleKeyEvent,
      child: Listener(onPointerDown: _handlePointerDown, child: child),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _buildBackActionListener(_buildCloseShortcuts(widget.child));
  }
}
