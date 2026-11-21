import 'package:flutter/widgets.dart';

import '../extensions/control.dart';
import '../models/control.dart';
import '../utils/transforms.dart';
import 'base_controls.dart';
import 'explicit_transition.dart';

/// Moves its `content` from offset `begin` to `end` ({x, y} in fractions of
/// the content's size; defaults {0, 1} and {0, 0}: it slides up into place)
/// with the timing [ExplicitTransition] reads. Design-neutral.
class SlideTransitionControl extends StatelessWidget {
  final Control control;

  const SlideTransitionControl({super.key, required this.control});

  @override
  Widget build(BuildContext context) {
    debugPrint("SlideTransition build: ${control.id}");

    return LayoutControl(
      control: control,
      child: ExplicitTransition<Offset>(
        control: control,
        begin: _offset(control.get("begin"), const Offset(0, 1)),
        end: _offset(control.get("end"), Offset.zero),
        builder: (context, position, child) =>
            SlideTransition(position: position, child: child),
        child: control.buildWidget("content"),
      ),
    );
  }
}

/// An {x, y} map (or [x, y] list) from Ruby, else [defaultValue].
Offset _offset(dynamic value, Offset defaultValue) {
  if (value is! Map && value is! List) return defaultValue;
  final offset = parseOffset(value, defaultValue)!;
  return offset.isFinite ? offset : defaultValue;
}
