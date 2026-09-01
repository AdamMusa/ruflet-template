import 'package:flutter/widgets.dart';

import '../models/control.dart';
import '../widgets/platform_control_renderer.dart';
import 'cupertino_segmented_button.dart';
import 'cupertino_sliding_segmented_button.dart';
import 'segmented_button.dart';

class AdaptiveSegmentedButtonControl extends StatelessWidget {
  final Control control;

  const AdaptiveSegmentedButtonControl({super.key, required this.control});

  @override
  Widget build(BuildContext context) {
    debugPrint("AdaptiveSegmentedButtonControl build: ${control.id}");
    return PlatformControlRenderer(
      material: (_) => SegmentedButtonControl(control: control),
      cupertino: (_) => control.type == "CupertinoSlidingSegmentedButton"
          ? CupertinoSlidingSegmentedButtonControl(control: control)
          : CupertinoSegmentedButtonControl(control: control),
    );
  }
}
