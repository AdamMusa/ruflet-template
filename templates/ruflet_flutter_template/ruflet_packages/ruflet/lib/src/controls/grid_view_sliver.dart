import 'package:flutter/widgets.dart';

import '../models/control.dart';
import '../utils/edge_insets.dart';
import '../utils/numbers.dart';
import 'scroll_slivers.dart';

/// The grid delegate of a Ruby GridView (`runs_count`/`max_extent`,
/// `spacing`, `run_spacing`, `child_aspect_ratio`).
SliverGridDelegate gridDelegateFor(Control control) {
  final runsCount = control.getInt("runs_count", 1)!;
  final maxExtent = control.getDouble("max_extent");
  final spacing = control.getDouble("spacing", 10)!;
  final runSpacing = control.getDouble("run_spacing", 10)!;
  final childAspectRatio = control.getDouble("child_aspect_ratio", 1)!;
  return maxExtent == null
      ? SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: runsCount,
          mainAxisSpacing: spacing,
          crossAxisSpacing: runSpacing,
          childAspectRatio: childAspectRatio)
      : SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: maxExtent,
          mainAxisSpacing: spacing,
          crossAxisSpacing: runSpacing,
          childAspectRatio: childAspectRatio);
}

/// The item sliver of a Ruby GridView, matching grid_view.dart's box path.
Widget gridViewSliver(
    BuildContext context, Control control, List<Control> items) {
  final horizontal = control.getBool("horizontal", false)!;
  final buildControlsOnDemand =
      control.getBool("build_controls_on_demand", true)!;
  final gridDelegate = gridDelegateFor(control);
  final Widget sliver = buildControlsOnDemand
      ? SliverGrid.builder(
          gridDelegate: gridDelegate,
          itemCount: items.length,
          itemBuilder: (context, index) => sliverItem(items[index]),
        )
      : SliverGrid(
          gridDelegate: gridDelegate,
          delegate: SliverChildListDelegate(items.map(sliverItem).toList()),
        );
  return paddedSliver(context, control.getPadding("padding"),
      horizontal ? Axis.horizontal : Axis.vertical, sliver);
}
