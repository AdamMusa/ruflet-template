import 'package:flutter/widgets.dart';

import '../models/control.dart';
import '../widgets/platform_control_renderer.dart';
import 'cupertino_navigation_controls.dart';
import 'material_navigation_bar_destination.dart';

class NavigationBarDestinationControl extends StatelessWidget {
  final Control control;

  const NavigationBarDestinationControl({super.key, required this.control});

  @override
  Widget build(BuildContext context) => PlatformControlRenderer(
        material: (_) =>
            MaterialNavigationBarDestinationControl(control: control),
        cupertino: (_) =>
            CupertinoNavigationBarDestinationControl(control: control),
      );
}
