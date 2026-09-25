import 'dart:math';

import 'package:fl_clash/providers/app.dart';
import 'package:fl_clash/common/shape.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'tv_back.dart';
import 'tv_layout.dart';

class CommonDialog extends ConsumerWidget {
  final String title;
  final Widget? child;
  final List<Widget>? actions;
  final EdgeInsets? padding;
  final bool overrideScroll;
  final Color? backgroundColor;
  final double maxWidth;
  final bool? isTV;

  const CommonDialog({
    super.key,
    required this.title,
    this.actions,
    this.child,
    this.padding,
    this.overrideScroll = false,
    this.backgroundColor,
    this.maxWidth = 300,
    this.isTV,
  });

  @override
  Widget build(BuildContext context, ref) {
    final size = ref.watch(viewSizeProvider);
    final bool useTvBack = isTV ?? ref.watch(tvLayoutProvider);
    final dialog = AlertDialog(
      title: Text(title),
      actions: actions,
      contentPadding: padding,
      backgroundColor: backgroundColor,
      content: ListTileTheme(
        data: const ListTileThemeData(shape: AppShape.md),
        child: Container(
          constraints: BoxConstraints(
            maxHeight: min(size.height - 40, 500),
            maxWidth: maxWidth,
          ),
          width: size.width - 40,
          child: !overrideScroll ? SingleChildScrollView(child: child) : child,
        ),
      ),
    );
    if (!useTvBack) {
      return dialog;
    }
    return TvBackHost(
      child: Builder(
        builder: (context) {
          return PopScope(
            canPop: false,
            onPopInvokedWithResult: (didPop, _) {
              if (didPop || ModalRoute.of(context)?.isCurrent != true) {
                return;
              }
              if (TvBackScope.consume(context)) {
                return;
              }
              Navigator.of(context).pop();
            },
            child: dialog,
          );
        },
      ),
    );
  }
}

class CommonModal extends ConsumerWidget {
  final Widget? child;

  const CommonModal({super.key, this.child});

  @override
  Widget build(BuildContext context, ref) {
    final size = ref.watch(viewSizeProvider);
    return Center(
      child: Container(
        width: size.width * 0.85,
        height: size.height * 0.85,
        decoration: const ShapeDecoration(shape: AppShape.xxl),
        clipBehavior: Clip.antiAlias,
        child: child,
      ),
    );
  }
}
