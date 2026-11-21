import 'package:flutter/widgets.dart';

import '../extensions/control.dart';
import '../models/control.dart';
import '../utils/borders.dart';
import '../utils/misc.dart';
import '../utils/numbers.dart';
import 'base_controls.dart';

/// Clips its `content` to a rounded rectangle with continuous ("squircle")
/// corners of `border_radius`, the iOS app-icon shape, like Flutter's
/// [ClipRSuperellipse]. A Container's border radius rounds with circular
/// arcs. `clip_behavior` defaults to anti-aliased. Design-neutral.
class ClipRSuperellipseControl extends StatelessWidget {
  final Control control;

  const ClipRSuperellipseControl({super.key, required this.control});

  @override
  Widget build(BuildContext context) {
    debugPrint("ClipRSuperellipse build: ${control.id}");

    return LayoutControl(
      control: control,
      child: ClipRSuperellipse(
        borderRadius:
            control.getBorderRadius("border_radius", BorderRadius.zero)!,
        clipBehavior:
            parseClip(control.getString("clip_behavior"), Clip.antiAlias)!,
        child: control.buildWidget("content"),
      ),
    );
  }
}
