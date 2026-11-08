import 'package:flutter/cupertino.dart';

import '../models/control.dart';
import '../utils/borders.dart';
import '../utils/colors.dart';
import '../utils/numbers.dart';
import 'base_controls.dart';

class CupertinoDividerControl extends StatelessWidget {
  final Control control;

  const CupertinoDividerControl({super.key, required this.control});

  @override
  Widget build(BuildContext context) {
    final height = control.getDouble("height", 1)!;
    final thickness = control.getDouble("thickness", 0.5)!;
    final leading = control.getDouble("leading_indent", 0)!;
    final trailing = control.getDouble("trailing_indent", 0)!;
    return BaseControl(
      control: control,
      child: SizedBox(
        height: height,
        child: Padding(
          padding: EdgeInsetsDirectional.only(start: leading, end: trailing),
          child: Center(
            child: Container(
              height: thickness,
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
