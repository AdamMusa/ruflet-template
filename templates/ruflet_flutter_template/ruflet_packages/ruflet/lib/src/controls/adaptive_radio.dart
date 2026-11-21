import 'package:flutter/widgets.dart';

import '../core/control_core.dart';
import '../models/control.dart';
import '../widgets/platform_control_renderer.dart';
import 'cupertino_radio.dart';
import 'radio.dart';
import 'radio_core.dart';

class AdaptiveRadioControl extends StatelessWidget {
  final Control control;

  const AdaptiveRadioControl({super.key, required this.control});

  @override
  Widget build(BuildContext context) {
    debugPrint("AdaptiveRadioControl build: ${control.id}");

    return CoreHost<RadioCore>(
      // The key the legacy skins used, so state survives parent rebuilds.
      key: ValueKey("control_${control.id}"),
      control: control,
      create: RadioCore.new,
      builder: (context, core) => PlatformControlRenderer(
        material: (_) => MaterialRadioSkin(core: core),
        cupertino: (_) => CupertinoRadioSkin(core: core),
      ),
    );
  }
}
