import 'dart:async';

import 'package:flutter/widgets.dart';

import 'focus.dart';

/// One back for a single sheet or dialog. Every [PopScope] on that route hears
/// the back, and Android may deliver the same key again after the IME.
class TvBackDecision {
  bool? _cached;
  bool _settling = false;
  bool _disposed = false;

  bool get settling => _settling;

  /// Fires when [settling] ends, after this frame. A sheet keeps its route
  /// from popping until then, so the IME repeat of this back does not close it.
  VoidCallback? onSettled;

  void dispose() {
    _disposed = true;
    onSettled = null;
  }

  bool consume(bool editableHere) {
    if (_disposed) {
      return false;
    }
    if (_settling) {
      return true;
    }
    final cached = _cached;
    if (cached != null) {
      return cached;
    }
    if (!editableHere) {
      _cached = false;
      scheduleMicrotask(() {
        if (!_settling) {
          _cached = null;
        }
      });
      return false;
    }
    _settling = true;
    final consumed = releaseEditableFocus();
    _cached = consumed;
    if (!consumed) {
      _settling = false;
      scheduleMicrotask(() => _cached = null);
      return false;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_disposed) {
        return;
      }
      _settling = false;
      _cached = null;
      onSettled?.call();
    });
    return true;
  }
}

class TvBackScope extends InheritedWidget {
  const TvBackScope({super.key, required this.decision, required super.child});

  final TvBackDecision decision;

  static bool consume(BuildContext context) {
    final boundary = context
        .getElementForInheritedWidgetOfExactType<TvBackScope>();
    final decision = context
        .getInheritedWidgetOfExactType<TvBackScope>()
        ?.decision;
    if (boundary == null || decision == null) {
      return false;
    }
    return decision.consume(editableFocusWithin(boundary));
  }

  @override
  bool updateShouldNotify(TvBackScope oldWidget) => false;
}

class TvBackHost extends StatefulWidget {
  const TvBackHost({super.key, required this.child});

  final Widget child;

  @override
  State<TvBackHost> createState() => _TvBackHostState();
}

class _TvBackHostState extends State<TvBackHost> {
  final TvBackDecision _decision = TvBackDecision();

  @override
  void dispose() {
    _decision.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TvBackScope(decision: _decision, child: widget.child);
  }
}
