import 'package:flutter/widgets.dart';

import '../extensions/control.dart';
import '../models/control.dart';
import '../utils/alignment.dart';
import '../utils/numbers.dart';
import '../widgets/error.dart';
import 'base_controls.dart';

/// Sizes its `content` to a fraction of the space its parent offers
/// (`width_factor`, `height_factor`), like Flutter's [FractionallySizedBox].
/// A missing (or negative) factor leaves that axis to the content.
/// Design-neutral.
class FractionallySizedBoxControl extends StatelessWidget {
  final Control control;

  const FractionallySizedBoxControl({super.key, required this.control});

  @override
  Widget build(BuildContext context) {
    debugPrint("FractionallySizedBox build: ${control.id}");

    final widthFactor = _factor(control.getDouble("width_factor"));
    final heightFactor = _factor(control.getDouble("height_factor"));

    final box = LayoutBuilder(builder: (context, constraints) {
      // A fraction of an unbounded axis is infinite: say where to fix it
      // instead of failing deep in layout.
      final unbounded = [
        if (widthFactor != null && !constraints.hasBoundedWidth) "width",
        if (heightFactor != null && !constraints.hasBoundedHeight) "height",
      ];
      if (unbounded.isNotEmpty) {
        return ErrorControl(
            "Error displaying FractionallySizedBox: "
            "${unbounded.join(" and ")} is unbounded.",
            description: "A factor needs a parent that bounds that axis: "
                "set the size, use expand, or place it in a bounded control "
                "(not directly in a Row, Column or scrolling list).");
      }
      return FractionallySizedBox(
        widthFactor: widthFactor,
        heightFactor: heightFactor,
        alignment: control.getAlignment("alignment") ?? Alignment.center,
        child: control.buildWidget("content"),
      );
    });

    return LayoutControl(control: control, child: box);
  }
}

double? _factor(double? value) => value == null || value < 0 ? null : value;
