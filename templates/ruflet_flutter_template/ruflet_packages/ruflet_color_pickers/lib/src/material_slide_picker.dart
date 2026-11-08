import 'package:ruflet/ruflet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

import 'utils/color_pickers.dart';

class MaterialSlidePickerControl extends StatefulWidget {
  final Control control;

  const MaterialSlidePickerControl({super.key, required this.control});

  @override
  State<MaterialSlidePickerControl> createState() =>
      _MaterialSlidePickerControlState();
}

class _MaterialSlidePickerControlState
    extends State<MaterialSlidePickerControl> {
  Color _pickerColor = Colors.black;

  void _onColorChanged(Color color) {
    final colorHex = color.toHex();
    widget.control.triggerEvent("color_change", colorHex);
  }

  @override
  Widget build(BuildContext context) {
    debugPrint("MaterialSlidePickerControl build: ${widget.control.id}");

    final controlColor =
        widget.control.getColor("color", context) ?? Colors.black;
    if (controlColor.toARGB32() != _pickerColor.toARGB32()) {
      _pickerColor = controlColor;
    }

    final colorModel = parseColorModel(
        widget.control.get("color_model")?.toString(), ColorModel.rgb);
    final rawLabelTypes = widget.control.get("label_types");
    final labelTypes = <ColorLabelType>[];
    if (rawLabelTypes is List) {
      for (final raw in rawLabelTypes) {
        final parsed = parseLabelType(raw?.toString());
        if (parsed != null) {
          labelTypes.add(parsed);
        }
      }
    }
    final labelTypesArg =
        rawLabelTypes is List ? labelTypes : const <ColorLabelType>[];

    final picker = SlidePicker(
      pickerColor: _pickerColor,
      onColorChanged: _onColorChanged,
      colorModel: colorModel ?? ColorModel.rgb,
      displayThumbColor: widget.control.getBool("display_thumb_color", true)!,
      enableAlpha: widget.control.getBool("enable_alpha", true)!,
      indicatorAlignmentBegin: widget.control.getAlignment(
          "indicator_alignment_begin", const Alignment(-1.0, -3.0))!,
      indicatorAlignmentEnd: widget.control
          .getAlignment("indicator_alignment_end", const Alignment(1.0, 3.0))!,
      indicatorBorderRadius:
          widget.control.getBorderRadius("indicator_border_radius") ??
              const BorderRadius.all(Radius.zero),
      indicatorSize:
          widget.control.getSize("indicator_size", const Size(280, 50))!,
      // The upstream replacement for labelTextStyle/sliderTextStyle is a
      // Theme text-role override, which cannot reproduce a per-control style
      // without changing rendering, so these two stay on the deprecated API.
      // ignore: deprecated_member_use
      labelTextStyle: widget.control
          .getTextStyle("label_text_style", RufletStyleTheme.of(context)),
      // `showLabel: false` is the same as no label types (the picker only
      // draws the label when both are set).
      labelTypes: widget.control.getBool("show_label", true)!
          ? labelTypesArg
          : const <ColorLabelType>[],
      showIndicator: widget.control.getBool("show_indicator", true)!,
      showParams: widget.control.getBool("show_params", true)!,
      showSliderText: widget.control.getBool("show_slider_text", true)!,
      sliderSize: widget.control.getSize("slider_size", const Size(260, 40))!,
      // ignore: deprecated_member_use
      sliderTextStyle: widget.control
          .getTextStyle("slider_text_style", RufletStyleTheme.of(context)),
    );

    return LayoutControl(control: widget.control, child: picker);
  }
}
