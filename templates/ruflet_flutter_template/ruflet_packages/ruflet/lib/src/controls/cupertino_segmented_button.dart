import 'package:flutter/cupertino.dart';

import '../extensions/control.dart';
import '../models/control.dart';
import '../utils/colors.dart';
import '../utils/edge_insets.dart';
import '../utils/misc.dart';
import '../utils/numbers.dart';
import '../widgets/error.dart';
import 'base_controls.dart';
import 'control_widget.dart';

class CupertinoSegmentedButtonControl extends StatefulWidget {
  final Control control;

  CupertinoSegmentedButtonControl({Key? key, required this.control})
      : super(key: key ?? ValueKey("control_${control.id}"));

  @override
  State<CupertinoSegmentedButtonControl> createState() =>
      _CupertinoSegmentedButtonControlState();
}

class _CupertinoSegmentedButtonControlState
    extends State<CupertinoSegmentedButtonControl> {
  @override
  Widget build(BuildContext context) {
    debugPrint("CupertinoSegmentedButtonControl build: ${widget.control.id}");

    var segments = widget.control.children("segments");
    if (segments.isNotEmpty) {
      return _buildCanonicalSegments(context, segments);
    }

    var controls = widget.control.buildWidgets("controls");
    var selectedIndex = widget.control.getInt("selected_index");

    if (controls.length < 2) {
      return const ErrorControl(
          "CupertinoSegmentedButton must have at minimum two visible controls");
    }

    var segmentedButton = CupertinoSegmentedControl(
      groupValue: selectedIndex,
      borderColor: widget.control.getColor("border_color", context),
      selectedColor: widget.control.getColor("selected_color", context),
      unselectedColor: widget.control.getColor("unselected_color", context),
      pressedColor: widget.control.getColor("click_color", context),
      disabledColor: widget.control.getColor("disabled_color", context),
      disabledTextColor:
          widget.control.getColor("disabled_text_color", context),
      padding: widget.control.getPadding("padding"),
      children: controls.asMap().map((i, c) => MapEntry(i, c)),
      onValueChanged: (int index) {
        if (!widget.control.disabled) {
          widget.control.updateProperties({"selected_index": index});
          widget.control.triggerEvent("change", index);
          setState(() {
            selectedIndex = index;
          });
        }
      },
    );

    return LayoutControl(control: widget.control, child: segmentedButton);
  }

  Widget _buildCanonicalSegments(BuildContext context, List<Control> segments) {
    var allowEmpty = widget.control.getBool("allow_empty_selection", false)!;
    var allowMultiple =
        widget.control.getBool("allow_multiple_selection", false)!;
    var selected = widget.control
        .get<List>("selected", [])!
        .map((value) => value.toString())
        .toSet();

    if (selected.isEmpty && !allowEmpty) {
      return const ErrorControl(
          "SegmentedButton.selected must contain at least one value because allow_empty_selection=False");
    }
    if (!allowMultiple && selected.length > 1) {
      return const ErrorControl(
          "SegmentedButton.selected must contain at most one value because allow_multiple_selection=False");
    }

    void toggle(Control segment) {
      if (widget.control.disabled || segment.disabled) return;
      var value = segment.getString("value")!;
      var next = Set<String>.from(selected);
      if (next.contains(value)) {
        if (allowEmpty || next.length > 1) next.remove(value);
      } else {
        if (!allowMultiple) next.clear();
        next.add(value);
      }
      widget.control
          .updateProperties({"selected": next.toList()}, notify: true);
      widget.control.triggerEvent("change", next.toList());
      setState(() {});
    }

    Widget buildContent(Control segment, bool isSelected) {
      var icon =
          isSelected && widget.control.getBool("show_selected_icon", true)!
              ? widget.control.buildIconOrWidget("selected_icon")
              : segment.buildIconOrWidget("icon");
      var label = segment.buildTextOrWidget("label");
      if (icon != null && label != null) {
        return Row(mainAxisSize: MainAxisSize.min, children: [
          icon,
          const SizedBox(width: 6),
          label,
        ]);
      }
      return icon ?? label ?? ControlWidget(control: segment);
    }

    var buttons = segments.map((segment) {
      segment.notifyParent = true;
      var value = segment.getString("value")!;
      var isSelected = selected.contains(value);
      var onPressed = widget.control.disabled || segment.disabled
          ? null
          : () => toggle(segment);
      return isSelected
          ? CupertinoButton.filled(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              onPressed: onPressed,
              child: buildContent(segment, true),
            )
          : CupertinoButton.tinted(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              onPressed: onPressed,
              child: buildContent(segment, false),
            );
    }).toList();

    var direction = widget.control.getAxis("direction", Axis.horizontal)!;
    Widget segmented = direction == Axis.vertical
        ? Column(mainAxisSize: MainAxisSize.min, children: buttons)
        : Row(mainAxisSize: MainAxisSize.min, children: buttons);

    return LayoutControl(control: widget.control, child: segmented);
  }
}
