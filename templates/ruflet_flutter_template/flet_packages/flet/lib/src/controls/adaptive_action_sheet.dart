import 'package:flutter/widgets.dart';

import '../models/control.dart';
import '../widgets/platform_control_renderer.dart';
import 'cupertino_action_sheet.dart';
import 'cupertino_action_sheet_action.dart';
import 'material_picker_controls.dart';

class AdaptiveActionSheetControl extends StatelessWidget {
  final Control control;

  const AdaptiveActionSheetControl({super.key, required this.control});

  @override
  Widget build(BuildContext context) {
    return PlatformControlRenderer(
      material: (_) => MaterialActionSheetControl(control: control),
      cupertino: (_) => CupertinoActionSheetControl(control: control),
    );
  }
}

class AdaptiveActionSheetActionControl extends StatelessWidget {
  final Control control;

  const AdaptiveActionSheetActionControl({super.key, required this.control});

  @override
  Widget build(BuildContext context) {
    return PlatformControlRenderer(
      material: (_) => MaterialActionSheetActionControl(control: control),
      cupertino: (_) => CupertinoActionSheetActionControl(control: control),
    );
  }
}
