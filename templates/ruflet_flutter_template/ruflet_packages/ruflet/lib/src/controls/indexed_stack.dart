import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../models/control.dart';
import '../utils/alignment.dart';
import '../utils/misc.dart';
import '../utils/numbers.dart';
import 'base_controls.dart';
import 'control_widget.dart';

/// Shows exactly one child (`index`) while keeping every child mounted, so
/// state such as typed text or scroll offset survives switching between them.
class IndexedStackControl extends StatelessWidget {
  final Control control;

  const IndexedStackControl({super.key, required this.control});

  @override
  Widget build(BuildContext context) {
    debugPrint("IndexedStack build: ${control.id}");

    // A hidden child keeps its slot (as an empty box) so `index` always
    // addresses the same Ruby child; hiding one must not shift the others.
    final children = control
        .children("controls", visibleOnly: false)
        .map<Widget>((child) => child.visible
            ? ControlWidget(key: ValueKey(child.id), control: child)
            : SizedBox.shrink(key: ValueKey(child.id)))
        .toList();
    // Flutter asserts on an out-of-range index; clamp it instead.
    final index = math.max(
        0, math.min(control.getInt("index", 0)!, children.length - 1));

    return LayoutControl(
      control: control,
      child: IndexedStack(
        index: index,
        alignment:
            control.getAlignment("alignment") ?? AlignmentDirectional.topStart,
        sizing: parseStackFit(
            control.getString("fit")?.replaceAll("_", ""), StackFit.loose)!,
        clipBehavior: parseClip(
            control.getString("clip_behavior")?.replaceAll("_", ""),
            Clip.hardEdge)!,
        children: children,
      ),
    );
  }
}
