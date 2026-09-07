import 'package:flutter/widgets.dart';

import '../models/control.dart';
import '../widgets/platform_control_renderer.dart';
import 'cupertino_input_controls.dart';
import 'material_auto_complete.dart';

class AutoCompleteControl extends StatelessWidget {
  final Control control;

  const AutoCompleteControl({super.key, required this.control});

  @override
  Widget build(BuildContext context) => PlatformControlRenderer(
        material: (_) => MaterialAutoCompleteControl(control: control),
        cupertino: (_) => CupertinoAutoCompleteControl(control: control),
      );
}
