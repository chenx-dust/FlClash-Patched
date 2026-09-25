import 'package:fl_clash/enum/enum.dart';
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
  FocusScopeNode? _overlayFocusBoundary(FocusNode node) {
    var scope = node.nearestScope;
    while (scope != null && scope != FocusManager.instance.rootScope) {
      final route = _routeOf(scope);
      if (route != null &&
          !route.opaque &&
          !identical(route, _routeOf(scope.enclosingScope))) {
        return scope;
      }
      scope = scope.enclosingScope;
    }
    return null;
  }

  ModalRoute<dynamic>? _routeOf(FocusScopeNode? scope) {
    final focusContext = scope?.context;
    if (focusContext == null) {
      return null;
    }
    return ModalRoute.of(focusContext);
  }

  bool _moveInsideOverlay(
    FocusScopeNode boundary, {
    required bool directional,
    required bool Function() move,
  }) {
    final previous = directional
        ? boundary.directionalTraversalEdgeBehavior
        : boundary.traversalEdgeBehavior;
    if (directional) {
      boundary.directionalTraversalEdgeBehavior = TraversalEdgeBehavior.stop;
    } else {
      boundary.traversalEdgeBehavior = TraversalEdgeBehavior.stop;
    }
    try {
      return move();
    } finally {
      if (directional) {
        boundary.directionalTraversalEdgeBehavior = previous;
      } else {
        boundary.traversalEdgeBehavior = previous;
      }
    }
  }

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
    final boundary = _overlayFocusBoundary(currentNode);
    if (boundary != null) {
      return _moveInsideOverlay(
        boundary,
        directional: true,
        move: () => super.inDirection(currentNode, direction),
      );
    }
    final isDownRight =
        direction == TraversalDirection.down ||
        direction == TraversalDirection.right;
    final scope = currentNode.nearestScope;
    final before = scope?.focusedChild;
    final moved = super.inDirection(currentNode, direction);
    if (moved && (scope == null || !identical(before, scope.focusedChild))) {
      return true;
    }
    if (isDownRight) {
      if (_isInPrimaryAction(currentNode)) {
        return _escapeToEnclosingScope(currentNode, true);
      }
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
    final boundary = _overlayFocusBoundary(currentNode);
    if (boundary != null) {
      return _moveInsideOverlay(
        boundary,
        directional: false,
        move: () =>
            forward ? super.next(currentNode) : super.previous(currentNode),
      );
    }
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

class NavDestinationAnchor extends StatelessWidget {
  const NavDestinationAnchor({
    super.key,
    required this.label,
    required this.child,
  });

  final PageLabel label;
  final Widget child;

  @override
  Widget build(BuildContext context) => child;
}

bool _isEditableContext(BuildContext focusContext) {
  return focusContext.widget is EditableText ||
      focusContext.findAncestorWidgetOfExactType<EditableText>() != null ||
      focusContext.widget is Slider ||
      focusContext.findAncestorWidgetOfExactType<Slider>() != null;
}

bool releaseEditableFocus() {
  final node = FocusManager.instance.primaryFocus;
  final focusContext = node?.context;
  if (focusContext == null || !_isEditableContext(focusContext)) {
    return false;
  }
  final scope = node?.enclosingScope;
  if (scope == null) {
    return false;
  }
  scope.requestScopeFocus();
  return true;
}

bool editableFocusWithin(BuildContext boundary) {
  final focusContext = FocusManager.instance.primaryFocus?.context;
  if (focusContext == null || !_isEditableContext(focusContext)) {
    return false;
  }
  var within = false;
  focusContext.visitAncestorElements((element) {
    if (identical(element, boundary)) {
      within = true;
      return false;
    }
    return true;
  });
  return within;
}

bool focusIsInNavigation() {
  final focusContext = FocusManager.instance.primaryFocus?.context;
  if (focusContext == null) {
    return false;
  }
  return focusContext.findAncestorWidgetOfExactType<NavigationBar>() != null ||
      focusContext.findAncestorWidgetOfExactType<NavigationRail>() != null;
}

bool focusNavigationDestination(BuildContext context, PageLabel label) {
  FocusNode? target;
  void visit(Element element) {
    if (target != null) {
      return;
    }
    final widget = element.widget;
    if (widget is NavDestinationAnchor && widget.label == label) {
      final node = Focus.maybeOf(element);
      if (node != null && node.canRequestFocus) {
        target = node;
        return;
      }
    }
    element.visitChildren(visit);
  }

  context.visitChildElements(visit);
  target?.requestFocus();
  return target != null;
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
