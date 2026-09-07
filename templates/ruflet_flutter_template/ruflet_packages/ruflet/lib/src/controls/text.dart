import 'package:flutter/widgets.dart';

import '../models/control.dart';
import '../widgets/platform_control_renderer.dart';
import 'cupertino_text.dart';
import 'material_text.dart';

class TextControl extends StatelessWidget {
  final Control control;

  const TextControl({super.key, required this.control});

  @override
  Widget build(BuildContext context) => PlatformControlRenderer(
        material: (_) => MaterialTextControl(control: control),
        cupertino: (_) => CupertinoTextControl(control: control),
      );
}
