import 'package:flutter/widgets.dart';

import '../extensions/control.dart';
import '../models/control.dart';
import '../utils/numbers.dart';
import 'base_controls.dart';

/// Sizes its `content` to the content's intrinsic width, like Flutter's
/// [IntrinsicWidth]: a Column inside it can stretch every child to the widest
/// one. `step_width`/`step_height` round the size up to a multiple (a
/// negative step is ignored). Design-neutral.
class IntrinsicWidthControl extends StatelessWidget {
  final Control control;

  const IntrinsicWidthControl({super.key, required this.control});

  @override
  Widget build(BuildContext context) {
    debugPrint("IntrinsicWidth build: ${control.id}");

    return LayoutControl(
      control: control,
      child: IntrinsicWidth(
        stepWidth: _step(control.getDouble("step_width")),
        stepHeight: _step(control.getDouble("step_height")),
        child: control.buildWidget("content"),
      ),
    );
  }
}

double? _step(double? value) => value == null || value < 0 ? null : value;
