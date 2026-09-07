import 'package:ruflet/ruflet.dart';
import 'package:flutter/cupertino.dart';
import 'cupertino_picker/cupertino_picker.dart';

class CupertinoHueRingPickerControl extends StatefulWidget {
  final Control control;

  const CupertinoHueRingPickerControl({super.key, required this.control});

  @override
  State<CupertinoHueRingPickerControl> createState() =>
      _CupertinoHueRingPickerControlState();
}

class _CupertinoHueRingPickerControlState
    extends State<CupertinoHueRingPickerControl> {
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
    debugPrint("CupertinoHueRingPickerControl build: ${widget.control.id}");

    final controlColor =
        widget.control.getColor("color", context) ?? PaletteColors.black;
    if (controlColor.value != _pickerColor.value) {
      _pickerColor = controlColor;
    }

    final picker = HueRingPicker(
      pickerColor: _pickerColor,
      onColorChanged: _onColorChanged,
      colorPickerHeight:
          widget.control.getDouble("color_picker_height") ?? 250.0,
      enableAlpha: widget.control.getBool("enable_alpha", false)!,
      hueRingStrokeWidth:
          widget.control.getDouble("hue_ring_stroke_width") ?? 20.0,
      pickerAreaBorderRadius:
          widget.control.getBorderRadius("picker_area_border_radius") ??
              const BorderRadius.all(Radius.zero),
      portraitOnly: widget.control.getBool("portrait_only", false)!,
    );

    return LayoutControl(control: widget.control, child: picker);
  }
}
