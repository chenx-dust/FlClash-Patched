import 'dart:async';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/manager/status_manager.dart';
import 'package:fl_clash/models/state.dart';
import 'package:fl_clash/providers/app.dart';
import 'package:fl_clash/widgets/inherited.dart';
import 'package:fl_clash/widgets/scaffold.dart';
import 'package:fl_clash/widgets/sheet.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const _snackBarDuration = Duration(milliseconds: 1500);

extension BuildContextExtension on BuildContext {
  CommonScaffoldState? get commonScaffoldState {
    return findAncestorStateOfType<CommonScaffoldState>();
  }

  bool get isMobileView {
    return ProviderScope.containerOf(
      this,
      listen: false,
    ).read(isMobileViewProvider);
  }

  void safeNestedPop<T extends Object?>([T? result]) {
    final nestedPop = SheetProvider.of(this)?.nestedNavigatorPop;
    if (nestedPop != null) {
      return nestedPop(result);
    } else {
      return Navigator.of(this).pop(result);
    }
  }

  double get sheetTopPadding {
    final sheetType = SheetProvider.of(this)!.type;
    if (sheetType == SheetType.bottomSheet) {
      return sheetAppBarHeight;
    } else {
      return 10;
    }
  }

  void showNotifier(
    String text, {
    MessageLevel level = MessageLevel.info,
    MessageActionState? actionState,
    bool allowCopy = false,
  }) {
    return findAncestorStateOfType<StatusManagerState>()?.message(
      text,
      level: level,
      actionState: actionState,
      allowCopy: allowCopy,
    );
  }

  void showSnackBar(String message, {SnackBarAction? action, bool? persist}) {
    final messenger = ScaffoldMessenger.of(this);
    messenger.removeCurrentSnackBar();
    final content = Text(message);
    messenger.showSnackBar(
      (persist ?? action != null)
          ? SnackBar(
              content: content,
              action: action,
              persist: true,
              behavior: SnackBarBehavior.fixed,
              duration: _snackBarDuration,
            )
          : _TimedSnackBar(content: content, action: action),
    );
  }

  ColorScheme get colorScheme => Theme.of(this).colorScheme;

  bool get disableAnimations => MediaQuery.disableAnimationsOf(this);

  Duration motionDuration(Duration duration) =>
      disableAnimations ? Duration.zero : duration;

  TextTheme get textTheme => Theme.of(this).textTheme;

  AppLocalizations get appLocalizations => AppLocalizations.of(this);

  T? findLastStateOfType<T extends State>() {
    T? state;

    void visitor(Element element) {
      if (!element.mounted) {
        return;
      }
      if (element is StatefulElement) {
        if (element.state is T) {
          state = element.state as T;
        }
      }
      element.visitChildren(visitor);
    }

    visitor(this as Element);
    return state;
  }
}

class _TimedSnackBar extends SnackBar {
  const _TimedSnackBar({
    super.key,
    required super.content,
    super.action,
    super.animation,
  }) : super(persist: true, behavior: SnackBarBehavior.fixed);

  @override
  SnackBar withAnimation(Animation<double> newAnimation, {Key? fallbackKey}) {
    return _TimedSnackBar(
      key: key ?? fallbackKey,
      content: content,
      action: action,
      animation: newAnimation,
    );
  }

  @override
  State<SnackBar> createState() => _TimedSnackBarState();
}

class _TimedSnackBarState extends State<SnackBar> {
  Timer? _timer;
  var _hovering = false;
  var _expired = false;
  var _closed = false;

  void _start() {
    _timer ??= Timer(_snackBarDuration, () {
      _expired = true;
      _dismissIfIdle();
    });
  }

  void _dismissIfIdle() {
    if (_closed || _hovering || !_expired) return;
    _closed = true;
    ScaffoldMessenger.of(
      context,
    ).hideCurrentSnackBar(reason: SnackBarClosedReason.timeout);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => _hovering = true,
      onExit: (_) {
        _hovering = false;
        _dismissIfIdle();
      },
      child: SnackBar(
        content: widget.content,
        action: widget.action,
        animation: widget.animation,
        persist: true,
        behavior: SnackBarBehavior.fixed,
        onVisible: _start,
      ),
    );
  }
}
