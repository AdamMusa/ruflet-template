import 'package:flutter/widgets.dart';

import '../models/control.dart';
import '../widgets/platform_control_renderer.dart';
import 'cupertino_slider.dart';
import 'slider.dart';

class AdaptiveSliderControl extends StatelessWidget {
  final Control control;

  const AdaptiveSliderControl({super.key, required this.control});

  @override
  Widget build(BuildContext context) {
    debugPrint("AdaptiveSlider build: ${control.id}");

    return PlatformControlRenderer(
      material: (_) => SliderControl(control: control),
      cupertino: (_) => CupertinoSliderControl(control: control),
    );
  }
}
