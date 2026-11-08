import 'package:flutter/widgets.dart';

import '../models/control.dart';
import '../widgets/platform_control_renderer.dart';
import 'cupertino_about_dialog.dart';
import 'material_about_dialog.dart';

class AdaptiveAboutDialogControl extends StatelessWidget {
  final Control control;

  const AdaptiveAboutDialogControl({super.key, required this.control});

  @override
  Widget build(BuildContext context) {
    debugPrint("AdaptiveAboutDialog build: ${control.id}");

    return PlatformControlRenderer(
      material: (_) => MaterialAboutDialogControl(control: control),
      cupertino: (_) => CupertinoAboutDialogControl(control: control),
    );
  }
}
