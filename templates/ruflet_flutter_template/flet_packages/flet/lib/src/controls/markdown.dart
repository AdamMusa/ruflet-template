import 'package:flutter/widgets.dart';

import '../models/control.dart';
import '../widgets/platform_control_renderer.dart';
import 'cupertino_markdown.dart';
import 'material_markdown.dart';

class MarkdownControl extends StatelessWidget {
  final Control control;

  const MarkdownControl({super.key, required this.control});

  @override
  Widget build(BuildContext context) => PlatformControlRenderer(
        material: (_) => MaterialMarkdownControl(control: control),
        cupertino: (_) => CupertinoMarkdownControl(control: control),
      );
}
