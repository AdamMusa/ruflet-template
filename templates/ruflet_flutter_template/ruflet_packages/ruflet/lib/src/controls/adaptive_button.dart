import 'package:flutter/widgets.dart';

import '../models/control.dart';
import '../models/control_type.dart';
import '../widgets/platform_control_renderer.dart';
import 'button.dart';
import 'cupertino_button.dart';
import 'cupertino_dialog_action.dart';

class AdaptiveButtonControl extends StatelessWidget {
  final Control control;

  const AdaptiveButtonControl({super.key, required this.control});

  @override
  Widget build(BuildContext context) {
    debugPrint("AdaptiveButton build: ${control.id}");

    return PlatformControlRenderer(
      material: (_) => ButtonControl(control: control),
      cupertino: (_) => control.parent?.canonicalType == "AlertDialog"
          ? CupertinoDialogActionControl(control: control)
          : CupertinoButtonControl(control: control),
    );
  }
}
