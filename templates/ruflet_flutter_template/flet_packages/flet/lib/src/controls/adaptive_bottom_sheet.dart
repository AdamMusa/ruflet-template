import 'package:flutter/widgets.dart';

import '../models/control.dart';
import '../widgets/platform_control_renderer.dart';
import 'bottom_sheet.dart';
import 'cupertino_bottom_sheet.dart';

class AdaptiveBottomSheetControl extends StatelessWidget {
  final Control control;

  const AdaptiveBottomSheetControl({super.key, required this.control});

  @override
  Widget build(BuildContext context) {
    debugPrint("AdaptiveBottomSheetControl build: ${control.id}");
    return PlatformControlRenderer(
      material: (_) => BottomSheetControl(control: control),
      cupertino: (_) => CupertinoBottomSheetControl(control: control),
    );
  }
}
