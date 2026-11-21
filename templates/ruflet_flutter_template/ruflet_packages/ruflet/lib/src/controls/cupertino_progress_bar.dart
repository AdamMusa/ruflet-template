import 'package:flutter/cupertino.dart';

import '../models/control.dart';
import '../utils/borders.dart';
import '../utils/colors.dart';
import '../utils/numbers.dart';
import 'base_controls.dart';

class CupertinoProgressBarControl extends StatelessWidget {
  final Control control;

  const CupertinoProgressBarControl({super.key, required this.control});

  @override
  Widget build(BuildContext context) {
    final value = control.getDouble("value");
    final height = control.getDouble("bar_height", 3)!;
    final radius = control.getBorderRadius("border_radius") ??
        BorderRadius.circular(height / 2);
    final color = control.getColor("color", context) ??
        CupertinoColors.activeBlue.resolveFrom(context);
    final background = control.getColor("bgcolor", context) ??
        CupertinoColors.systemGrey5.resolveFrom(context);

    final indicator = Semantics(
      label: control.getString("semantics_label"),
      value: control.get("semantics_value")?.toString(),
      child: ClipRRect(
        borderRadius: radius,
        child: SizedBox(
          height: height,
          child: value == null
              ? CupertinoActivityIndicator(color: color, radius: height * 2)
              : LayoutBuilder(builder: (context, constraints) {
                  return ColoredBox(
                    color: background,
                    child: Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: SizedBox(
                        width: constraints.maxWidth * value.clamp(0, 1),
                        child: ColoredBox(color: color),
                      ),
                    ),
                  );
                }),
        ),
      ),
    );
    return LayoutControl(control: control, child: indicator);
  }
}
