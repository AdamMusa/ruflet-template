import 'package:flutter/widgets.dart';

import '../controls/cupertino_control_chrome.dart';
import '../controls/material_control_chrome.dart';
import '../models/control.dart';
import 'platform_control_renderer.dart';

class PlatformControlBadge extends StatelessWidget {
  final Control control;
  final Widget child;

  const PlatformControlBadge({
    super.key,
    required this.control,
    required this.child,
  });

  @override
  Widget build(BuildContext context) => PlatformControlRenderer(
        material: (_) => MaterialControlBadge(control: control, child: child),
        cupertino: (_) => CupertinoControlBadge(control: control, child: child),
      );
}
