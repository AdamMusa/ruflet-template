import 'package:ruflet/ruflet.dart';
import 'package:flutter/widgets.dart';

import 'cupertino_hue_ring_picker.dart';
import 'material_hue_ring_picker.dart';

class HueRingPickerControl extends StatelessWidget {
  final Control control;
  const HueRingPickerControl({super.key, required this.control});

  @override
  Widget build(BuildContext context) => PlatformControlRenderer(
        material: (_) => MaterialHueRingPickerControl(control: control),
        cupertino: (_) => CupertinoHueRingPickerControl(control: control),
      );
}
