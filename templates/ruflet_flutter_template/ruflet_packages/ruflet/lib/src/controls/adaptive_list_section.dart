import 'package:flutter/widgets.dart';

import '../models/control.dart';
import '../widgets/platform_control_renderer.dart';
import 'cupertino_list_section.dart';
import 'material_list_section.dart';

class AdaptiveListSectionControl extends StatelessWidget {
  final Control control;

  const AdaptiveListSectionControl({super.key, required this.control});

  @override
  Widget build(BuildContext context) {
    debugPrint("AdaptiveListSection build: ${control.id}");

    return PlatformControlRenderer(
      material: (_) => MaterialListSectionControl(control: control),
      cupertino: (_) => CupertinoListSectionControl(control: control),
    );
  }
}
