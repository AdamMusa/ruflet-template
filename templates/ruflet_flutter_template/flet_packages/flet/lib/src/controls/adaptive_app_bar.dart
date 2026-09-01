import 'package:flutter/widgets.dart';

import '../models/control.dart';
import '../widgets/platform_control_renderer.dart';
import 'app_bar.dart';
import 'cupertino_app_bar.dart';

class AdaptiveAppBarControl extends StatelessWidget {
  final Control control;

  const AdaptiveAppBarControl({super.key, required this.control});

  @override
  Widget build(BuildContext context) {
    debugPrint("AdaptiveAppBarControl build: ${control.id}");

    return PlatformControlRenderer(
      material: (_) => AppBarControl(control: control),
      cupertino: (_) => CupertinoAppBarControl(control: control),
    );
  }
}
