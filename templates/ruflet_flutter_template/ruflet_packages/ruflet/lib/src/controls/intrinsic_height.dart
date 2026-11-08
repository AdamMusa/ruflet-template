import 'package:flutter/widgets.dart';

import '../extensions/control.dart';
import '../models/control.dart';
import 'base_controls.dart';

/// Sizes its `content` to the content's intrinsic height, like Flutter's
/// [IntrinsicHeight]: a Row inside it can stretch every child to the tallest
/// one. Design-neutral.
class IntrinsicHeightControl extends StatelessWidget {
  final Control control;

  const IntrinsicHeightControl({super.key, required this.control});

  @override
  Widget build(BuildContext context) {
    debugPrint("IntrinsicHeight build: ${control.id}");

    return LayoutControl(
      control: control,
      child: IntrinsicHeight(child: control.buildWidget("content")),
    );
  }
}
