import 'package:flutter/widgets.dart';

import '../models/control.dart';
import '../widgets/platform_control_renderer.dart';
import 'cupertino_navigation_controls.dart';
import 'material_navigation_rail.dart';

class NavigationRailControl extends StatelessWidget {
  final Control control;

  const NavigationRailControl({super.key, required this.control});

  @override
  Widget build(BuildContext context) => PlatformControlRenderer(
        material: (_) => MaterialNavigationRailControl(control: control),
        cupertino: (_) => CupertinoNavigationRailControl(control: control),
      );
}
