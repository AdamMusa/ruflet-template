import 'package:flutter/widgets.dart';

import '../models/control.dart';
import '../widgets/platform_control_renderer.dart';
import 'cupertino_list_tile.dart';
import 'list_tile.dart';

class AdaptiveListTileControl extends StatelessWidget {
  final Control control;

  const AdaptiveListTileControl({super.key, required this.control});

  @override
  Widget build(BuildContext context) {
    debugPrint("AdaptiveListTileControl build: ${control.id}");
    return PlatformControlRenderer(
      material: (_) => ListTileControl(control: control),
      cupertino: (_) => CupertinoListTileControl(control: control),
    );
  }
}
