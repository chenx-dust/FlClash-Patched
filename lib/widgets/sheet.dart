import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/models/common.dart';
import 'package:fl_clash/widgets/inherited.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'focus.dart';
import 'scaffold.dart';
import 'side_sheet.dart';
import 'tv_back.dart';
import 'tv_layout.dart';

@immutable
class SheetProps {
  final double? maxWidth;
  final double? maxHeight;
  final bool isScrollControlled;
  final bool useSafeArea;
  final Color? backgroundColor;
  final bool blur;

  const SheetProps({
    this.maxWidth,
    this.maxHeight,
    this.backgroundColor,
    this.useSafeArea = true,
    this.isScrollControlled = false,
    this.blur = true,
  });
}

@immutable
class ExtendProps {
  final double? maxWidth;
  final bool useSafeArea;
  final bool blur;
  final bool forceFull;

  const ExtendProps({
    this.maxWidth,
    this.useSafeArea = true,
    this.blur = true,
    this.forceFull = false,
  });
}

enum SheetType { page, bottomSheet, sideSheet }

Future<T?> showSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  SheetProps props = const SheetProps(),
}) {
  final isMobile = context.isMobileView;
  return switch (isMobile) {
    true => showModalBottomSheet<T>(
      context: context,
      isScrollControlled: props.isScrollControlled,
      builder: (_) {
        return _sheetHost(
          context: context,
          type: SheetType.bottomSheet,
          child: builder(context),
        );
      },
      backgroundColor: props.backgroundColor,
      showDragHandle: false,
      useSafeArea: props.useSafeArea,
    ),
    false => showModalSideSheet<T>(
      useSafeArea: props.useSafeArea,
      isScrollControlled: props.isScrollControlled,
      context: context,
      backgroundColor: props.backgroundColor,
      constraints: BoxConstraints(maxWidth: props.maxWidth ?? 360),
      filter: props.blur ? commonFilter : null,
      builder: (_) {
        return _sheetHost(
          context: context,
          type: SheetType.sideSheet,
          child: builder(context),
        );
      },
    ),
  };
}

Future<T?> showExtend<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  ExtendProps props = const ExtendProps(),
}) {
  final isMobile = context.isMobileView;
  return switch (isMobile || props.forceFull) {
    true => BaseNavigator.push(
      context,
      _sheetHost(
        context: context,
        type: SheetType.page,
        child: builder(context),
      ),
    ),
    false => showModalSideSheet<T>(
      useSafeArea: props.useSafeArea,
      context: context,
      constraints: BoxConstraints(maxWidth: props.maxWidth ?? 360),
      filter: props.blur ? commonFilter : null,
      builder: (_) {
        return _sheetHost(
          context: context,
          type: SheetType.sideSheet,
          child: builder(context),
        );
      },
    ),
  };
}

Widget _sheetHost({
  required BuildContext context,
  required SheetType type,
  required Widget child,
}) {
  final tvLayout = ProviderScope.containerOf(
    context,
    listen: false,
  ).read(tvLayoutProvider);
  return SheetProvider(
    type: type,
    child: tvLayout ? _TvSheetBack(child: child) : child,
  );
}

class _TvSheetBack extends StatefulWidget {
  const _TvSheetBack({required this.child});

  final Widget child;

  @override
  State<_TvSheetBack> createState() => _TvSheetBackState();
}

class _TvSheetBackState extends State<_TvSheetBack> implements PopEntry<void> {
  final TvBackDecision _decision = TvBackDecision();
  ModalRoute<void>? _route;

  @override
  final ValueNotifier<bool> canPopNotifier = ValueNotifier<bool>(true);

  @override
  void onPopInvoked(bool didPop) {}

  @override
  void onPopInvokedWithResult(bool didPop, void result) {
    if (didPop || ModalRoute.of(context)?.isCurrent != true) {
      return;
    }
    if (!_decision.consume(editableFocusWithin(context))) {
      return;
    }
    _syncCanPop();
  }

  @override
  void initState() {
    super.initState();
    _decision.onSettled = _syncCanPop;
    FocusManager.instance.addListener(_syncCanPop);
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncCanPop());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (identical(route, _route)) {
      return;
    }
    _route?.unregisterPopEntry(this);
    _route = route;
    _route?.registerPopEntry(this);
  }

  @override
  void dispose() {
    FocusManager.instance.removeListener(_syncCanPop);
    _decision.dispose();
    _route?.unregisterPopEntry(this);
    canPopNotifier.dispose();
    super.dispose();
  }

  void _syncCanPop() {
    if (!mounted) {
      return;
    }
    canPopNotifier.value = !editableFocusWithin(context) && !_decision.settling;
  }

  @override
  Widget build(BuildContext context) {
    return TvBackScope(decision: _decision, child: widget.child);
  }
}

class AdaptiveSheetScaffold extends StatefulWidget {
  final Widget body;
  final String title;
  final bool sheetTransparentToolBar;
  final bool bodyIncludesBottomSafeArea;
  final bool? centerTitle;
  final List<IconButtonData> actions;
  final VoidCallback? backAction;

  const AdaptiveSheetScaffold({
    super.key,
    required this.body,
    required this.title,
    this.sheetTransparentToolBar = false,
    this.bodyIncludesBottomSafeArea = false,
    this.centerTitle,
    this.actions = const [],
    this.backAction,
  });

  @override
  State<AdaptiveSheetScaffold> createState() => _AdaptiveSheetScaffoldState();
}

class _AdaptiveSheetScaffoldState extends State<AdaptiveSheetScaffold> {
  IconData get backIconData {
    if (kIsWeb) {
      return Icons.arrow_back;
    }
    switch (Theme.of(context).platform) {
      case TargetPlatform.android:
      case TargetPlatform.fuchsia:
      case TargetPlatform.linux:
      case TargetPlatform.windows:
        return Icons.arrow_back;
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return Icons.arrow_back_ios_new_rounded;
    }
  }

  @override
  void didUpdateWidget(covariant AdaptiveSheetScaffold oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.backAction != widget.backAction) {
      setState(() {});
    }
  }

  Widget _buildIconButton(IconButtonData data, {required bool filled}) {
    return _SheetIconButton(data: data, filled: filled);
  }

  IconButtonData _popButtonData(
    BuildContext context, {
    required bool useCloseIcon,
  }) {
    if (useCloseIcon) {
      return IconButtonData(
        icon: Icons.close,
        onPressed: context.safeNestedPop,
        tooltip: context.appLocalizations.close,
      );
    }
    return IconButtonData(
      icon: backIconData,
      onPressed: widget.backAction ?? () => Navigator.of(context).pop(),
      tooltip: context.appLocalizations.back,
    );
  }

  @override
  Widget build(BuildContext context) {
    final sheetProvider = SheetProvider.of(context);
    final type = sheetProvider?.type ?? SheetType.page;
    final isBottomSheet = type == SheetType.bottomSheet;
    final centerTitle = widget.centerTitle ?? isBottomSheet;

    if (type == SheetType.page) {
      return CommonScaffold(
        title: widget.title,
        centerTitle: centerTitle,
        actions: [
          for (final data in widget.actions)
            _buildIconButton(data, filled: false),
        ],
        body: widget.body,
      );
    }

    final nestedNavigatorPop = sheetProvider?.nestedNavigatorPop;
    final route = ModalRoute.of(context);
    final useCloseIcon =
        nestedNavigatorPop == null || route?.impliesAppBarDismissal == false;
    final actions = [
      for (final data in widget.actions)
        _buildIconButton(data, filled: isBottomSheet),
    ];
    final popButton = _buildIconButton(
      _popButtonData(context, useCloseIcon: useCloseIcon),
      filled: isBottomSheet,
    );
    final popAsSuffix = useCloseIcon && actions.isEmpty;
    final backgroundColor = isBottomSheet
        ? context.colorScheme.surfaceContainerLow
        : context.colorScheme.surface;
    final appBar = AppBar(
      backgroundColor: backgroundColor,
      forceMaterialTransparency: isBottomSheet,
      automaticallyImplyLeading: false,
      leading: popAsSuffix ? null : Center(child: popButton),
      centerTitle: centerTitle,
      toolbarHeight: isBottomSheet ? 48 : null,
      title: Text(widget.title),
      titleTextStyle: isBottomSheet
          ? context.textTheme.titleLarge?.adjustSize(-4)
          : null,
      actions: genActions(popAsSuffix ? [popButton] : actions),
    );
    if (!isBottomSheet) {
      return CommonScaffold(appBar: appBar, body: widget.body);
    }
    final sheetAppBar = _SheetToolBar(appBar: appBar);
    return ClipRSuperellipse(
      borderRadius: AppRadius.top(AppCorner.xxl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!widget.sheetTransparentToolBar) ...[
            sheetAppBar,
            Flexible(
              child: ScrollConfiguration(
                behavior: const ShowBarScrollBehavior(),
                child: widget.body,
              ),
            ),
          ] else
            Flexible(
              child: _TransparentToolBarBody(
                backgroundColor: backgroundColor,
                toolBar: sheetAppBar,
                body: widget.body,
              ),
            ),
          SizedBox(height: MediaQuery.viewInsetsOf(context).bottom),
          if (!widget.bodyIncludesBottomSafeArea)
            SizedBox(height: MediaQuery.viewPaddingOf(context).bottom),
        ],
      ),
    );
  }
}

class _SheetIconButton extends StatelessWidget {
  const _SheetIconButton({required this.data, required this.filled});

  static final _style = IconButton.styleFrom(
    visualDensity: VisualDensity.standard,
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
  );

  final IconButtonData data;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final icon = Icon(data.icon);
    if (filled) {
      return IconButton.filledTonal(
        tooltip: data.tooltip,
        onPressed: data.onPressed,
        style: _style,
        icon: icon,
      );
    }
    return IconButton(
      tooltip: data.tooltip,
      onPressed: data.onPressed,
      style: _style,
      icon: icon,
    );
  }
}

class _SheetToolBar extends StatelessWidget {
  const _SheetToolBar({required this.appBar});

  static const _handleSize = Size(28, 4);

  final Widget appBar;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Container(
            alignment: Alignment.center,
            height: _handleSize.height,
            width: _handleSize.width,
            decoration: ShapeDecoration(
              color: context.colorScheme.onSurfaceVariant,
              shape: AppShape.all(_handleSize.height / 2),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: appBar,
        ),
        const SizedBox(height: 6),
      ],
    );
  }
}

class _TransparentToolBarBody extends StatelessWidget {
  const _TransparentToolBarBody({
    required this.backgroundColor,
    required this.toolBar,
    required this.body,
  });

  final Color backgroundColor;
  final Widget toolBar;
  final Widget body;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ScrollConfiguration(
          behavior: const ShowBarScrollBehavior(
            scrollbarPadding: EdgeInsets.only(top: sheetAppBarHeight),
          ),
          child: body,
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: sheetAppBarHeight,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0, 0.5, 1],
                colors: [
                  backgroundColor.opacity60,
                  backgroundColor.opacity60,
                  backgroundColor.opacity0,
                ],
              ),
            ),
            child: Align(alignment: Alignment.topCenter, child: toolBar),
          ),
        ),
      ],
    );
  }
}
