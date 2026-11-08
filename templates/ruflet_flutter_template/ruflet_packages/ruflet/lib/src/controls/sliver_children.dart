import 'package:flutter/widgets.dart';

import '../extensions/control.dart';
import '../models/control.dart';
import '../models/control_type.dart';
import '../utils/colors.dart';
import '../utils/edge_insets.dart';
import '../utils/keys.dart';
import '../utils/numbers.dart';
import '../widgets/control_inherited_notifier.dart';
import 'adaptive_sliver_app_bar.dart';
import 'control_widget.dart';
import 'sliver_app_bar_spec.dart';

/// Wire types a CustomScrollView builds as slivers itself.
///
/// They are intentionally absent from `createWidget` (like DataRow or
/// Segment): a sliver cannot render inside a box, so the parent consumes them
/// through `control.children("slivers")`.
const Set<String> sliverChildTypes = {
  "SliverFillRemaining",
  "SliverGrid",
  "SliverList",
  "SliverPadding",
  "SliverToBoxAdapter",
  sliverAppBarType,
};

/// Layout facts a sliver needs from the CustomScrollView that hosts it.
class SliverHost {
  final Axis axis;

  /// True when the scroll view sizes itself to its content (unbounded main
  /// axis), where "the remaining viewport space" does not exist.
  final bool shrinkWrap;

  const SliverHost({required this.axis, required this.shrinkWrap});
}

Key _keyOf(Control control) =>
    ValueKey(control.getKey("key")?.value ?? control.id);

/// Builds the slivers for one entry of a CustomScrollView's `slivers`.
///
/// Sliver child types become slivers that rebuild on their own Ruby patches;
/// any other control is a box and scrolls as a single [SliverToBoxAdapter].
/// A SliverAppBar is followed by its (iOS only) flexible space sliver, which
/// must be a sibling so the navigation bar stays pinned past it.
Iterable<Widget> buildSlivers(Control child, SliverHost host) sync* {
  if (!sliverChildTypes.contains(child.canonicalType)) {
    yield SliverToBoxAdapter(
        key: _keyOf(child), child: ControlWidget(control: child));
    return;
  }
  yield SliverChildControl(key: _keyOf(child), control: child, host: host);
  if (child.canonicalType == sliverAppBarType) {
    yield SliverAppBarFlexibleSpace(
        key: ValueKey("flexible_space_${child.id}"), control: child);
  }
}

class SliverChildControl extends StatelessWidget {
  final Control control;
  final SliverHost host;

  const SliverChildControl(
      {super.key, required this.control, required this.host});

  @override
  Widget build(BuildContext context) {
    // Same reactive context as ControlWidget, so a Ruby patch to this sliver
    // (new items, header, spacing) rebuilds only this sliver.
    return control.buildInControlContext((context) {
      debugPrint("${control.type} build: ${control.id}");
      switch (control.canonicalType) {
        case "SliverList":
          return _section(context, control, _list(control, host));
        case "SliverGrid":
          return _section(context, control, _grid(control));
        case "SliverFillRemaining":
          return _fillRemaining(control, host);
        case "SliverPadding":
          return _paddingGroup(control, host);
        case sliverAppBarType:
          return AdaptiveSliverAppBarControl(control: control);
        default:
          return _boxAdapter(control);
      }
    });
  }
}

Widget _item(Control item) => ControlWidget(key: _keyOf(item), control: item);

/// A Ruby `sliver_padding`: `padding` around its slivers (`slivers:`, or block
/// children in `controls`), which scroll as one group. Each child is built
/// like a CustomScrollView entry, so a box among them scrolls as a box and a
/// SliverAppBar keeps its flexible space sibling.
Widget _paddingGroup(Control control, SliverHost host) {
  final slivers = control.get("slivers") != null
      ? control.children("slivers")
      : control.children("controls");
  return SliverPadding(
    padding: control.getPadding("padding") ?? EdgeInsets.zero,
    sliver: SliverMainAxisGroup(slivers: [
      for (final sliver in slivers) ...buildSlivers(sliver, host),
    ]),
  );
}

Widget _padded(Control sliver, Widget body) {
  final padding = sliver.getPadding("padding");
  return padding == null ? body : SliverPadding(padding: padding, sliver: body);
}

/// Optional (sticky) section header and background around a list or grid.
///
/// A [PinnedHeaderSliver] inside a [SliverMainAxisGroup] stays at the top
/// while its group's items scroll under it and leaves with the group, which is
/// the iOS Contacts / Mail section header behavior.
Widget _section(BuildContext context, Control sliver, Widget items) {
  Widget section = _padded(sliver, items);
  final header = sliver.buildWidget("header");
  if (header != null) {
    section = SliverMainAxisGroup(slivers: [
      sliver.getBool("sticky_header", false)!
          ? PinnedHeaderSliver(child: header)
          : SliverToBoxAdapter(child: header),
      section,
    ]);
  }
  final bgcolor = sliver.getColor("bgcolor", context);
  if (bgcolor != null) {
    section = DecoratedSliver(
        decoration: BoxDecoration(color: bgcolor), sliver: section);
  }
  return section;
}

/// Mirrors ListView's item, spacing and divider rules (list_view.dart).
Widget _list(Control sliver, SliverHost host) {
  final horizontal = host.axis == Axis.horizontal;
  final items = sliver.children("controls");
  final spacing = sliver.getDouble("spacing", 0)!;
  final dividerThickness = sliver.getDouble("divider_thickness", 0)!;
  final itemExtent = sliver.getDouble("item_extent");

  Widget separator() {
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

  if (!sliver.getBool("build_controls_on_demand", true)!) {
    final children = <Widget>[];
    for (var index = 0; index < items.length; index++) {
      children.add(_item(items[index]));
      if (spacing > 0 && index < items.length - 1) {
        children.add(separator());
      }
    }
    return itemExtent != null && spacing <= 0
        ? SliverFixedExtentList.list(itemExtent: itemExtent, children: children)
        : SliverList.list(children: children);
  }
  if (spacing > 0) {
    return SliverList.separated(
      itemCount: items.length,
      itemBuilder: (context, index) => _item(items[index]),
      separatorBuilder: (context, index) => separator(),
    );
  }
  if (itemExtent != null) {
    return SliverFixedExtentList.builder(
      itemExtent: itemExtent,
      itemCount: items.length,
      itemBuilder: (context, index) => _item(items[index]),
    );
  }
  return SliverList.builder(
    itemCount: items.length,
    itemBuilder: (context, index) => _item(items[index]),
  );
}

/// Mirrors GridView's delegate and defaults (grid_view.dart).
Widget _grid(Control sliver) {
  final items = sliver.children("controls");
  final maxExtent = sliver.getDouble("max_extent");
  final spacing = sliver.getDouble("spacing", 10)!;
  final runSpacing = sliver.getDouble("run_spacing", 10)!;
  final childAspectRatio = sliver.getDouble("child_aspect_ratio", 1)!;
  final gridDelegate = maxExtent == null
      ? SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: sliver.getInt("runs_count", 1)!,
          mainAxisSpacing: spacing,
          crossAxisSpacing: runSpacing,
          childAspectRatio: childAspectRatio)
      : SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: maxExtent,
          mainAxisSpacing: spacing,
          crossAxisSpacing: runSpacing,
          childAspectRatio: childAspectRatio);
  return SliverGrid.builder(
    gridDelegate: gridDelegate,
    itemCount: items.length,
    itemBuilder: (context, index) => _item(items[index]),
  );
}

Widget _boxAdapter(Control sliver) =>
    SliverToBoxAdapter(child: sliver.buildWidget("content"));

Widget _fillRemaining(Control sliver, SliverHost host) {
  final content = sliver.buildWidget("content");
  if (host.shrinkWrap) {
    // A shrink-wrapping viewport has no remaining extent to fill.
    return SliverToBoxAdapter(child: content);
  }
  return SliverFillRemaining(
    // Ruflet default: arbitrary box content, not a nested scrollable.
    hasScrollBody: sliver.getBool("has_scroll_body", false)!,
    fillOverscroll: sliver.getBool("fill_overscroll", false)!,
    child: content,
  );
}
