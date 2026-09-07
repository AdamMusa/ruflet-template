import 'package:flutter/material.dart';

import '../extensions/control.dart';
import '../models/control.dart';
import '../utils/numbers.dart';
import '../utils/time.dart';
import '../widgets/error.dart';
import 'base_controls.dart';
import 'control_widget.dart';
import 'date_picker.dart';

class MaterialActionSheetControl extends StatelessWidget {
  final Control control;

  const MaterialActionSheetControl({super.key, required this.control});

  @override
  Widget build(BuildContext context) {
    var actions = control.buildWidgets("actions");
    if (actions.isEmpty && control.buildWidget("cancel") == null) {
      return const ErrorControl(
          "ActionSheet requires an action or cancel button");
    }
    var theme = Theme.of(context);
    var title = control.buildTextOrWidget("title",
        textStyle: theme.textTheme.titleLarge);
    var message = control.buildTextOrWidget("message",
        textStyle: theme.textTheme.bodyMedium);
    var cancel = control.buildWidget("cancel");
    return LayoutControl(
      control: control,
      child: SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (title != null)
            Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                child: title),
          if (message != null)
            Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: message),
          ...actions,
          if (cancel != null) const Divider(height: 1),
          if (cancel != null) cancel,
        ]),
      ),
    );
  }
}

class MaterialActionSheetActionControl extends StatelessWidget {
  final Control control;

  const MaterialActionSheetActionControl({super.key, required this.control});

  @override
  Widget build(BuildContext context) {
    var theme = Theme.of(context);
    var destructive = control.getBool("destructive", false)!;
    var isDefault = control.getBool("default", false)!;
    var content = control.buildTextOrWidget(
      "content",
      textStyle: theme.textTheme.labelLarge?.copyWith(
        color: destructive ? theme.colorScheme.error : null,
        fontWeight: isDefault ? FontWeight.bold : null,
      ),
    );
    if (content == null) {
      return const ErrorControl("ActionSheetAction.content must be provided");
    }
    return ListTile(
      enabled: !control.disabled,
      title: content,
      onTap: control.disabled ? null : () => control.triggerEvent("click"),
    );
  }
}

class MaterialContextMenuActionControl extends StatelessWidget {
  final Control control;

  const MaterialContextMenuActionControl({super.key, required this.control});

  @override
  Widget build(BuildContext context) {
    var content = control.buildTextOrWidget("content");
    if (content == null) {
      return const ErrorControl("ContextMenuAction.content must be provided");
    }
    return MenuItemButton(
      leadingIcon: control.buildIconOrWidget("icon"),
      onPressed: control.disabled ? null : () => control.triggerEvent("click"),
      child: content,
    );
  }
}

class MaterialDatePickerRenderer extends StatelessWidget {
  final Control control;

  const MaterialDatePickerRenderer({super.key, required this.control});

  @override
  Widget build(BuildContext context) => control.type == "CupertinoDatePicker"
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

class MaterialPickerControl extends StatelessWidget {
  final Control control;

  const MaterialPickerControl({super.key, required this.control});

  @override
  Widget build(BuildContext context) {
    var controls = control.children("controls");
    if (controls.isEmpty) {
      return const ErrorControl("Picker.controls must not be empty");
    }
    var selectedIndex = control.getInt("selected_index", 0)!;
    if (selectedIndex < 0 || selectedIndex >= controls.length) {
      return const ErrorControl("Picker.selected_index is out of range");
    }
    return LayoutControl(
      control: control,
      child: DropdownButton<int>(
        value: selectedIndex,
        isExpanded: control.getBool("expand", false)!,
        onChanged: control.disabled
            ? null
            : (index) {
                if (index == null) return;
                control
                    .updateProperties({"selected_index": index}, notify: true);
                control.triggerEvent("change", index);
              },
        items: controls.asMap().entries.map((entry) {
          return DropdownMenuItem<int>(
            value: entry.key,
            enabled: !entry.value.disabled,
            child: ControlWidget(control: entry.value),
          );
        }).toList(),
      ),
    );
  }
}

class MaterialTimerPickerControl extends StatefulWidget {
  final Control control;

  const MaterialTimerPickerControl({super.key, required this.control});

  @override
  State<MaterialTimerPickerControl> createState() =>
      _MaterialTimerPickerControlState();
}

class _MaterialTimerPickerControlState
    extends State<MaterialTimerPickerControl> {
  void _change({int? hours, int? minutes, int? seconds}) {
    var duration = widget.control
        .getDuration("value", Duration.zero, DurationUnit.seconds)!;
    var next = Duration(
      hours: hours ?? duration.inHours,
      minutes: minutes ?? duration.inMinutes.remainder(60),
      seconds: seconds ?? duration.inSeconds.remainder(60),
    );
    var value = widget.control.get("value") is int ? next.inSeconds : next;
    widget.control.updateProperties({"value": value}, notify: true);
    widget.control.triggerEvent("change", value);
  }

  @override
  Widget build(BuildContext context) {
    var duration = widget.control
        .getDuration("value", Duration.zero, DurationUnit.seconds)!;
    var mode = widget.control.getString("mode", "hms")!;
    var minuteInterval = widget.control.getInt("minute_interval", 1)!;
    var secondInterval = widget.control.getInt("second_interval", 1)!;
    if (minuteInterval < 1) minuteInterval = 1;
    if (secondInterval < 1) secondInterval = 1;
    var hours = duration.inHours.clamp(0, 23);
    var minutes = duration.inMinutes.remainder(60);
    var seconds = duration.inSeconds.remainder(60);
    var minuteValues = {
      minutes,
      for (var value = 0; value < 60; value += minuteInterval) value,
    }.toList()
      ..sort();
    var secondValues = {
      seconds,
      for (var value = 0; value < 60; value += secondInterval) value,
    }.toList()
      ..sort();

    DropdownButton<int> selector(
        int value, Iterable<int> values, ValueChanged<int?> changed) {
      return DropdownButton<int>(
        value: value,
        onChanged: widget.control.disabled ? null : changed,
        items: values
            .map((value) => DropdownMenuItem(
                  value: value,
                  child: Text(value.toString().padLeft(2, "0")),
                ))
            .toList(),
      );
    }

    var children = <Widget>[];
    if (mode != "ms") {
      children.add(selector(hours, List.generate(24, (index) => index),
          (value) => _change(hours: value)));
      children.add(const Text(" : "));
    }
    children.add(
        selector(minutes, minuteValues, (value) => _change(minutes: value)));
    if (mode != "hm") {
      children.add(const Text(" : "));
      children.add(
          selector(seconds, secondValues, (value) => _change(seconds: value)));
    }
    return LayoutControl(
      control: widget.control,
      child: Row(mainAxisSize: MainAxisSize.min, children: children),
    );
  }
}
