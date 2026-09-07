import 'package:flutter/widgets.dart';

import '../models/control.dart';
import '../widgets/platform_control_renderer.dart';
import 'cupertino_snack_bar.dart';
import 'material_snack_bar.dart';

class SnackBarControl extends StatelessWidget {
  final Control control;

  const SnackBarControl({super.key, required this.control});

  @override
  Widget build(BuildContext context) {
    return PlatformControlRenderer(
      material: (_) => MaterialSnackBarControl(control: control),
      cupertino: (_) => CupertinoSnackBarControl(control: control),
    );
  }
}
