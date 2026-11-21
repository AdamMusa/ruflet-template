import 'package:flutter/widgets.dart';

import '../core/control_core.dart';
import '../models/control.dart';
import '../widgets/platform_control_renderer.dart';
import 'cupertino_activity_indicator.dart';
import 'progress_ring.dart';
import 'progress_ring_core.dart';

class AdaptiveProgressRingControl extends StatelessWidget {
  final Control control;

  const AdaptiveProgressRingControl({super.key, required this.control});

  @override
  Widget build(BuildContext context) {
    debugPrint("AdaptiveProgressRingControl build: ${control.id}");

    return CoreHost<ProgressRingCore>(
      key: ValueKey("control_${control.id}"),
      control: control,
      create: ProgressRingCore.new,
      builder: (context, core) => PlatformControlRenderer(
        material: (_) => MaterialProgressRingSkin(core: core),
        cupertino: (_) => CupertinoProgressRingSkin(core: core),
      ),
    );
  }
}
