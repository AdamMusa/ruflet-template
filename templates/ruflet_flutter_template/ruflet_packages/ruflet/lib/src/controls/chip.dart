import 'package:flutter/widgets.dart';

import '../models/control.dart';
import '../widgets/platform_control_renderer.dart';
import 'cupertino_content_controls.dart';
import 'material_chip.dart';

class ChipControl extends StatelessWidget {
  final Control control;

  const ChipControl({super.key, required this.control});

  @override
  Widget build(BuildContext context) => PlatformControlRenderer(
        material: (_) => MaterialChipControl(control: control),
        cupertino: (_) => CupertinoChipControl(control: control),
      );
}
