import 'package:flutter/widgets.dart';

import '../models/control.dart';
import '../widgets/platform_control_renderer.dart';
import 'cupertino_selection_area.dart';
import 'material_selection_area.dart';

class SelectionAreaControl extends StatelessWidget {
  final Control control;

  const SelectionAreaControl({super.key, required this.control});

  @override
  Widget build(BuildContext context) => PlatformControlRenderer(
        material: (_) => MaterialSelectionAreaControl(control: control),
        cupertino: (_) => CupertinoSelectionAreaControl(control: control),
      );
}
