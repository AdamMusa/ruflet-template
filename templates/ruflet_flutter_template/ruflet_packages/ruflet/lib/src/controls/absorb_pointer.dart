import 'package:flutter/widgets.dart';

import '../extensions/control.dart';
import '../models/control.dart';
import '../utils/numbers.dart';
import 'base_controls.dart';

/// While `absorbing` (Ruby's default: true) pointer events aimed at its
/// `content` stop here, like Flutter's [AbsorbPointer]: neither the content
/// nor anything behind it receives them. Design-neutral.
class AbsorbPointerControl extends StatelessWidget {
  final Control control;

  const AbsorbPointerControl({super.key, required this.control});

  @override
  Widget build(BuildContext context) {
    debugPrint("AbsorbPointer build: ${control.id}");

    return LayoutControl(
      control: control,
      child: AbsorbPointer(
        absorbing: control.getBool("absorbing", true)!,
        child: control.buildWidget("content"),
      ),
    );
  }
}
