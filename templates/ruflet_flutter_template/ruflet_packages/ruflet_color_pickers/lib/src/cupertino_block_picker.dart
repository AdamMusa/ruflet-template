import 'package:ruflet/ruflet.dart';
import 'package:flutter/cupertino.dart';
import 'cupertino_picker/cupertino_picker.dart';

class CupertinoBlockPickerControl extends StatefulWidget {
  final Control control;

  const CupertinoBlockPickerControl({super.key, required this.control});

  @override
  State<CupertinoBlockPickerControl> createState() =>
      _CupertinoBlockPickerControlState();
}

class _CupertinoBlockPickerControlState
    extends State<CupertinoBlockPickerControl> {
  Color _pickerColor = PaletteColors.black;

  void _onColorChanged(Color color) {
    setState(() {
      _pickerColor = color;
    });
    final colorHex = color.toHex();
    widget.control.updateProperties({"color": colorHex}, notify: true);
    widget.control.triggerEvent("color_change", colorHex);
  }

  @override
  Widget build(BuildContext context) {
    debugPrint("CupertinoBlockPickerControl build: ${widget.control.id}");

    final controlColor =
        widget.control.getColor("color", context) ?? PaletteColors.black;
    if (controlColor.value != _pickerColor.value) {
      _pickerColor = controlColor;
    }

    final rawColors = widget.control.get("available_colors");
    final theme = RufletStyleTheme.of(context);
    final availableColors = <Color>[];
    if (rawColors is List) {
      for (final raw in rawColors) {
        final parsed = parseColor(raw?.toString(), theme);
        if (parsed != null) {
          availableColors.add(parsed);
        }
      }
    }
    final picker = availableColors.isNotEmpty
        ? BlockPicker(
            pickerColor: _pickerColor,
            onColorChanged: _onColorChanged,
            availableColors: availableColors,
          )
        : BlockPicker(
            pickerColor: _pickerColor,
            onColorChanged: _onColorChanged,
          );

    return LayoutControl(control: widget.control, child: picker);
  }
}
