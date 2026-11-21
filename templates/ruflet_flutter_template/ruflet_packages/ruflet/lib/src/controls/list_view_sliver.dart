import 'package:flutter/widgets.dart';

import '../models/control.dart';
import '../utils/edge_insets.dart';
import '../utils/numbers.dart';
import 'scroll_slivers.dart';

/// The separator a Ruby ListView draws between items when `spacing > 0`.
Widget listSeparator(
    {required bool horizontal,
    required double spacing,
    required double dividerThickness}) {
  if (dividerThickness == 0) {
    return SizedBox(
        width: horizontal ? spacing : null,
        height: horizontal ? null : spacing);
  }
  return SizedBox(
    width: horizontal ? spacing : dividerThickness,
    height: horizontal ? dividerThickness : spacing,
    child: Center(
      child: SizedBox(
        width: horizontal ? dividerThickness : double.infinity,
        height: horizontal ? double.infinity : dividerThickness,
        child: const ColoredBox(color: Color(0x1F000000)),
      ),
    ),
  );
}

/// The item sliver of a Ruby ListView (`spacing`, `divider_thickness`,
/// `item_extent`, `prototype_item`/`first_item_prototype`,
/// `build_controls_on_demand`, `padding`), matching list_view.dart's box path.
Widget listViewSliver(BuildContext context, Control control,
    List<Control> items, Widget? prototypeItem,
    {Widget Function(int index)? itemBuilder}) {
  final horizontal = control.getBool("horizontal", false)!;
  final spacing = control.getDouble("spacing", 0)!;
  final dividerThickness = control.getDouble("divider_thickness", 0)!;
  final itemExtent = control.getDouble("item_extent");
  final buildControlsOnDemand =
      control.getBool("build_controls_on_demand", true)!;
  Widget separator() => listSeparator(
      horizontal: horizontal,
      spacing: spacing,
      dividerThickness: dividerThickness);
  Widget item(int index) =>
      itemBuilder?.call(index) ?? sliverItem(items[index]);

  Widget layout(
      SliverChildDelegate delegate, double? extent, Widget? prototype) {
    if (extent != null) {
      return SliverFixedExtentList(delegate: delegate, itemExtent: extent);
    }
    if (prototype != null) {
      return SliverPrototypeExtentList(
          delegate: delegate, prototypeItem: prototype);
    }
    return SliverList(delegate: delegate);
  }

  Widget sliver;
  if (!buildControlsOnDemand) {
    final children = <Widget>[];
    for (var index = 0; index < items.length; index++) {
      children.add(item(index));
      if (spacing > 0 && index < items.length - 1) children.add(separator());
    }
    sliver = layout(SliverChildListDelegate(children),
        spacing > 0 ? null : itemExtent, spacing > 0 ? null : prototypeItem);
  } else if (spacing > 0) {
    sliver = SliverList.separated(
      itemCount: items.length,
      itemBuilder: (context, index) => item(index),
      separatorBuilder: (context, index) => separator(),
    );
  } else {
    sliver = layout(
        SliverChildBuilderDelegate((context, index) => item(index),
            childCount: items.length),
        itemExtent,
        prototypeItem);
  }
  return paddedSliver(context, control.getPadding("padding"),
      horizontal ? Axis.horizontal : Axis.vertical, sliver);
}
