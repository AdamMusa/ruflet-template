import 'package:flutter/widgets.dart';

import '../models/control.dart';
import '../widgets/platform_control_renderer.dart';
import 'cupertino_timer_picker.dart';
import 'material_picker_controls.dart';

class AdaptiveTimerPickerControl extends StatelessWidget {
  final Control control;

  const AdaptiveTimerPickerControl({super.key, required this.control});

  @override
  Widget build(BuildContext context) {
    return PlatformControlRenderer(
      material: (_) => MaterialTimerPickerControl(control: control),
      cupertino: (_) => CupertinoTimerPickerControl(control: control),
    );
  }
}
