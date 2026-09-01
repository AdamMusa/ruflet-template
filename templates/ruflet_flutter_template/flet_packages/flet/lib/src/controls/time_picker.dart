import 'package:flutter/widgets.dart';

import '../models/control.dart';
import '../widgets/platform_control_renderer.dart';
import 'cupertino_input_controls.dart';
import 'material_time_picker.dart';

class TimePickerControl extends StatelessWidget {
  final Control control;

  const TimePickerControl({super.key, required this.control});

  @override
  Widget build(BuildContext context) => PlatformControlRenderer(
        material: (_) => MaterialTimePickerControl(control: control),
        cupertino: (_) => CupertinoTimePickerControl(control: control),
      );
}
