import 'package:flutter/cupertino.dart';

import '../models/control.dart';
import '../utils/borders.dart';
import '../utils/colors.dart';
import '../utils/edge_insets.dart';
import '../utils/misc.dart';
import '../utils/numbers.dart';
import 'base_controls.dart';
import 'control_widget.dart';

class CupertinoCardControl extends StatelessWidget {
  final Control control;

  const CupertinoCardControl({super.key, required this.control});

  @override
  Widget build(BuildContext context) {
    final content = control.child("content");
    final variant = control.getString("variant", "elevated")!.toLowerCase();
    final elevation = control.getDouble("elevation", 1)!;
    final radius = control.getBorderRadius("border_radius") ??
        const BorderRadius.all(Radius.circular(12));
    final color = control.getColor("bgcolor", context) ??
        CupertinoColors.secondarySystemGroupedBackground.resolveFrom(context);
    final borderColor = CupertinoColors.separator.resolveFrom(context);

    Widget result = Container(
      margin: control.getMargin("margin", const EdgeInsets.all(4)),
      clipBehavior: control.getClipBehavior("clip_behavior", Clip.antiAlias)!,
      decoration: BoxDecoration(
        color: color,
        borderRadius: radius,
        border: variant == "outlined" ? Border.all(color: borderColor) : null,
        boxShadow: variant == "elevated" && elevation > 0
            ? [
                BoxShadow(
                  color: control.getColor("shadow_color", context) ??
                      const Color(0x26000000),
                  blurRadius: elevation * 2,
                  offset: Offset(0, elevation),
                )
              ]
            : null,
      ),
      child: content == null ? null : ControlWidget(control: content),
    );
    if (control.getBool("semantic_container", true)!) {
      result = Semantics(container: true, child: result);
    }
    return LayoutControl(control: control, child: result);
  }
}
