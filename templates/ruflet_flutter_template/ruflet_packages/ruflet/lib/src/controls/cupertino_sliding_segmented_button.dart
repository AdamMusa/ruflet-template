import 'package:flutter/cupertino.dart';

import '../extensions/control.dart';
import '../models/control.dart';
import '../utils/colors.dart';
import '../utils/edge_insets.dart';
import '../utils/numbers.dart';
import '../widgets/error.dart';
import 'base_controls.dart';
import 'control_widget.dart';

class CupertinoSlidingSegmentedButtonControl extends StatelessWidget {
  final Control control;

  const CupertinoSlidingSegmentedButtonControl(
      {super.key, required this.control});

  @override
  Widget build(BuildContext context) {
    debugPrint("CupertinoSlidingSegmentedButtonControl build: ${control.id}");

    // Ruby's canonical segmented_button(segments, selected:, sliding: true).
    final segments = control.children("segments");
    if (segments.isNotEmpty) return _segments(context, segments);

    var controls = control.buildWidgets("controls");
    if (controls.length < 2) {
      return const ErrorControl(
          "CupertinoSlidingSegmentedButton must have at minimum two visible controls");
    }

    return _sliding<int>(
      context,
      groupValue: control.getInt("selected_index", 0)!,
      children: controls.asMap().map((i, c) => MapEntry(i, c)),
      onValueChanged: (int? index) {
        if (!control.disabled) {
          index = index ?? 0;
          control.updateProperties({"selected_index": index}, notify: true);
          control.triggerEvent("change", index);
        }
      },
    );
  }

  /// `segments` keyed by their `value`, one of them `selected` at a time
  /// (the thumb). A pick is reported like the segmented control reports it:
  /// `selected` and `change` carry the list of selected values.
  Widget _segments(BuildContext context, List<Control> segments) {
    final visible = segments.where((segment) => segment.visible).toList();
    if (visible.length < 2) {
      return const ErrorControl(
          "SegmentedButton with sliding: true must have at minimum two visible segments");
    }
    final children = <String, Widget>{};
    final disabled = <String>{};
    for (final segment in visible) {
      segment.notifyParent = true;
      final value = segment.getString("value")!;
      children[value] = _segmentContent(segment);
      if (segment.disabled) disabled.add(value);
    }
    final selected = control
        .get<List>("selected", [])!
        .map((value) => value.toString())
        .where(children.containsKey);

    return _sliding<String>(
      context,
      groupValue: selected.isEmpty ? null : selected.first,
      children: children,
      disabledChildren: disabled,
      onValueChanged: (String? value) {
        if (control.disabled || value == null || disabled.contains(value)) {
          return;
        }
        control.updateProperties({
          "selected": [value]
        }, notify: true);
        control.triggerEvent("change", [value]);
      },
    );
  }

  Widget _segmentContent(Control segment) {
    final icon = segment.buildIconOrWidget("icon");
    final label = segment.buildTextOrWidget("label");
    if (icon != null && label != null) {
      return Row(mainAxisSize: MainAxisSize.min, children: [
        icon,
        const SizedBox(width: 6),
        label,
      ]);
    }
    return icon ?? label ?? ControlWidget(control: segment);
  }

  Widget _sliding<T extends Object>(
    BuildContext context, {
    required T? groupValue,
    required Map<T, Widget> children,
    required ValueChanged<T?> onValueChanged,
    Set<T> disabledChildren = const {},
  }) {
    final button = CupertinoSlidingSegmentedControl<T>(
      groupValue: groupValue,
      proportionalWidth: control.getBool("proportional_width", false)!,
      backgroundColor: control.getColor(
          "bgcolor", context, CupertinoColors.tertiarySystemFill)!,
      padding: control.getPadding(
          "padding", const EdgeInsets.symmetric(vertical: 2, horizontal: 3))!,
      thumbColor: control.getColor(
          "thumb_color",
          context,
          const CupertinoDynamicColor.withBrightness(
              color: Color(0xFFFFFFFF), darkColor: Color(0xFF636366)))!,
      disabledChildren: disabledChildren,
      children: children,
      onValueChanged: onValueChanged,
    );

    return LayoutControl(control: control, child: button);
  }
}
