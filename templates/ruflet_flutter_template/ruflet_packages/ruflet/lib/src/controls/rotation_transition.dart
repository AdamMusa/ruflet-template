import 'package:flutter/widgets.dart';

import '../extensions/control.dart';
import '../models/control.dart';
import '../utils/alignment.dart';
import 'base_controls.dart';
import 'explicit_transition.dart';

/// Turns its `content` from `begin` to `end` turns (defaults 0 and 1)
/// around `alignment` (default the centre) with the timing
/// [ExplicitTransition] reads; `repeat: true` spins it. Design-neutral.
class RotationTransitionControl extends StatelessWidget {
  final Control control;

  const RotationTransitionControl({super.key, required this.control});

  @override
  Widget build(BuildContext context) {
    debugPrint("RotationTransition build: ${control.id}");

    final alignment = control.getAlignment("alignment") ?? Alignment.center;
    return LayoutControl(
      control: control,
      child: ExplicitTransition<double>(
        control: control,
        begin: transitionNumber(control, "begin", 0),
        end: transitionNumber(control, "end", 1),
        builder: (context, turns, child) => RotationTransition(
            turns: turns, alignment: alignment, child: child),
        child: control.buildWidget("content"),
      ),
    );
  }
}
