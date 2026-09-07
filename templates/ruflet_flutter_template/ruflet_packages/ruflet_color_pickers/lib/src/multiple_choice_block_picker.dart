import 'package:ruflet/ruflet.dart';
import 'package:flutter/widgets.dart';

import 'cupertino_multiple_choice_block_picker.dart';
import 'material_multiple_choice_block_picker.dart';

class MultipleChoiceBlockPickerControl extends StatelessWidget {
  final Control control;
  const MultipleChoiceBlockPickerControl({super.key, required this.control});

  @override
  Widget build(BuildContext context) => PlatformControlRenderer(
        material: (_) =>
            MaterialMultipleChoiceBlockPickerControl(control: control),
        cupertino: (_) =>
            CupertinoMultipleChoiceBlockPickerControl(control: control),
      );
}
