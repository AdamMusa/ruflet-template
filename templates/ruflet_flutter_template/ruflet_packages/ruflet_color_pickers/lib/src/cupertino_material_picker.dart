import 'package:ruflet/ruflet.dart';
import 'package:flutter/cupertino.dart';
import 'cupertino_picker/cupertino_picker.dart';

class CupertinoMaterialPickerControl extends StatefulWidget {
  final Control control;

  const CupertinoMaterialPickerControl({super.key, required this.control});

  @override
  State<CupertinoMaterialPickerControl> createState() =>
      _CupertinoMaterialPickerControlState();
}

class _CupertinoMaterialPickerControlState
    extends State<CupertinoMaterialPickerControl> {
  Color _pickerColor = PaletteColors.black;

  void _onColorChanged(Color color) {
    setState(() {
      _pickerColor = color;
    });
    final colorHex = color.toHex();
    widget.control.updateProperties({"color": colorHex}, notify: true);
    widget.control.triggerEvent("color_change", colorHex);
  }

  void _onPrimaryChanged(Color color) {
    final colorHex = color.toHex();
    widget.control.triggerEvent("primary_change", colorHex);
  }

  @override
  Widget build(BuildContext context) {
    debugPrint("CupertinoMaterialPickerControl build: ${widget.control.id}");

    final controlColor =
        widget.control.getColor("color", context) ?? PaletteColors.black;
    if (controlColor.value != _pickerColor.value) {
      _pickerColor = controlColor;
    }

    final picker = CupertinoSwatchPicker(
      pickerColor: _pickerColor,
      onColorChanged: _onColorChanged,
      onPrimaryChanged: _onPrimaryChanged,
      enableLabel: widget.control.getBool("enable_label", false)!,
      portraitOnly: widget.control.getBool("portrait_only", false)!,
    );

    return LayoutControl(control: widget.control, child: picker);
  }
}
