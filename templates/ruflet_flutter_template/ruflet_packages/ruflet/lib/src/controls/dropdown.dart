import 'package:flutter/widgets.dart';

import '../models/control.dart';
import '../widgets/platform_control_renderer.dart';
import 'cupertino_input_controls.dart';
import 'material_dropdown.dart';
import 'material_dropdown_m2.dart';

class DropdownControl extends StatelessWidget {
  final Control control;

  const DropdownControl({super.key, required this.control});

  @override
  Widget build(BuildContext context) => PlatformControlRenderer(
        material: (_) => control.type == "DropdownM2"
            ? MaterialDropdownM2Control(control: control)
            : MaterialDropdownControl(control: control),
        cupertino: (_) => CupertinoDropdownControl(control: control),
      );
}
