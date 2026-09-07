// Modified from flutter_code_editor 0.3.5 for the Cupertino renderer.
// Upstream license: cupertino_editor/LICENSE (Apache-2.0).
import 'package:flutter/cupertino.dart';

import 'clickable.dart';

class FoldToggle extends StatelessWidget {
  final Color? color;
  final bool isFolded;
  final VoidCallback onTap;

  const FoldToggle({
    required this.color,
    required this.isFolded,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ClickableWidget(
      onTap: onTap,
      child: RotatedBox(
        quarterTurns: isFolded ? 0 : 1,
        child: Icon(
          CupertinoIcons.chevron_right,
          color: color,
          size: 16,
        ),
      ),
    );
  }
}
