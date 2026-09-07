import 'package:ruflet/ruflet.dart';
import 'package:flutter/widgets.dart';

import 'cupertino_material_picker.dart';
import 'material_material_picker.dart';

class MaterialPickerControl extends StatelessWidget {
  final Control control;
  const MaterialPickerControl({super.key, required this.control});

  @override
  Widget build(BuildContext context) => PlatformControlRenderer(
        material: (_) => MaterialMaterialPickerControl(control: control),
        cupertino: (_) => CupertinoMaterialPickerControl(control: control),
      );
}
