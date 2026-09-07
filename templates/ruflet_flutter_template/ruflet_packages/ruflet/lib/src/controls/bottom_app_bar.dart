import 'package:flutter/widgets.dart';

import '../models/control.dart';
import '../widgets/platform_control_renderer.dart';
import 'cupertino_surface_controls.dart';
import 'material_bottom_app_bar.dart';

class BottomAppBarControl extends StatelessWidget {
  final Control control;

  const BottomAppBarControl({super.key, required this.control});

  @override
  Widget build(BuildContext context) => PlatformControlRenderer(
        material: (_) => MaterialBottomAppBarControl(control: control),
        cupertino: (_) => CupertinoBottomAppBarControl(control: control),
      );
}
