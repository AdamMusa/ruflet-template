import 'package:flutter/widgets.dart';

import '../models/control.dart';
import '../widgets/platform_control_renderer.dart';
import 'cupertino_navigation_bar.dart';
import 'material_navigation_bar.dart';

class NavigationBarControl extends StatelessWidget {
  final Control control;

  const NavigationBarControl({super.key, required this.control});

  @override
  Widget build(BuildContext context) => PlatformControlRenderer(
        material: (_) => MaterialNavigationBarControl(control: control),
        cupertino: (_) => CupertinoNavigationBarControl(control: control),
      );
}
