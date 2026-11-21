import 'package:flutter/widgets.dart';

import '../core/control_core.dart';
import '../models/control.dart';
import '../widgets/platform_control_renderer.dart';
import 'cupertino_switch.dart';
import 'switch.dart';
import 'switch_core.dart';

class AdaptiveSwitchControl extends StatelessWidget {
  final Control control;

  const AdaptiveSwitchControl({super.key, required this.control});

  @override
  Widget build(BuildContext context) {
    debugPrint("AdaptiveSwitch build: ${control.id}");

    return CoreHost<SwitchCore>(
      // The key the legacy skins used, so state survives parent rebuilds.
      key: ValueKey("control_${control.id}"),
      control: control,
      create: SwitchCore.new,
      builder: (context, core) => PlatformControlRenderer(
        material: (_) => MaterialSwitchSkin(core: core),
        cupertino: (_) => CupertinoSwitchSkin(core: core),
      ),
    );
  }
}
