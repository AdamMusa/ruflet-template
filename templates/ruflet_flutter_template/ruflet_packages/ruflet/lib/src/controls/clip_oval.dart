import 'package:flutter/widgets.dart';

import '../extensions/control.dart';
import '../models/control.dart';
import '../utils/misc.dart';
import '../utils/numbers.dart';
import 'base_controls.dart';

/// Clips its `content` to the oval that fills the content's box (a circle
/// for a square), like Flutter's [ClipOval]. `clip_behavior` defaults to
/// anti-aliased. Design-neutral.
class ClipOvalControl extends StatelessWidget {
  final Control control;

  const ClipOvalControl({super.key, required this.control});

  @override
  Widget build(BuildContext context) {
    debugPrint("ClipOval build: ${control.id}");

    return LayoutControl(
      control: control,
      child: ClipOval(
        clipBehavior:
            parseClip(control.getString("clip_behavior"), Clip.antiAlias)!,
        child: control.buildWidget("content"),
      ),
    );
  }
}
