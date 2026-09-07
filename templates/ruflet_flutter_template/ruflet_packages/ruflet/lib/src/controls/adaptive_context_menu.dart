import 'package:flutter/widgets.dart';

import '../models/control.dart';
import '../widgets/platform_control_renderer.dart';
import 'context_menu.dart';
import 'cupertino_context_menu.dart';

class AdaptiveContextMenuControl extends StatelessWidget {
  final Control control;

  const AdaptiveContextMenuControl({super.key, required this.control});

  @override
  Widget build(BuildContext context) {
    debugPrint("AdaptiveContextMenuControl build: ${control.id}");
    return PlatformControlRenderer(
      material: (_) => ContextMenuControl(control: control),
      cupertino: (_) => CupertinoContextMenuControl(control: control),
    );
  }
}
