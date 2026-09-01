import 'package:flutter/widgets.dart';

import '../models/control.dart';
import '../widgets/platform_control_renderer.dart';
import 'cupertino_navigation_controls.dart';
import 'material_menu_item_button.dart';

class MenuItemButtonControl extends StatelessWidget {
  final Control control;

  const MenuItemButtonControl({super.key, required this.control});

  @override
  Widget build(BuildContext context) => PlatformControlRenderer(
        material: (_) => MaterialMenuItemButtonControl(control: control),
        cupertino: (_) => CupertinoMenuItemButtonControl(control: control),
      );
}
