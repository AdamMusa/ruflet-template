import 'package:flutter/cupertino.dart';

import '../extensions/control.dart';
import '../models/control.dart';
import '../utils/borders.dart';
import '../utils/colors.dart';
import '../utils/edge_insets.dart';
import '../utils/numbers.dart';
import 'base_controls.dart';

class CupertinoBottomAppBarControl extends StatelessWidget {
  final Control control;

  const CupertinoBottomAppBarControl({super.key, required this.control});

  @override
  Widget build(BuildContext context) {
    final borderRadius = control.getBorderRadius("border_radius");
    Widget bar = DecoratedBox(
      decoration: BoxDecoration(
        color: control.getColor("bgcolor", context) ??
            CupertinoColors.systemBackground.resolveFrom(context),
        borderRadius: borderRadius,
        border: Border(
          top: BorderSide(
            color: CupertinoColors.separator.resolveFrom(context),
            width: 0.5,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: control.getPadding("padding", EdgeInsets.zero)!,
          child: SizedBox(
            height: control.getDouble("height"),
            child: control.buildWidget("content"),
          ),
        ),
      ),
    );
    if (borderRadius != null) {
      bar = ClipRRect(borderRadius: borderRadius, child: bar);
    }
    return LayoutControl(control: control, child: bar);
  }
}
