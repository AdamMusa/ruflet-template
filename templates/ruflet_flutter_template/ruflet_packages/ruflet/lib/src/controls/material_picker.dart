import 'package:flutter/material.dart';
import '../models/control.dart';
import '../utils/numbers.dart';
import '../widgets/error.dart';
import 'base_controls.dart';
import 'control_widget.dart';

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
