import 'package:flutter/widgets.dart';

import '../models/control.dart';
import '../widgets/platform_control_renderer.dart';
import 'cupertino_surface_controls.dart';
import 'material_circle_avatar.dart';

class CircleAvatarControl extends StatelessWidget {
  final Control control;

  const CircleAvatarControl({super.key, required this.control});

  @override
  Widget build(BuildContext context) => PlatformControlRenderer(
        material: (_) => MaterialCircleAvatarControl(control: control),
        cupertino: (_) => CupertinoCircleAvatarControl(control: control),
      );
}
