import 'package:flutter/widgets.dart';

import '../models/control.dart';
import '../widgets/platform_control_renderer.dart';
import 'cupertino_surface_controls.dart';
import 'material_vertical_divider.dart';

class VerticalDividerControl extends StatelessWidget {
  final Control control;

  const VerticalDividerControl({super.key, required this.control});

  @override
  Widget build(BuildContext context) => PlatformControlRenderer(
        material: (_) => MaterialVerticalDividerControl(control: control),
        cupertino: (_) => CupertinoVerticalDividerControl(control: control),
      );
}
