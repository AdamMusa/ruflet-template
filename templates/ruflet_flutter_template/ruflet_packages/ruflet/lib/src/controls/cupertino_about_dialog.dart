import 'package:flutter/cupertino.dart';

import '../extensions/control.dart';
import '../models/control.dart';
import '../utils/numbers.dart';
import '../widgets/control_inherited_notifier.dart';
import '../widgets/control_route.dart';
import '../widgets/cupertino_dialog_route.dart';
import '../widgets/cupertino_license_page.dart';

/// iOS renderer of `AboutDialog` (hand-built, D-7): a [CupertinoAlertDialog]
/// with "View Licenses" and "Close" actions. "View Licenses" (or
/// `view: "licenses"`) pushes the Cupertino [CupertinoLicensePage].
class CupertinoAboutDialogControl extends StatelessWidget {
  final Control control;

  const CupertinoAboutDialogControl({super.key, required this.control});

  bool get _licensesOnly =>
      control.getString("view", "about")!.toLowerCase() == "licenses";

  /// Rebuilds [builder] on control changes; routes opened from inside (the
  /// licenses pages) are adopted, so they close with the dialog.
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

  String _applicationName(BuildContext context) =>
      control.getString("application_name") ??
      context.findAncestorWidgetOfExactType<Title>()?.title ??
      "";

  Widget _licensePage(BuildContext context) => CupertinoLicensePage(
        applicationName: _applicationName(context),
        applicationVersion: control.getString("application_version"),
        applicationIcon: control.buildIconOrWidget("application_icon"),
        applicationLegalese: control.getString("application_legalese"),
      );

  Widget _alert(BuildContext context) {
    final name = _applicationName(context);
    final version = control.getString("application_version") ?? "";
    final icon = control.buildIconOrWidget("application_icon");
    final legalese = control.getString("application_legalese");
    final extra = control.buildWidgets("controls");

    return SafeArea(
      child: CupertinoAlertDialog(
        title: Text("$name $version".trim()),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null)
              Padding(padding: const EdgeInsets.only(top: 8), child: icon),
            if (legalese != null && legalese.isNotEmpty)
              Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(legalese)),
            ...extra.map((child) =>
                Padding(padding: const EdgeInsets.only(top: 8), child: child)),
          ],
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => pushCarryingThemes(
                context,
                (wrap) => CupertinoPageRoute<void>(
                    builder: (_) => wrap(_live(_licensePage)))),
            child: const Text("View Licenses"),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(context).pop(),
            child: const Text("Close"),
          ),
        ],
      ),
    );
  }

  Route<void> _createRoute(BuildContext context) {
    if (_licensesOnly) {
      return CupertinoPageRoute<void>(builder: (_) => _live(_licensePage));
    }
    return ControlCupertinoDialogRoute<void>(
      control: control,
      context: context,
      barrierDismissible: !control.getBool("modal", false)!,
      builder: (_) => _live(_alert),
    );
  }

  @override
  Widget build(BuildContext context) {
    debugPrint("CupertinoAboutDialog build: ${control.id}");

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
