import 'package:flutter/widgets.dart';

import '../models/control.dart';
import '../widgets/platform_control_renderer.dart';
import 'cupertino_surface_controls.dart';
import 'material_divider.dart';

class DividerControl extends StatelessWidget {
  final Control control;

  const DividerControl({super.key, required this.control});

  @override
  Widget build(BuildContext context) => PlatformControlRenderer(
        material: (_) => MaterialDividerControl(control: control),
        cupertino: (_) => CupertinoDividerControl(control: control),
      );
}
