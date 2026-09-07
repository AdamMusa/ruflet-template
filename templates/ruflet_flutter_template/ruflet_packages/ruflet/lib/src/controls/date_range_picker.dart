import 'package:flutter/widgets.dart';

import '../models/control.dart';
import '../widgets/platform_control_renderer.dart';
import 'cupertino_input_controls.dart';
import 'material_date_range_picker.dart';

class DateRangePickerControl extends StatelessWidget {
  final Control control;

  const DateRangePickerControl({super.key, required this.control});

  @override
  Widget build(BuildContext context) => PlatformControlRenderer(
        material: (_) => MaterialDateRangePickerControl(control: control),
        cupertino: (_) => CupertinoDateRangePickerControl(control: control),
      );
}
