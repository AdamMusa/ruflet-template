import 'package:flutter/material.dart';

import '../extensions/control.dart';
import '../models/control.dart';
import '../utils/numbers.dart';
import '../widgets/control_inherited_notifier.dart';
import '../widgets/control_route.dart';
import '../widgets/material_dialog_route.dart';

/// Material renderer of `AboutDialog`: the SDK [AboutDialog] (with its
/// built-in "View licenses" button) or, with `view: "licenses"`, the SDK
/// [LicensePage] directly.
class MaterialAboutDialogControl extends StatelessWidget {
  final Control control;

  const MaterialAboutDialogControl({super.key, required this.control});

  bool get _licensesOnly =>
      control.getString("view", "about")!.toLowerCase() == "licenses";

  /// Rebuilds [builder] on control changes; routes opened from inside (the
  /// SDK "View licenses" button) are adopted, so they close with the dialog.
  Widget _live(WidgetBuilder builder) {
    return ControlRouteScope(
      control: control,
      child: ControlInheritedNotifier(
        notifier: control,
        child: Builder(builder: (context) {
          ControlInheritedNotifier.of(context);
          return builder(context);
        }),
      ),
    );
  }

  Route<void> _createRoute(BuildContext context) {
    if (_licensesOnly) {
      return MaterialPageRoute<void>(
        builder: (_) => _live((context) => LicensePage(
              applicationName: control.getString("application_name"),
              applicationVersion: control.getString("application_version"),
              applicationIcon: control.buildIconOrWidget("application_icon"),
              applicationLegalese: control.getString("application_legalese"),
            )),
      );
    }
    return ControlMaterialDialogRoute<void>(
      control: control,
      context: context,
      barrierDismissible: !control.getBool("modal", false)!,
      builder: (_) => _live((context) => SafeArea(
            child: AboutDialog(
              applicationName: control.getString("application_name"),
              applicationVersion: control.getString("application_version"),
              applicationIcon: control.buildIconOrWidget("application_icon"),
              applicationLegalese: control.getString("application_legalese"),
              children: control.buildWidgets("controls"),
            ),
          )),
    );
  }

  @override
  Widget build(BuildContext context) {
    debugPrint("AboutDialog build: ${control.id}");

    final open = control.getBool("open", false)!;
    final lastOpen = control.getBool("_open", false)!;

    if (open && !lastOpen) {
      presentControlRoute(context, control, () => _createRoute(context));
    } else if (!open && lastOpen) {
      closeControlRoute(control);
    }
    return const SizedBox.shrink();
  }
}
