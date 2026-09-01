import 'package:flutter/widgets.dart';

import '../models/control.dart';
import '../widgets/platform_control_renderer.dart';
import 'checkbox.dart';
import 'cupertino_checkbox.dart';

class AdaptiveCheckboxControl extends StatelessWidget {
  final Control control;

  const AdaptiveCheckboxControl({super.key, required this.control});

  @override
  Widget build(BuildContext context) {
    debugPrint("AdaptiveCheckboxControl build: ${control.id}");

    return PlatformControlRenderer(
      material: (_) => CheckboxControl(control: control),
      cupertino: (_) => CupertinoCheckboxControl(control: control),
    );
  }
}
