import 'package:flutter/widgets.dart';

import '../controls/cupertino_control_chrome.dart';
import '../controls/material_control_chrome.dart';
import '../models/control.dart';
import 'platform_control_renderer.dart';

class PlatformControlTooltip extends StatelessWidget {
  final Control control;
  final Widget child;

  const PlatformControlTooltip({
    super.key,
    required this.control,
    required this.child,
  });

  @override
  Widget build(BuildContext context) => PlatformControlRenderer(
        material: (_) => MaterialControlTooltip(control: control, child: child),
        cupertino: (_) =>
            CupertinoControlTooltip(control: control, child: child),
      );
}
