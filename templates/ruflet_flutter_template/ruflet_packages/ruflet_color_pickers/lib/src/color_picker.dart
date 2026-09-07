import 'package:ruflet/ruflet.dart';
import 'package:flutter/widgets.dart';

import 'cupertino_color_picker.dart';
import 'material_color_picker.dart';

class ColorPickerControl extends StatelessWidget {
  final Control control;
  const ColorPickerControl({super.key, required this.control});

  @override
  Widget build(BuildContext context) => PlatformControlRenderer(
        material: (_) => MaterialColorPickerControl(control: control),
        cupertino: (_) => CupertinoColorPickerControl(control: control),
      );
}
