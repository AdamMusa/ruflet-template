import 'package:flutter/widgets.dart';

import '../controls/cupertino_control_theme.dart';
import '../controls/material_control_theme.dart';
import '../models/control.dart';
import 'platform_control_renderer.dart';

/// Applies a per-control theme without leaking the opposite design system into
/// the rendered subtree.
class PlatformControlTheme extends StatelessWidget {
  final Control control;
  final Widget child;

  const PlatformControlTheme({
    super.key,
    required this.control,
    required this.child,
  });

  @override
  Widget build(BuildContext context) => PlatformControlRenderer(
        material: (_) => MaterialControlTheme(control: control, child: child),
        cupertino: (_) => CupertinoControlTheme(control: control, child: child),
      );
}
