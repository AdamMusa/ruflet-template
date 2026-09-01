import 'package:flutter/widgets.dart';

import '../models/control.dart';
import '../widgets/platform_control_renderer.dart';
import 'cupertino_content_controls.dart';
import 'material_expansion_tile.dart';

class ExpansionTileControl extends StatelessWidget {
  final Control control;

  const ExpansionTileControl({super.key, required this.control});

  @override
  Widget build(BuildContext context) => PlatformControlRenderer(
        material: (_) => MaterialExpansionTileControl(control: control),
        cupertino: (_) => CupertinoExpansionTileControl(control: control),
      );
}
