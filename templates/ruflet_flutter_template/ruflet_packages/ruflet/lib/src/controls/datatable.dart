import 'package:flutter/widgets.dart';

import '../models/control.dart';
import '../widgets/platform_control_renderer.dart';
import 'cupertino_content_controls.dart';
import 'material_datatable.dart';

class DataTableControl extends StatelessWidget {
  final Control control;

  const DataTableControl({super.key, required this.control});

  @override
  Widget build(BuildContext context) => PlatformControlRenderer(
        material: (_) => MaterialDataTableControl(control: control),
        cupertino: (_) => CupertinoDataTableControl(control: control),
      );
}
