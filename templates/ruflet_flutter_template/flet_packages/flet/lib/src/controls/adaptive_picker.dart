import 'package:flutter/widgets.dart';

import '../models/control.dart';
import '../widgets/platform_control_renderer.dart';
import 'cupertino_picker.dart';
import 'material_picker_controls.dart';

class AdaptivePickerControl extends StatelessWidget {
  final Control control;

  const AdaptivePickerControl({super.key, required this.control});

  @override
  Widget build(BuildContext context) {
    return PlatformControlRenderer(
      material: (_) => MaterialPickerControl(control: control),
      cupertino: (_) => CupertinoPickerControl(control: control),
    );
  }
}
