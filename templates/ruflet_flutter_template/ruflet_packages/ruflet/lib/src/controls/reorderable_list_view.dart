import 'package:flutter/widgets.dart';

import '../models/control.dart';
import '../widgets/platform_control_renderer.dart';
import 'cupertino_reorderable_list_view.dart';
import 'material_reorderable_list_view.dart';

class ReorderableListViewControl extends StatelessWidget {
  final Control control;

  const ReorderableListViewControl({super.key, required this.control});

  @override
  Widget build(BuildContext context) => PlatformControlRenderer(
        material: (_) => MaterialReorderableListViewControl(control: control),
        cupertino: (_) => CupertinoReorderableListViewControl(control: control),
      );
}
