import 'package:flutter/cupertino.dart';

import '../extensions/control.dart';
import '../models/control.dart';
import '../services/client_action.dart' show runControlClientActions;
import '../utils/colors.dart';
import '../utils/launch_url.dart';
import '../utils/numbers.dart';
import '../widgets/error.dart';
import 'base_controls.dart';

class CupertinoFloatingActionButtonControl extends StatelessWidget {
  final Control control;

  const CupertinoFloatingActionButtonControl(
      {super.key, required this.control});

  @override
  Widget build(BuildContext context) {
    final icon = control.buildIconOrWidget("icon");
    final content = control.buildTextOrWidget("content");
    if (icon == null && content == null) {
      return const ErrorControl(
          "FloatingActionButton has nothing to display. Provide at minimum one of these: icon, content");
    }
    final child = icon ?? content!;
    final mini = control.getBool("mini", false)!;
    final url = control.getUrl("url");
    final button = CupertinoButton(
      minimumSize: Size.square(mini ? 40 : 56),
      padding: icon != null && content != null
          ? const EdgeInsets.symmetric(horizontal: 18)
          : EdgeInsets.zero,
      borderRadius: BorderRadius.circular(mini ? 20 : 28),
      color: control.getColor("bgcolor", context) ??
          CupertinoTheme.of(context).primaryColor,
      foregroundColor: control.getColor("foreground_color", context) ??
          (control.disabled
              ? null
              : CupertinoTheme.of(context).primaryContrastingColor),
      disabledColor: CupertinoColors.tertiarySystemFill.resolveFrom(context),
      onPressed: control.disabled
          ? null
          : () {
              runControlClientActions(control);
              if (url != null) openWebBrowser(url);
              control.triggerEvent("click");
            },
      child: icon != null && content != null
          ? Row(mainAxisSize: MainAxisSize.min, children: [icon, content])
          : child,
    );
    return LayoutControl(control: control, child: button);
  }
}
