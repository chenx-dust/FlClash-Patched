import 'package:emoji_regex/emoji_regex.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:material_ui/material_ui.dart';

import '../state.dart';

final _emojiRegex = emojiRegex();

String getFirstEmoji(String text) {
  return _emojiRegex.firstMatch(text)?.group(0) ?? '';
}

String removeLeadingEmoji(String text) {
  var value = text;
  var match = _emojiRegex.matchAsPrefix(value);
  while (match != null) {
    value = value.substring(match.end).trimLeft();
    match = _emojiRegex.matchAsPrefix(value);
  }
  return value;
}

List<TextSpan> _emojiSpans(String text, TextStyle? style) {
  final spans = <TextSpan>[];
  final matches = _emojiRegex.allMatches(text);
  var lastMatchEnd = 0;
  for (final match in matches) {
    if (match.start > lastMatchEnd) {
      spans.add(
        TextSpan(text: text.substring(lastMatchEnd, match.start), style: style),
      );
    }
    spans.add(
      TextSpan(
        text: match.group(0),
        style: style?.copyWith(fontFamily: FontFamily.twEmoji.value),
      ),
    );
    lastMatchEnd = match.end;
  }
  if (lastMatchEnd < text.length) {
    spans.add(TextSpan(text: text.substring(lastMatchEnd), style: style));
  }
  return spans;
}

bool _emojiTextExceedsMaxLines({
  required BuildContext context,
  required String text,
  required TextStyle? style,
  required double maxWidth,
  required int maxLines,
}) {
  if (text.isEmpty || maxWidth <= 0 || !maxWidth.isFinite) {
    return false;
  }
  final painter = TextPainter(
    text: TextSpan(children: _emojiSpans(text, style)),
    maxLines: maxLines,
    textScaler: MediaQuery.textScalerOf(context),
    textDirection: Directionality.of(context),
    locale: Localizations.maybeLocaleOf(context),
    ellipsis: '\u2026',
  )..layout(maxWidth: maxWidth);
  try {
    return painter.didExceedMaxLines;
  } finally {
    painter.dispose();
  }
}

class OverflowHoverTooltip extends StatelessWidget {
  const OverflowHoverTooltip({
    super.key,
    required this.message,
    required this.maxWidth,
    required this.style,
    this.maxLines = 1,
    required this.child,
  });

  final String message;
  final double maxWidth;
  final TextStyle? style;
  final int maxLines;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final overflows = _emojiTextExceedsMaxLines(
      context: context,
      text: message,
      style: style,
      maxWidth: maxWidth,
      maxLines: maxLines,
    );
    if (!overflows) {
      return child;
    }
    return Tooltip(
      message: message,
      preferBelow: false,
      triggerMode: TooltipTriggerMode.longPress,
      child: child,
    );
  }
}

class TooltipText extends StatelessWidget {
  final Text text;

  const TooltipText({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        final isOverflow = globalState.measure.computeTextIsOverflow(
          text,
          maxWidth: maxWidth,
        );
        if (isOverflow) {
          return Tooltip(
            triggerMode: TooltipTriggerMode.longPress,
            preferBelow: false,
            message: text.data,
            child: text,
          );
        }
        return text;
      },
    );
  }
}

class TooltipLabel extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final int maxLines;

  const TooltipLabel(this.text, {super.key, this.style, this.maxLines = 2});

  @override
  Widget build(BuildContext context) {
    return TooltipText(
      text: Text(
        text,
        maxLines: maxLines,
        overflow: TextOverflow.ellipsis,
        style: DefaultTextStyle.of(context).style.merge(style),
      ),
    );
  }
}

class TooltipTextV2 extends StatefulWidget {
  final Text text;

  const TooltipTextV2({super.key, required this.text});

  @override
  State<TooltipTextV2> createState() => _TooltipTextV2State();
}

class _TooltipTextV2State extends State<TooltipTextV2> {
  bool _isOverflow = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkOverflow();
    });
  }

  void _checkOverflow() {
    if (!mounted) {
      return;
    }
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final isOverflow = globalState.measure.computeTextIsOverflow(
      widget.text,
      maxWidth: renderBox.size.width,
    );
    setState(() => _isOverflow = isOverflow);
  }

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      triggerMode: TooltipTriggerMode.longPress,
      preferBelow: false,
      message: _isOverflow ? widget.text.data : '',
      child: widget.text,
    );
  }
}

class EmojiText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;

  const EmojiText(
    this.text, {
    super.key,
    this.maxLines,
    this.overflow,
    this.style,
  });

  @override
  Widget build(BuildContext context) {
    return RichText(
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: maxLines,
      overflow: overflow ?? TextOverflow.clip,
      text: TextSpan(children: _emojiSpans(text, style)),
    );
  }
}
