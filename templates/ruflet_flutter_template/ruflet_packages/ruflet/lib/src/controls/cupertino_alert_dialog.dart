import 'package:flutter/cupertino.dart';

import '../extensions/control.dart';
import '../models/control.dart';
import '../utils/animations.dart';
import '../utils/numbers.dart';
import '../widgets/cupertino_dialog_route.dart';
import '../widgets/control_inherited_notifier.dart';
import '../widgets/control_route.dart';
import '../widgets/error.dart';
import 'base_controls.dart';

class CupertinoAlertDialogControl extends StatelessWidget {
  final Control control;

  const CupertinoAlertDialogControl({super.key, required this.control});

  Widget _createCupertinoAlertDialog() {
    return ControlInheritedNotifier(
      notifier: control,
      child: Builder(builder: (context) {
        ControlInheritedNotifier.of(context);
        var insetAnimation = parseAnimation(
            control.get("inset_animation"),
            ImplicitAnimationDetails(
                duration: const Duration(milliseconds: 100),
                curve: Curves.decelerate))!;

        final dialog = CupertinoAlertDialog(
          insetAnimationCurve: insetAnimation.curve,
          insetAnimationDuration: insetAnimation.duration,
          title: control.buildTextOrWidget("title"),
          content: control.buildWidget("content"),
          actions: control.buildWidgets("actions"),
        );
        return SafeArea(child: BaseControl(control: control, child: dialog));
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    debugPrint("CupertinoAlertDialog build: ${control.id}");

    final lastOpen = control.getBool("_open", false)!;
    var open = control.getBool("open", false)!;
    var modal = control.getBool("modal", false)!;

    if (open && (open != lastOpen)) {
      if (control.get("title") == null &&
          control.get("content") == null &&
          control.children("actions").isEmpty) {
        return const ErrorControl(
            "CupertinoAlertDialog has nothing to display. Provide at minimum one of the following: title, content, actions.");
      }

      presentControlRoute(
          context,
          control,
          () => ControlCupertinoDialogRoute<void>(
              control: control,
              barrierDismissible: !modal,
              context: context,
              builder: (context) => _createCupertinoAlertDialog()));
    } else if (!open && lastOpen) {
      closeControlRoute(control);
    }
    return const SizedBox.shrink();
  }
}
