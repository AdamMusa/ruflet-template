import 'package:flutter/widgets.dart';

import '../models/control.dart';
import '../widgets/platform_control_renderer.dart';
import 'cupertino_navigation_controls.dart';
import 'material_submenu_button.dart';

class SubmenuButtonControl extends StatelessWidget {
  final Control control;

  const SubmenuButtonControl({super.key, required this.control});

  @override
  Widget build(BuildContext context) => PlatformControlRenderer(
        material: (_) => MaterialSubmenuButtonControl(control: control),
        cupertino: (_) => CupertinoSubmenuButtonControl(control: control),
      );
}
