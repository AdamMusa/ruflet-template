import 'package:flutter/widgets.dart';

import '../models/control.dart';
import '../widgets/platform_control_renderer.dart';
import 'cupertino_switch.dart';
import 'switch.dart';

class AdaptiveSwitchControl extends StatelessWidget {
  final Control control;

  const AdaptiveSwitchControl({super.key, required this.control});

  @override
  Widget build(BuildContext context) {
    debugPrint("AdaptiveSwitch build: ${control.id}");

    return PlatformControlRenderer(
      material: (_) => SwitchControl(control: control),
      cupertino: (_) => CupertinoSwitchControl(control: control),
    );
  }
}
