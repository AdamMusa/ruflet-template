import 'package:flutter/widgets.dart';

import '../models/control.dart';
import '../widgets/platform_control_renderer.dart';
import 'cupertino_input_controls.dart';
import 'material_range_slider.dart';

class RangeSliderControl extends StatelessWidget {
  final Control control;

  const RangeSliderControl({super.key, required this.control});

  @override
  Widget build(BuildContext context) => PlatformControlRenderer(
        material: (_) => MaterialRangeSliderControl(control: control),
        cupertino: (_) => CupertinoRangeSliderControl(control: control),
      );
}
