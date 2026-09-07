import 'package:ruflet/ruflet.dart';
import 'package:flutter/widgets.dart';

import 'cupertino_block_picker.dart';
import 'material_block_picker.dart';

class BlockPickerControl extends StatelessWidget {
  final Control control;
  const BlockPickerControl({super.key, required this.control});

  @override
  Widget build(BuildContext context) => PlatformControlRenderer(
        material: (_) => MaterialBlockPickerControl(control: control),
        cupertino: (_) => CupertinoBlockPickerControl(control: control),
      );
}
