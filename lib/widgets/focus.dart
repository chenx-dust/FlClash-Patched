import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

typedef FocusEntryBuilder =
    Widget Function(
      BuildContext context,
      FocusNode sourceFocusNode,
      FocusNode targetFocusNode,
    );

class PrimaryFocusOrder extends FocusOrder {
  const PrimaryFocusOrder();

  @override
  int doCompare(FocusOrder other) => 0;
}

class PageFocusScope extends StatefulWidget {
  final Widget child;

  const PageFocusScope({super.key, required this.child});

  @override
  State<PageFocusScope> createState() => _PageFocusScopeState();
}

class _PageFocusScopeState extends State<PageFocusScope> {
  final FocusScopeNode _node = FocusScopeNode()
    ..traversalEdgeBehavior = TraversalEdgeBehavior.parentScope
    ..directionalTraversalEdgeBehavior = TraversalEdgeBehavior.parentScope;

  @override
  void dispose() {
    _node.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FocusScope.withExternalFocusNode(
      focusScopeNode: _node,
      child: widget.child,
    );
  }
}

class PageTraversalPolicy extends OrderedTraversalPolicy {
  FocusNode? _findPrimaryAction(FocusScopeNode scope) {
    for (final node in scope.traversalDescendants) {
      final context = node.context;
      if (context == null) {
        continue;
      }
      if (FocusTraversalOrder.maybeOf(context) is PrimaryFocusOrder) {
        return node;
      }
    }
    return null;
  }

  bool _isInPrimaryAction(FocusNode node) {
    final context = node.context;
    return context != null &&
        FocusTraversalOrder.maybeOf(context) is PrimaryFocusOrder;
  }

  bool _escapeToEnclosingScope(FocusNode currentNode, bool forward) {
    final parent = currentNode.nearestScope?.enclosingScope;
    if (parent == null || parent == FocusManager.instance.rootScope) {
      return false;
    }
    return forward ? parent.nextFocus() : parent.previousFocus();
  }

  @override
  bool inDirection(FocusNode currentNode, TraversalDirection direction) {
    final isDownRight =
        direction == TraversalDirection.down ||
        direction == TraversalDirection.right;
    if (isDownRight && _isInPrimaryAction(currentNode)) {
      return _escapeToEnclosingScope(currentNode, true);
    }
    final scope = currentNode.nearestScope;
    final before = scope?.focusedChild;
    final moved = super.inDirection(currentNode, direction);
    if (moved && (scope == null || !identical(before, scope.focusedChild))) {
      return true;
    }
    if (isDownRight) {
      final primaryAction = scope == null ? null : _findPrimaryAction(scope);
      if (primaryAction != null && primaryAction.canRequestFocus) {
        primaryAction.requestFocus();
        return true;
      }
      return _escapeToEnclosingScope(currentNode, true);
    }
    return _escapeToEnclosingScope(currentNode, false);
  }

  bool _moveOrEscape(FocusNode currentNode, bool forward) {
    final scope = currentNode.nearestScope;
    final before = scope?.focusedChild;
    final moved = forward
        ? super.next(currentNode)
        : super.previous(currentNode);
    if (scope == null || !identical(before, scope.focusedChild)) {
      return moved;
    }
    return _escapeToEnclosingScope(currentNode, forward);
  }

  @override
  bool next(FocusNode currentNode) => _moveOrEscape(currentNode, true);

  @override
  bool previous(FocusNode currentNode) => _moveOrEscape(currentNode, false);
}

class FocusEntryOnArrow extends StatefulWidget {
  const FocusEntryOnArrow({
    super.key,
    required this.directions,
    required this.builder,
  });

  final Set<LogicalKeyboardKey> directions;
  final FocusEntryBuilder builder;

  @override
  State<FocusEntryOnArrow> createState() => _FocusEntryOnArrowState();
}

class _FocusEntryOnArrowState extends State<FocusEntryOnArrow> {
  final FocusNode _sourceFocusNode = FocusNode();
  final FocusNode _targetFocusNode = FocusNode();

  @override
  void dispose() {
    _sourceFocusNode.dispose();
    _targetFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      canRequestFocus: false,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            widget.directions.contains(event.logicalKey) &&
            _sourceFocusNode.hasPrimaryFocus) {
          _targetFocusNode.requestFocus();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: widget.builder(context, _sourceFocusNode, _targetFocusNode),
    );
  }
}
