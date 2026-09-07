import 'package:flutter/widgets.dart';

import '../models/control.dart';
import '../widgets/platform_control_renderer.dart';
import 'cupertino_textfield.dart';
import 'textfield.dart';

class AdaptiveTextFieldControl extends StatelessWidget {
  final Control control;

  const AdaptiveTextFieldControl({super.key, required this.control});

  @override
  Widget build(BuildContext context) {
    debugPrint("AdaptiveTextFieldControl build: ${control.id}");

    return PlatformControlRenderer(
      material: (_) => TextFieldControl(control: control),
      cupertino: (_) => CupertinoTextFieldControl(control: control),
    );
  }
}
