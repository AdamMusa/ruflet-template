import 'package:flutter/widgets.dart';

import '../models/control.dart';
import '../widgets/platform_control_renderer.dart';
import 'cupertino_date_picker_dialog.dart';
import 'material_picker_controls.dart';

class AdaptiveDatePickerControl extends StatelessWidget {
  final Control control;

  const AdaptiveDatePickerControl({super.key, required this.control});

  @override
  Widget build(BuildContext context) {
    return PlatformControlRenderer(
      material: (_) => MaterialDatePickerRenderer(control: control),
      cupertino: (_) => CupertinoDatePickerRenderer(control: control),
    );
  }
}
