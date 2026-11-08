import 'package:flutter/widgets.dart';

import '../core/control_core.dart';
import '../models/control.dart';
import '../models/control_type.dart';
import '../widgets/platform_control_renderer.dart';
import 'button.dart';
import 'button_core.dart';
import 'cupertino_button_skin.dart';
import 'cupertino_dialog_action.dart';

/// Registry entry of the Button, FilledButton, FilledTonalButton,
/// OutlinedButton and TextButton wire types.
class AdaptiveButtonControl extends StatelessWidget {
  final Control control;

  const AdaptiveButtonControl({super.key, required this.control});

  @override
  Widget build(BuildContext context) {
    debugPrint("AdaptiveButton build: ${control.id}");

    return CoreHost<ButtonCore>(
      // The legacy key plus the wire type: a core serves one wire type.
      key: ValueKey("control_${control.canonicalType}_${control.id}"),
      control: control,
      create: ButtonCore.new,
      builder: (context, core) => PlatformControlRenderer(
        material: (_) => MaterialButtonSkin(core: core),
        cupertino: (_) => core.inAlertDialog
            ? CupertinoDialogActionSkin(core: core)
            : CupertinoButtonSkin(core: core),
      ),
    );
  }
}
