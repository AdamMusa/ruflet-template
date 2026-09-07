import 'package:flutter/widgets.dart';

import '../models/control.dart';
import '../widgets/platform_control_renderer.dart';
import 'cupertino_surface_controls.dart';
import 'material_card.dart';

class CardControl extends StatelessWidget {
  final Control control;

  const CardControl({super.key, required this.control});

  @override
  Widget build(BuildContext context) => PlatformControlRenderer(
        material: (_) => MaterialCardControl(control: control),
        cupertino: (_) => CupertinoCardControl(control: control),
      );
}
