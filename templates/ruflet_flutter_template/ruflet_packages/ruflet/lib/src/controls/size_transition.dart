import 'package:flutter/widgets.dart';

import '../extensions/control.dart';
import '../models/control.dart';
import '../utils/misc.dart';
import '../utils/numbers.dart';
import 'base_controls.dart';
import 'explicit_transition.dart';

/// Grows its `content` along `axis` (default vertical) from size factor
/// `begin` to `end` (defaults 0 and 1), clipping what does not fit yet,
/// from `axis_alignment` (-1..1, default 0) with the timing
/// [ExplicitTransition] reads. Design-neutral.
class SizeTransitionControl extends StatelessWidget {
  final Control control;

  const SizeTransitionControl({super.key, required this.control});

  @override
  Widget build(BuildContext context) {
    debugPrint("SizeTransition build: ${control.id}");

    final axis = parseAxis(control.getString("axis"), Axis.vertical)!;
    final axisAlignment = transitionNumber(control, "axis_alignment", 0);
    return LayoutControl(
      control: control,
      child: ExplicitTransition<double>(
        control: control,
        begin: _factor(transitionNumber(control, "begin", 0)),
        end: _factor(transitionNumber(control, "end", 1)),
        builder: (context, sizeFactor, child) => SizeTransition(
            sizeFactor: sizeFactor,
            axis: axis,
            axisAlignment: axisAlignment,
            child: child),
        child: control.buildWidget("content"),
      ),
    );
  }
}

/// Flutter asserts on a negative size factor.
double _factor(double value) => value < 0 ? 0 : value;
