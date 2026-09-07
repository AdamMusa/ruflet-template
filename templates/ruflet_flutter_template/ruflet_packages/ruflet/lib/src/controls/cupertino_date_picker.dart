import 'package:flutter/cupertino.dart';

import '../models/control.dart';
import '../utils/cupertino_enums.dart';
import '../utils/colors.dart';
import '../utils/locale.dart';
import '../utils/numbers.dart';
import '../utils/time.dart';
import '../widgets/error.dart';
import 'base_controls.dart';

class CupertinoDatePickerControl extends StatelessWidget {
  final Control control;
  final void Function(DateTime)? onDateTimeChanged;
  final bool applyLayout;

  CupertinoDatePickerControl(
      {Key? key,
      required this.control,
      this.onDateTimeChanged,
      this.applyLayout = true})
      : super(key: key ?? ValueKey("control_${control.id}"));

  @override
  Widget build(BuildContext context) {
    var locale = control.getLocale("locale");

    Widget dialog;
    try {
      dialog = CupertinoDatePicker(
        initialDateTime: control.getDateTime("value"),
        showDayOfWeek: control.getBool("show_day_of_week", false)!,
        minimumDate: control.getDateTime("first_date"),
        maximumDate: control.getDateTime("last_date"),
        backgroundColor: control.getColor("bgcolor", context),
        minimumYear: control.getInt("minimum_year", 1)!,
        maximumYear: control.getInt("maximum_year"),
        itemExtent: control.getDouble("item_extent", 32.0)!,
        minuteInterval: control.getInt("minute_interval", 1)!,
        use24hFormat: control.getBool("use_24h_format", false)!,
        dateOrder: control.getDatePickerDateOrder("date_order"),
        mode: control.getCupertinoDatePickerMode(
            "date_picker_mode",
            control.type == "CupertinoDatePicker"
                ? CupertinoDatePickerMode.dateAndTime
                : CupertinoDatePickerMode.date)!,
        onDateTimeChanged: onDateTimeChanged ??
            (DateTime value) {
              control.updateProperties({"value": value});
              control.triggerEvent("change", value);
            },
      );
    } catch (e) {
      return ErrorControl("CupertinoDatePicker Error: ${e.toString()}");
    }

    final picker = locale == null || !locale.isSupportedByDelegates()
        ? dialog
        : Localizations.override(
            context: context, locale: locale, child: dialog);
    return applyLayout
        ? LayoutControl(control: control, child: picker)
        : picker;
  }
}
