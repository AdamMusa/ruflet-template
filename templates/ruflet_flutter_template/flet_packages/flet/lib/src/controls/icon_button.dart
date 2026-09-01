import 'package:flutter/widgets.dart';

import '../models/control.dart';
import '../widgets/platform_control_renderer.dart';
import 'cupertino_button.dart';
import 'material_icon_button.dart';

class IconButtonControl extends StatelessWidget {
  final Control control;

  const IconButtonControl({super.key, required this.control});

  @override
  Widget build(BuildContext context) => PlatformControlRenderer(
        material: (_) => MaterialIconButtonControl(control: control),
        cupertino: (_) => CupertinoButtonControl(control: control),
      );
}
