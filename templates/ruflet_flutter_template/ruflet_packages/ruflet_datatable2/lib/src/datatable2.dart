import 'package:ruflet/ruflet.dart';
import 'package:flutter/widgets.dart';

import 'cupertino_datatable2.dart';
import 'material_datatable2.dart';

/// The wire control is shared; each visual language owns its renderer.
class DataTable2Control extends StatelessWidget {
  final Control control;

  const DataTable2Control({super.key, required this.control});

  @override
  Widget build(BuildContext context) => PlatformControlRenderer(
        material: (_) => MaterialDataTable2Control(control: control),
        cupertino: (_) => CupertinoDataTable2Control(control: control),
      );
}
