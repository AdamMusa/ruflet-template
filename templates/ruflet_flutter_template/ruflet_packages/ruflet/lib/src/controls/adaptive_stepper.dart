import 'package:flutter/widgets.dart';

import '../models/control.dart';
import '../widgets/error.dart';
import '../widgets/platform_control_renderer.dart';
import 'base_controls.dart';
import 'cupertino_stepper.dart';
import 'material_stepper.dart';
import 'stepper_steps.dart';

class AdaptiveStepperControl extends StatelessWidget {
  final Control control;

  const AdaptiveStepperControl({super.key, required this.control});

  @override
  Widget build(BuildContext context) {
    debugPrint("AdaptiveStepper build: ${control.id}");

    final model = StepperModel(control);
    Widget child = model.error ??
        PlatformControlRenderer(
          material: (_) =>
              MaterialStepperControl(control: control, model: model),
          cupertino: (_) =>
              CupertinoStepperControl(control: control, model: model),
        );
    if (model.error == null && model.horizontal) {
      // Both renderers give the step content an Expanded body below the
      // header row, which needs a finite height.
      final stepper = child;
      child = LayoutBuilder(
        builder: (context, constraints) => constraints.hasBoundedHeight
            ? stepper
            : const ErrorControl(
                "Stepper(type: horizontal) needs a bounded height",
                description: "Set height or expand"),
      );
    }
    return LayoutControl(control: control, child: child);
  }
}
