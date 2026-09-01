import 'package:flutter/widgets.dart';

import '../models/control.dart';
import '../widgets/platform_control_renderer.dart';
import 'cupertino_navigation_controls.dart';
import 'material_popup_menu_button.dart';

class PopupMenuButtonControl extends StatelessWidget {
  final Control control;

  const PopupMenuButtonControl({super.key, required this.control});

  @override
  Widget build(BuildContext context) => PlatformControlRenderer(
        material: (_) => MaterialPopupMenuButtonControl(control: control),
        cupertino: (_) => CupertinoPopupMenuButtonControl(control: control),
      );
}
