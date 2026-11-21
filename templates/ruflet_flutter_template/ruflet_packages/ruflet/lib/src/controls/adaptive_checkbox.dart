import 'package:flutter/widgets.dart';

import '../core/control_core.dart';
import '../models/control.dart';
import '../widgets/platform_control_renderer.dart';
import 'checkbox.dart';
import 'checkbox_core.dart';
import 'cupertino_checkbox.dart';

class AdaptiveCheckboxControl extends StatelessWidget {
  final Control control;

  const AdaptiveCheckboxControl({super.key, required this.control});

  @override
  Widget build(BuildContext context) {
    debugPrint("AdaptiveCheckboxControl build: ${control.id}");

    return CoreHost<CheckboxCore>(
      // The key the legacy skins used, so state survives parent rebuilds.
      key: ValueKey("control_${control.id}"),
      control: control,
      create: CheckboxCore.new,
      builder: (context, core) => PlatformControlRenderer(
        material: (_) => MaterialCheckboxSkin(core: core),
        cupertino: (_) => CupertinoCheckboxSkin(core: core),
      ),
    );
  }
}
