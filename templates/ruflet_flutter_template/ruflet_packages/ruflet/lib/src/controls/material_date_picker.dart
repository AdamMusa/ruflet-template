import 'package:flutter/material.dart';
import '../models/control.dart';
import '../utils/numbers.dart';
import '../utils/presentation.dart';
import '../utils/time.dart';
import 'base_controls.dart';
import 'date_picker.dart';

class MaterialDatePickerRenderer extends StatelessWidget {
  final Control control;

  const MaterialDatePickerRenderer({super.key, required this.control});

  @override
  // `inline` renders the calendar in place; otherwise it is a dialog. A
  // picker the page presents (show_dialog / open) is always a dialog.
  Widget build(BuildContext context) =>
      control.getBool("inline", false)! && !control.presentedByPage
          ? MaterialInlineDatePickerControl(control: control)
          : DatePickerControl(control: control);
}

class MaterialInlineDatePickerControl extends StatelessWidget {
  final Control control;

  const MaterialInlineDatePickerControl({super.key, required this.control});

  @override
  Widget build(BuildContext context) {
    var value = control.getDateTime("value") ?? DateTime.now();
    return LayoutControl(
      control: control,
      child: CalendarDatePicker(
        initialDate: value,
        firstDate: control.getDateTime("first_date", DateTime(1900, 1, 1))!,
        lastDate: control.getDateTime("last_date", DateTime(2050, 1, 1))!,
        currentDate: control.getDateTime("current_date"),
        onDateChanged: (next) {
          control.updateProperties({"value": next});
          control.triggerEvent("change", next);
        },
      ),
    );
  }
}
