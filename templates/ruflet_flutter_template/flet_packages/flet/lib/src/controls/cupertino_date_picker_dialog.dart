import 'package:flutter/cupertino.dart';

import '../models/control.dart';
import '../utils/numbers.dart';
import 'cupertino_date_picker.dart';

class CupertinoDatePickerRenderer extends StatelessWidget {
  final Control control;

  const CupertinoDatePickerRenderer({super.key, required this.control});

  @override
  Widget build(BuildContext context) => control.type == "CupertinoDatePicker"
      ? CupertinoDatePickerControl(control: control)
      : CupertinoDatePickerDialogControl(control: control);
}

class CupertinoDatePickerDialogControl extends StatelessWidget {
  final Control control;

  const CupertinoDatePickerDialogControl({super.key, required this.control});

  @override
  Widget build(BuildContext context) {
    var lastOpen = control.getBool("_open", false)!;
    var open = control.getBool("open", false)!;
    if (open && !lastOpen) {
      control.updateProperties({"_open": true}, python: false);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        showCupertinoModalPopup<void>(
          context: context,
          useRootNavigator: false,
          barrierDismissible: !control.getBool("modal", false)!,
          builder: (context) => Container(
            height: control.getDouble("height", 260)!,
            color: CupertinoColors.systemBackground.resolveFrom(context),
            child: SafeArea(
              top: false,
              child: CupertinoDatePickerControl(control: control),
            ),
          ),
        ).then((_) {
          control.updateProperties({"_open": false}, python: false);
          control.updateProperties({"open": false});
          control.triggerEvent("dismiss");
        });
      });
    } else if (!open && lastOpen && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
    return const SizedBox.shrink();
  }
}
