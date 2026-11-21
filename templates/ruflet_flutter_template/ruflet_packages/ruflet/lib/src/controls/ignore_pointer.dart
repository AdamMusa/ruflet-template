import 'package:flutter/widgets.dart';

import '../extensions/control.dart';
import '../models/control.dart';
import '../utils/numbers.dart';
import 'base_controls.dart';

/// While `ignoring` (Ruby's default: true) its `content` is invisible to
/// pointer events, like Flutter's [IgnorePointer]: taps reach whatever lies
/// behind it. Design-neutral.
class IgnorePointerControl extends StatelessWidget {
  final Control control;

  const IgnorePointerControl({super.key, required this.control});

  @override
  Widget build(BuildContext context) {
    debugPrint("IgnorePointer build: ${control.id}");

    return LayoutControl(
      control: control,
      child: IgnorePointer(
        ignoring: control.getBool("ignoring", true)!,
        child: control.buildWidget("content"),
      ),
    );
  }
}
