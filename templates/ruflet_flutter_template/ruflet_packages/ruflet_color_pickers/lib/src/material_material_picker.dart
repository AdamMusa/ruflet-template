import 'package:ruflet/ruflet.dart';
import 'package:flutter/material.dart';
import 'material_swatch_picker/material_swatch_picker.dart';

class MaterialMaterialPickerControl extends StatefulWidget {
  final Control control;

  const MaterialMaterialPickerControl({super.key, required this.control});

  @override
  State<MaterialMaterialPickerControl> createState() =>
      _MaterialMaterialPickerControlState();
}

class _MaterialMaterialPickerControlState
    extends State<MaterialMaterialPickerControl> {
  Color _pickerColor = Colors.black;

  // The picker keeps the selection of its first build; rebuild it when Ruby
  // changes `color`, not when the control echoes the user's own pick.
  int _rubyColorVersion = 0;

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
    debugPrint("MaterialMaterialPickerControl build: ${widget.control.id}");

    final controlColor =
        widget.control.getColor("color", context) ?? Colors.black;
    if (controlColor.toARGB32() != _pickerColor.toARGB32()) {
      _pickerColor = controlColor;
      _rubyColorVersion++;
    }

    final picker = MaterialSwatchPicker(
      key: ValueKey(_rubyColorVersion),
      pickerColor: _pickerColor,
      onColorChanged: _onColorChanged,
      onPrimaryChanged: _onPrimaryChanged,
      enableLabel: widget.control.getBool("enable_label", false)!,
      portraitOnly: widget.control.getBool("portrait_only", false)!,
    );

    return LayoutControl(control: widget.control, child: picker);
  }
}
