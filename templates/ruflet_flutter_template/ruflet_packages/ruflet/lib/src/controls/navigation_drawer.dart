import 'package:flutter/widgets.dart';

import '../models/control.dart';
import '../widgets/platform_control_renderer.dart';
import 'cupertino_navigation_controls.dart';
import 'material_navigation_drawer.dart';

class NavigationDrawerControl extends StatelessWidget {
  final Control control;

  const NavigationDrawerControl({super.key, required this.control});

  @override
  Widget build(BuildContext context) => PlatformControlRenderer(
        material: (_) => MaterialNavigationDrawerControl(control: control),
        cupertino: (_) => CupertinoNavigationDrawerControl(control: control),
      );
}
