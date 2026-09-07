import 'package:flutter/widgets.dart';

import '../models/control.dart';
import '../widgets/platform_control_renderer.dart';
import 'cupertino_radio.dart';
import 'radio.dart';

class AdaptiveRadioControl extends StatelessWidget {
  final Control control;

  const AdaptiveRadioControl({super.key, required this.control});

  @override
  Widget build(BuildContext context) {
    debugPrint("AdaptiveRadioControl build: ${control.id}");

    return PlatformControlRenderer(
      material: (_) => RadioControl(control: control),
      cupertino: (_) => CupertinoRadioControl(control: control),
    );
  }
}
