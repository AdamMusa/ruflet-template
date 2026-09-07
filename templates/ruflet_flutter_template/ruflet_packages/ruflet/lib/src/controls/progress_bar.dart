import 'package:flutter/widgets.dart';

import '../models/control.dart';
import '../widgets/platform_control_renderer.dart';
import 'cupertino_surface_controls.dart';
import 'material_progress_bar.dart';

class ProgressBarControl extends StatelessWidget {
  final Control control;

  const ProgressBarControl({super.key, required this.control});

  @override
  Widget build(BuildContext context) => PlatformControlRenderer(
        material: (_) => MaterialProgressBarControl(control: control),
        cupertino: (_) => CupertinoProgressBarControl(control: control),
      );
}
