// Modified from flutter_code_editor 0.3.5 for the Cupertino renderer.
// Upstream license: cupertino_editor/LICENSE (Apache-2.0).
import 'package:flutter/widgets.dart';

/// MouseRegion + GestureDetector.
class ClickableWidget extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;

  const ClickableWidget({
    required this.child,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (onTap == null) return child;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: child,
      ),
    );
  }
}
