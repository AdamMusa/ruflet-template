import 'package:flutter/widgets.dart';

import '../models/control.dart';
import '../utils/numbers.dart';
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
      // `sliding` (Ruby's cupertino_sliding_segmented_button, or the legacy
      // CupertinoSlidingSegmentedButton wire name) selects the iOS sliding
      // control. Material has no sliding equivalent: SegmentedButton.
      cupertino: (_) => control.getBool("sliding", false)!
          ? CupertinoSlidingSegmentedButtonControl(control: control)
          : CupertinoSegmentedButtonControl(control: control),
    );
  }
}
