import 'package:flutter/widgets.dart';

import '../models/control.dart';
import '../widgets/platform_control_renderer.dart';
import 'cupertino_content_controls.dart';
import 'material_expansion_panel.dart';

class ExpansionPanelListControl extends StatelessWidget {
  final Control control;

  const ExpansionPanelListControl({super.key, required this.control});

  @override
  Widget build(BuildContext context) => PlatformControlRenderer(
        material: (_) => MaterialExpansionPanelListControl(control: control),
        cupertino: (_) => CupertinoExpansionPanelListControl(control: control),
      );
}
