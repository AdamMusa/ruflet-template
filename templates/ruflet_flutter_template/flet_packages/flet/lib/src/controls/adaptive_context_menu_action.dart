import 'package:flutter/widgets.dart';

import '../models/control.dart';
import '../widgets/platform_control_renderer.dart';
import 'cupertino_context_menu_action.dart';
import 'material_picker_controls.dart';

class AdaptiveContextMenuActionControl extends StatelessWidget {
  final Control control;

  const AdaptiveContextMenuActionControl({super.key, required this.control});

  @override
  Widget build(BuildContext context) {
    return PlatformControlRenderer(
      material: (_) => MaterialContextMenuActionControl(control: control),
      cupertino: (_) => CupertinoContextMenuActionControl(control: control),
    );
  }
}
