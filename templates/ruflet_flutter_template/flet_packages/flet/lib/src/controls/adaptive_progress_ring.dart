import 'package:flutter/widgets.dart';

import '../models/control.dart';
import '../widgets/platform_control_renderer.dart';
import 'cupertino_activity_indicator.dart';
import 'progress_ring.dart';

class AdaptiveProgressRingControl extends StatelessWidget {
  final Control control;

  const AdaptiveProgressRingControl({super.key, required this.control});

  @override
  Widget build(BuildContext context) {
    debugPrint("AdaptiveProgressRingControl build: ${control.id}");
    return PlatformControlRenderer(
      material: (_) => ProgressRingControl(control: control),
      cupertino: (_) => CupertinoActivityIndicatorControl(control: control),
    );
  }
}
