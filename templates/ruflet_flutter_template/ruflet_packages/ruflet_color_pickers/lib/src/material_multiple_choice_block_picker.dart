import 'package:ruflet/ruflet.dart';
import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

class MaterialMultipleChoiceBlockPickerControl extends StatefulWidget {
  final Control control;

  const MaterialMultipleChoiceBlockPickerControl(
      {super.key, required this.control});

  @override
  State<MaterialMultipleChoiceBlockPickerControl> createState() =>
      _MaterialMultipleChoiceBlockPickerControlState();
}

class _MaterialMultipleChoiceBlockPickerControlState
    extends State<MaterialMultipleChoiceBlockPickerControl> {
  List<Color> _pickerColors = [Colors.black];

  // The picker keeps the selection of its first build; rebuild it when Ruby
  // changes `colors`, not when the control echoes the user's own toggles.
  List<int>? _selection;
  int _rubyColorsVersion = 0;

  void _onColorsChanged(List<Color> colors) {
    setState(() {
      _pickerColors = colors;
      _selection = [for (final color in colors) color.toARGB32()];
    });
    final colorsHex = colors.map((color) => color.toHex()).toList();
    widget.control.updateProperties({"colors": colorsHex}, notify: true);
    widget.control.triggerEvent("colors_change", colorsHex);
  }

  @override
  Widget build(BuildContext context) {
    debugPrint(
        "MaterialMultipleChoiceBlockPickerControl build: ${widget.control.id}");

    final rawColors = widget.control.get("colors");
    final theme = RufletStyleTheme.of(context);
    final parsedColors = <Color>[];
    if (rawColors is List) {
      for (final raw in rawColors) {
        final parsed = parseColor(raw?.toString(), theme);
        if (parsed != null) {
          parsedColors.add(parsed);
        }
      }
    }
    if (parsedColors.isNotEmpty) {
      final selection = [for (final color in parsedColors) color.toARGB32()];
      if (!listEquals(selection, _selection)) {
        _selection = selection;
        _rubyColorsVersion++;
      }
      _pickerColors = parsedColors;
    } else if (_pickerColors.isEmpty) {
      _pickerColors = [Colors.black];
    }

    final rawAvailableColors = widget.control.get("available_colors");
    final availableColors = <Color>[];
    if (rawAvailableColors is List) {
      for (final raw in rawAvailableColors) {
        final parsed = parseColor(raw?.toString(), theme);
        if (parsed != null) {
          availableColors.add(parsed);
        }
      }
    }

    final picker = availableColors.isNotEmpty
        ? MultipleChoiceBlockPicker(
            key: ValueKey(_rubyColorsVersion),
            pickerColors: _pickerColors,
            onColorsChanged: _onColorsChanged,
            availableColors: availableColors,
          )
        : MultipleChoiceBlockPicker(
            key: ValueKey(_rubyColorsVersion),
            pickerColors: _pickerColors,
            onColorsChanged: _onColorsChanged,
          );

    return LayoutControl(control: widget.control, child: picker);
  }
}
