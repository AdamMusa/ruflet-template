import 'package:flutter/widgets.dart';

import '../models/control.dart';
import '../widgets/platform_control_renderer.dart';
import 'cupertino_form_row.dart';
import 'material_form_row.dart';

class AdaptiveFormRowControl extends StatelessWidget {
  final Control control;

  const AdaptiveFormRowControl({super.key, required this.control});

  @override
  Widget build(BuildContext context) {
    debugPrint("AdaptiveFormRow build: ${control.id}");

    return PlatformControlRenderer(
      material: (_) => MaterialFormRowControl(control: control),
      cupertino: (_) => CupertinoFormRowControl(control: control),
    );
  }
}
