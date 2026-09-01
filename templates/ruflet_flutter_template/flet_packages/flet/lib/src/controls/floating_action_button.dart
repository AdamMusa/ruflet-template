import 'package:flutter/widgets.dart';

import '../models/control.dart';
import '../widgets/platform_control_renderer.dart';
import 'cupertino_surface_controls.dart';
import 'material_floating_action_button.dart';

class FloatingActionButtonControl extends StatelessWidget {
  final Control control;

  const FloatingActionButtonControl({super.key, required this.control});

  @override
  Widget build(BuildContext context) => PlatformControlRenderer(
        material: (_) => MaterialFloatingActionButtonControl(control: control),
        cupertino: (_) =>
            CupertinoFloatingActionButtonControl(control: control),
      );
}
