import 'package:flutter/widgets.dart';

import '../models/control.dart';
import '../widgets/platform_control_renderer.dart';
import 'cupertino_navigation_controls.dart';
import 'material_menu_bar.dart';

class MenuBarControl extends StatelessWidget {
  final Control control;

  const MenuBarControl({super.key, required this.control});

  @override
  Widget build(BuildContext context) => PlatformControlRenderer(
        material: (_) => MaterialMenuBarControl(control: control),
        cupertino: (_) => CupertinoMenuBarControl(control: control),
      );
}
