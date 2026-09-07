import 'package:flutter/widgets.dart';

import '../controls/alert_dialog.dart';
import '../models/control.dart';
import '../widgets/platform_control_renderer.dart';
import 'cupertino_alert_dialog.dart';

class AdaptiveAlertDialogControl extends StatelessWidget {
  final Control control;

  const AdaptiveAlertDialogControl({super.key, required this.control});

  @override
  Widget build(BuildContext context) {
    debugPrint("AdaptiveAlertDialog build: ${control.id}");

    return PlatformControlRenderer(
      material: (_) => AlertDialogControl(control: control),
      cupertino: (_) => CupertinoAlertDialogControl(control: control),
    );
  }
}
