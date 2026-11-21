import 'package:flutter/widgets.dart';

import '../extensions/control.dart';
import '../models/control.dart';
import '../utils/alignment.dart';
import 'base_controls.dart';
import 'explicit_transition.dart';

/// Scales its `content` from `begin` to `end` (defaults 0 and 1) around
/// `alignment` (default the centre) with the timing [ExplicitTransition]
/// reads; `begin: 1, end: 1.15, repeat: true, reverse: true` pulses.
/// Design-neutral.
class ScaleTransitionControl extends StatelessWidget {
  final Control control;

  const ScaleTransitionControl({super.key, required this.control});

  @override
  Widget build(BuildContext context) {
    debugPrint("ScaleTransition build: ${control.id}");

    final alignment = control.getAlignment("alignment") ?? Alignment.center;
    return LayoutControl(
      control: control,
      child: ExplicitTransition<double>(
        control: control,
        begin: transitionNumber(control, "begin", 0),
        end: transitionNumber(control, "end", 1),
        builder: (context, scale, child) =>
            ScaleTransition(scale: scale, alignment: alignment, child: child),
        child: control.buildWidget("content"),
      ),
    );
  }
}
