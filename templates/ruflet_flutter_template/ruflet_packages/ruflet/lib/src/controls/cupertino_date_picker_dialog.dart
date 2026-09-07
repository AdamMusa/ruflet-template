import 'package:flutter/cupertino.dart';

import '../models/control.dart';
import '../utils/numbers.dart';
import '../utils/time.dart';
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
    final lastOpen = control.getBool("_open", false)!;
    final open = control.getBool("open", false)!;
    final initialValue = control.getDateTime("value");
    if (open && !lastOpen) {
      control.updateProperties({"_open": true}, python: false);
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        var selected = initialValue ??
            control.getDateTime("current_date") ??
            DateTime.now();
        final result = await showCupertinoModalPopup<DateTime>(
          context: context,
          useRootNavigator: false,
          barrierDismissible: !control.getBool("modal", false)!,
          builder: (context) => CupertinoPopupSurface(
            child: SafeArea(
              top: false,
              child: SizedBox(
                height: control.getDouble("height", 260)!,
                child: Column(
                  children: [
                    SizedBox(
                      height: 44,
                      child: Row(
                        children: [
                          CupertinoButton(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            onPressed: () => Navigator.pop(context),
                            child: Text(
                                control.getString("cancel_text", "Cancel")!),
                          ),
                          Expanded(
                            child: Text(
                              control.getString("help_text", "")!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                            ),
                          ),
                          CupertinoButton(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            onPressed: () => Navigator.pop(context, selected),
                            child: Text(
                                control.getString("confirm_text", "Done")!),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: CupertinoDatePickerControl(
                        control: control,
                        applyLayout: false,
                        onDateTimeChanged: (value) => selected = value,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        control.updateProperties({"_open": false}, python: false);
        control
            .updateProperties({"value": result ?? initialValue, "open": false});
        if (result != null) control.triggerEvent("change", result);
        control.triggerEvent("dismiss", result == null);
      });
    } else if (!open && lastOpen && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
    return const SizedBox.shrink();
  }
}
