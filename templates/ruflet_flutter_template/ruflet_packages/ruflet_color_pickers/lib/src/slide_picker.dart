import 'package:ruflet/ruflet.dart';
import 'package:flutter/widgets.dart';

import 'cupertino_slide_picker.dart';
import 'material_slide_picker.dart';

class SlidePickerControl extends StatelessWidget {
  final Control control;
  const SlidePickerControl({super.key, required this.control});

  @override
  Widget build(BuildContext context) => PlatformControlRenderer(
        material: (_) => MaterialSlidePickerControl(control: control),
        cupertino: (_) => CupertinoSlidePickerControl(control: control),
      );
}
