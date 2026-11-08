import 'package:flutter/cupertino.dart';

import '../models/control.dart';
import '../utils/borders.dart';
import '../utils/colors.dart';
import '../utils/numbers.dart';
import 'base_controls.dart';

class CupertinoVerticalDividerControl extends StatelessWidget {
  final Control control;

  const CupertinoVerticalDividerControl({super.key, required this.control});

  @override
  Widget build(BuildContext context) {
    final width = control.getDouble("width", 1)!;
    final thickness = control.getDouble("thickness", 0.5)!;
    final leading = control.getDouble("leading_indent", 0)!;
    final trailing = control.getDouble("trailing_indent", 0)!;
    return BaseControl(
      control: control,
      child: SizedBox(
        width: width,
        child: Padding(
          padding: EdgeInsets.only(top: leading, bottom: trailing),
          child: Center(
            child: Container(
              width: thickness,
              decoration: BoxDecoration(
                color: control.getColor("color", context) ??
                    CupertinoColors.separator.resolveFrom(context),
                borderRadius: control.getBorderRadius("radius"),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
