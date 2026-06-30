import 'dart:async';
import 'dart:math';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/widgets/fade_box.dart';
import 'package:fl_clash/widgets/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class StatusManager extends StatefulWidget {
  final Widget child;

  const StatusManager({super.key, required this.child});

  @override
  State<StatusManager> createState() => StatusManagerState();
}

class StatusManagerState extends State<StatusManager> {
  final _messagesNotifier = ValueNotifier<List<CommonMessage>>([]);
  final _activeTimers = <String, Timer>{};

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _messagesNotifier.dispose();
    for (final timer in _activeTimers.values) {
      timer.cancel();
    }
    _activeTimers.clear();
    super.dispose();
  }

  void message(String text, {MessageActionState? actionState}) {
    final commonMessage = CommonMessage(
      id: utils.uuidV4,
      text: text,
      actionState: actionState,
    );
    commonPrint.log('message: $text');
    _showMessage(commonMessage);
  }

  void _showMessage(CommonMessage message) {
    for (final timer in _activeTimers.values) {
      timer.cancel();
    }
    _activeTimers.clear();
    _messagesNotifier.value = [message];
    final timer = Timer(message.duration, () {
      _removeMessage(message.id);
    });
    _activeTimers[message.id] = timer;
  }

  void _removeMessage(String id) {
    _activeTimers.remove(id)?.cancel();
    final currentMessages = List<CommonMessage>.from(_messagesNotifier.value);
    currentMessages.removeWhere((msg) => msg.id == id);
    _messagesNotifier.value = currentMessages;
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        Consumer(
          builder: (_, ref, child) {
            final top = ref.watch(overlayTopOffsetProvider);
            return Container(
              margin: EdgeInsets.only(
                top: top + MediaQuery.of(context).viewPadding.top + 8,
              ),
              child: child,
            );
          },
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: AnimatedSize(
                  duration: animateDuration,
                  child: ValueListenableBuilder(
                    valueListenable: _messagesNotifier,
                    builder: (_, messages, _) {
                      return FadeThroughBox(
                        alignment: Alignment.centerRight,
                        child: messages.isEmpty
                            ? const SizedBox()
                            : LayoutBuilder(
                                key: Key(messages.last.id),
                                builder: (_, constraints) {
                                  final message = messages.last;
                                  final actionState = message.actionState;
                                  final cardWidth = min(
                                    constraints.maxWidth,
                                    500.0,
                                  );
                                  final showCloseButton = cardWidth >= 480;
                                  return Dismissible(
                                    key: ValueKey(message.id),
                                    onDismissed: (_) {
                                      _removeMessage(message.id);
                                    },
                                    child: Card(
                                      clipBehavior: Clip.antiAlias,
                                      shape: const RoundedSuperellipseBorder(
                                        borderRadius: BorderRadius.all(
                                          Radius.circular(14),
                                        ),
                                      ),
                                      elevation: 10,
                                      color: context
                                          .colorScheme
                                          .surfaceContainerHigh,
                                      child: InkWell(
                                        onLongPress: () {
                                          Clipboard.setData(
                                            ClipboardData(text: message.text),
                                          );
                                        },
                                        child: Container(
                                          width: cardWidth,
                                          constraints: const BoxConstraints(
                                            minHeight: 54,
                                          ),
                                          padding: const EdgeInsets.all(8),
                                          child: Row(
                                            children: [
                                              Expanded(
                                                child: Padding(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                      ),
                                                  child: Text(
                                                    message.text,
                                                    maxLines: 3,
                                                    style: context
                                                        .textTheme
                                                        .labelLarge
                                                        ?.copyWith(
                                                          color: context
                                                              .colorScheme
                                                              .onSurfaceVariant,
                                                        ),
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ),
                                              if (actionState != null) ...[
                                                CommonMinFilledButtonTheme(
                                                  child: FilledButton.tonal(
                                                    onPressed: () async {
                                                      _removeMessage(
                                                        message.id,
                                                      );
                                                      actionState.action();
                                                    },
                                                    child: Text(
                                                      actionState.actionText,
                                                    ),
                                                  ),
                                                ),
                                                if (showCloseButton)
                                                  const SizedBox(width: 4),
                                              ] else if (showCloseButton) ...[
                                                IconButton(
                                                  style: IconButton.styleFrom(
                                                    fixedSize:
                                                        const Size.square(32),
                                                    padding: EdgeInsets.zero,
                                                    shape: const CircleBorder(),
                                                    tapTargetSize:
                                                        MaterialTapTargetSize
                                                            .shrinkWrap,
                                                  ),
                                                  visualDensity:
                                                      VisualDensity.compact,
                                                  iconSize: 20,
                                                  onPressed: () {
                                                    Clipboard.setData(
                                                      ClipboardData(
                                                        text: message.text,
                                                      ),
                                                    );
                                                  },
                                                  icon: const Icon(Icons.copy),
                                                ),
                                                const SizedBox(width: 4),
                                              ],
                                              if (showCloseButton)
                                                IconButton(
                                                  style: IconButton.styleFrom(
                                                    fixedSize:
                                                        const Size.square(32),
                                                    padding: EdgeInsets.zero,
                                                    shape: const CircleBorder(),
                                                    tapTargetSize:
                                                        MaterialTapTargetSize
                                                            .shrinkWrap,
                                                  ),
                                                  visualDensity:
                                                      VisualDensity.compact,
                                                  iconSize: 20,
                                                  onPressed: () {
                                                    _removeMessage(message.id);
                                                  },
                                                  icon: const Icon(Icons.close),
                                                ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                      );
                    },
                  ),
                ),
              ),
              // LoadingIndicator(),
            ],
          ),
        ),
      ],
    );
  }
}

// class LoadingIndicator extends ConsumerWidget {
//   const LoadingIndicator({super.key});
//
//   @override
//   Widget build(BuildContext context, ref) {
//     final loading = ref.watch(loadingProvider);
//     final isMobileView = ref.watch(isMobileViewProvider);
//     return AnimatedSwitcher(
//       switchInCurve: Curves.easeIn,
//       switchOutCurve: Curves.easeOut,
//       duration: midDuration,
//       transitionBuilder: (Widget child, Animation<double> animation) {
//         return SlideTransition(
//           position: Tween<Offset>(
//             begin: const Offset(1, 0),
//             end: Offset.zero,
//           ).animate(animation),
//           child: child,
//         );
//       },
//       child: loading && isMobileView
//           ? Container(
//               height: 54,
//               margin: EdgeInsets.only(top: 8, left: 14, right: 14),
//               child: Material(
//                 elevation: 3,
//                 color: context.colorScheme.surfaceContainer,
//                 surfaceTintColor: context.colorScheme.surfaceTint,
//                 shape: const RoundedSuperellipseBorder(
//                   borderRadius: BorderRadius.all(Radius.circular(14)),
//                 ),
//                 child: Padding(
//                   padding: EdgeInsets.symmetric(horizontal: 16),
//                   child: Row(
//                     mainAxisSize: MainAxisSize.min,
//                     spacing: 12,
//                     mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                     children: [
//                       Flexible(
//                         child: Text(
//                           context.appLocalizations.loading,
//                           style: context.textTheme.labelLarge?.copyWith(
//                             color: context.colorScheme.onSurfaceVariant,
//                           ),
//                         ),
//                       ),
//                       SizedBox(
//                         height: 32,
//                         width: 32,
//                         child: CommonCircleLoading(),
//                       ),
//                     ],
//                   ),
//                 ),
//               ),
//             )
//           : SizedBox(),
//     );
//   }
// }
