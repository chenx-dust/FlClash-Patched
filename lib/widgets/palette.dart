import 'package:flutter/material.dart';
import 'package:material_color_utilities/hct/hct.dart';

import 'theme.dart';

@immutable
class Palette extends StatefulWidget {
  const Palette({super.key, required this.controller});

  final ValueNotifier<Color> controller;

  @override
  State<Palette> createState() => _PaletteState();
}

class _PaletteState extends State<Palette> {
  double _hue = 0;
  double _chroma = 0;
  double _tone = 0;

  @override
  void initState() {
    super.initState();
    _initFromColor(widget.controller.value);
  }

  void _initFromColor(Color color) {
    final hct = Hct.fromInt(color.toARGB32());
    _hue = hct.hue;
    _chroma = hct.chroma;
    _tone = hct.tone;
  }

  Color _toColor() => Color(Hct.from(_hue, _chroma, _tone).toInt());

  void _onHueChanged(double value) {
    setState(() => _hue = value);
    widget.controller.value = _toColor();
  }

  void _onChromaChanged(double value) {
    setState(() => _chroma = value);
    widget.controller.value = _toColor();
  }

  void _onToneSelected(double tone) {
    setState(() => _tone = tone);
    widget.controller.value = _toColor();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: widget.controller,
      builder: (_, _, _) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _HueSlider(hue: _hue, onChanged: _onHueChanged),
            const SizedBox(height: 16),
            _ChromaSlider(
              hue: _hue,
              chroma: _chroma,
              onChanged: _onChromaChanged,
            ),
            const SizedBox(height: 16),
            _ToneGrid(
              hue: _hue,
              chroma: _chroma,
              selectedTone: _tone,
              onToneSelected: _onToneSelected,
            ),
          ],
        );
      },
    );
  }
}

class _HueSlider extends StatelessWidget {
  const _HueSlider({required this.hue, required this.onChanged});

  final double hue;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return SliderTheme(
      data: SliderDefaultsM3(context).copyWith(
        trackShape: _HueTrackShape(),
        thumbColor: Color(Hct.from(hue, 60, 48).toInt()),
      ),
      child: Slider(value: hue, min: 0, max: 360, onChanged: onChanged),
    );
  }
}

class _ChromaSlider extends StatelessWidget {
  const _ChromaSlider({
    required this.hue,
    required this.chroma,
    required this.onChanged,
  });

  final double hue;
  final double chroma;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return SliderTheme(
      data: SliderDefaultsM3(context).copyWith(
        trackShape: _ChromaTrackShape(hue: hue),
        thumbColor: Color(Hct.from(hue, chroma, 60).toInt()),
      ),
      child: Slider(
        value: chroma.clamp(0, 150),
        min: 0,
        max: 150,
        onChanged: onChanged,
      ),
    );
  }
}

class _HueTrackShape extends SliderTrackShape {
  @override
  Rect getPreferredRect({
    required RenderBox parentBox,
    Offset offset = Offset.zero,
    required SliderThemeData sliderTheme,
    bool isEnabled = false,
    bool isDiscrete = false,
  }) {
    final trackHeight = sliderTheme.trackHeight ?? 24;
    final trackTop = offset.dy + (parentBox.size.height - trackHeight) / 2;
    return Rect.fromLTWH(
      offset.dx + 16,
      trackTop,
      parentBox.size.width - 32,
      trackHeight,
    );
  }

  @override
  void paint(
    PaintingContext context,
    Offset offset, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation,
    required TextDirection textDirection,
    required Offset thumbCenter,
    Offset? secondaryOffset,
    bool isDiscrete = false,
    bool isEnabled = false,
  }) {
    final rect = getPreferredRect(
      parentBox: parentBox,
      offset: offset,
      sliderTheme: sliderTheme,
      isEnabled: isEnabled,
      isDiscrete: isDiscrete,
    );
    final colors = <Color>[];
    for (int i = 0; i <= 360; i += 10) {
      colors.add(Color(Hct.from(i.toDouble(), 48, 60).toInt()));
    }
    final shader = LinearGradient(colors: colors).createShader(rect);
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(12));
    context.canvas.drawRRect(rrect, Paint()..shader = shader);
  }
}

class _ChromaTrackShape extends SliderTrackShape {
  const _ChromaTrackShape({required this.hue});

  final double hue;

  @override
  Rect getPreferredRect({
    required RenderBox parentBox,
    Offset offset = Offset.zero,
    required SliderThemeData sliderTheme,
    bool isEnabled = false,
    bool isDiscrete = false,
  }) {
    final trackHeight = sliderTheme.trackHeight ?? 24;
    final trackTop = offset.dy + (parentBox.size.height - trackHeight) / 2;
    return Rect.fromLTWH(
      offset.dx + 16,
      trackTop,
      parentBox.size.width - 32,
      trackHeight,
    );
  }

  @override
  void paint(
    PaintingContext context,
    Offset offset, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation,
    required TextDirection textDirection,
    required Offset thumbCenter,
    Offset? secondaryOffset,
    bool isDiscrete = false,
    bool isEnabled = false,
  }) {
    final rect = getPreferredRect(
      parentBox: parentBox,
      offset: offset,
      sliderTheme: sliderTheme,
      isEnabled: isEnabled,
      isDiscrete: isDiscrete,
    );
    final colors = <Color>[];
    for (int i = 0; i <= 49; i++) {
      colors.add(Color(Hct.from(hue, (i / 49) * 150, 60).toInt()));
    }
    final shader = LinearGradient(colors: colors).createShader(rect);
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(12));
    context.canvas.drawRRect(rrect, Paint()..shader = shader);
  }
}

class _ToneGrid extends StatelessWidget {
  const _ToneGrid({
    required this.hue,
    required this.chroma,
    required this.selectedTone,
    required this.onToneSelected,
  });

  final double hue;
  final double chroma;
  final double selectedTone;
  final ValueChanged<double> onToneSelected;

  static const _tones = [0, 10, 20, 30, 40, 50, 60, 70, 80, 90, 100];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _tones.map((tone) {
        final color = Color(Hct.from(hue, chroma, tone.toDouble()).toInt());
        final isSelected = tone == selectedTone.round();
        final textColor = tone <= 50 ? Colors.white : Colors.black;
        return GestureDetector(
          onTap: () => onToneSelected(tone.toDouble()),
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(8),
              border: isSelected
                  ? Border.all(
                      color: Theme.of(context).colorScheme.primary,
                      width: 3,
                    )
                  : null,
            ),
            alignment: Alignment.center,
            child: Text(
              '$tone',
              style: TextStyle(
                color: textColor,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
