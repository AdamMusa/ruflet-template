import 'package:flutter/widgets.dart';

import '../extensions/control.dart';
import '../models/control.dart';
import '../utils/alignment.dart';
import '../utils/images.dart';
import '../utils/misc.dart';
import '../utils/numbers.dart';
import 'base_controls.dart';

/// Scales and positions its `content` inside the box Ruby gives it (`width`,
/// `height`, `expand`, ...) according to `fit`. Design-neutral.
class FittedBoxControl extends StatelessWidget {
  final Control control;

  const FittedBoxControl({super.key, required this.control});

  @override
  Widget build(BuildContext context) {
    debugPrint("FittedBox build: ${control.id}");

    return LayoutControl(
      control: control,
      child: FittedBox(
        fit: parseBoxFit(
            control.getString("fit")?.replaceAll("_", ""), BoxFit.contain)!,
        alignment: control.getAlignment("alignment") ?? Alignment.center,
        clipBehavior: parseClip(
            control.getString("clip_behavior")?.replaceAll("_", ""),
            Clip.none)!,
        child: control.buildWidget("content"),
      ),
    );
  }
}
