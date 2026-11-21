import 'package:flutter/widgets.dart';

import '../extensions/control.dart';
import '../models/control.dart';
import 'base_controls.dart';
import 'explicit_transition.dart';

/// Fades its `content` from opacity `begin` (default 0) to `end` (default 1)
/// with the timing [ExplicitTransition] reads (`duration`, `curve`,
/// `repeat`, `reverse`, `animating`, `delay`). Design-neutral.
class FadeTransitionControl extends StatelessWidget {
  final Control control;

  const FadeTransitionControl({super.key, required this.control});

  @override
  Widget build(BuildContext context) {
    debugPrint("FadeTransition build: ${control.id}");

    return LayoutControl(
      control: control,
      child: ExplicitTransition<double>(
        control: control,
        begin: _opacity(transitionNumber(control, "begin", 0)),
        end: _opacity(transitionNumber(control, "end", 1)),
        builder: (context, opacity, child) =>
            FadeTransition(opacity: opacity, child: child),
        child: control.buildWidget("content"),
      ),
    );
  }
}

double _opacity(double value) => value.clamp(0.0, 1.0);
