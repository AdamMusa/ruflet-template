import 'package:flutter/widgets.dart';

import '../controls/control_widget.dart';
import '../models/control.dart';
import '../utils/edge_insets.dart';
import '../utils/keys.dart';
import '../utils/layout.dart';
import '../utils/misc.dart';
import '../utils/numbers.dart';
import '../widgets/error.dart';
import 'adaptive_refresh_scroll_view.dart';
import 'base_controls.dart';
import 'end_reached_listener.dart';
import 'grid_view_sliver.dart';
import 'nested_scroll_body.dart';
import 'scroll_notification_control.dart';
import 'scrollable_control.dart';

class GridViewControl extends StatefulWidget {
  final Control control;

  GridViewControl({Key? key, required this.control})
      : super(key: key ?? ValueKey("control_${control.id}"));

  @override
  State<GridViewControl> createState() => _GridViewControlState();
}

class _GridViewControlState extends State<GridViewControl> {
  late final ScrollController _controller;

  @override
  void initState() {
    super.initState();
    _controller = ScrollController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    debugPrint("GridViewControl build: ${widget.control.id}");

    final horizontal = widget.control.getBool("horizontal", false)!;
    final semanticChildCount = widget.control.getInt("semantic_child_count");
    final padding = widget.control.getPadding("padding");
    final reverse = widget.control.getBool("reverse", false)!;
    final cacheExtent = widget.control.getDouble("cache_extent");
    final controls = widget.control.children("controls");

    var clipBehavior =
        widget.control.getClipBehavior("clip_behavior", Clip.hardEdge)!;
    final keyboardDismissBehavior =
        widget.control.getKeyboardDismissBehavior("keyboard_dismiss_behavior");

    final onRefresh = widget.control.getBool("on_refresh", false)!;
    final refreshable = onRefresh && !horizontal && !reverse;
    if (onRefresh && !refreshable) {
      debugPrint("GridView ${widget.control.id}: on_refresh is ignored on "
          "horizontal or reversed grids");
    }

    var gridView = LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        // debugPrint("GridView constraints.maxWidth: ${constraints.maxWidth}");
        // debugPrint("GridView constraints.maxHeight: ${constraints.maxHeight}");

        var shrinkWrap =
            (!horizontal && constraints.maxHeight == double.infinity) ||
                (horizontal && constraints.maxWidth == double.infinity);

        // A NestedScrollView body grid scrolls with its inner controller and
        // starts after the pinned header's overlap, so it is built from
        // slivers like the refreshable grid.
        final nested = NestedScrollBody.of(context, widget.control);
        if (refreshable || nested != null) {
          final controller = nested?.controller ?? _controller;
          final handle = nested?.handle;
          final slivers = [
            if (handle != null) SliverOverlapInjector(handle: handle),
            gridViewSliver(context, widget.control, controls)
          ];
          final scrollDirection = horizontal ? Axis.horizontal : Axis.vertical;
          return _scrollable(
              refreshable
                  ? AdaptiveRefreshScrollView(
                      control: widget.control,
                      controller: controller,
                      shrinkWrap: shrinkWrap,
                      cacheExtent: cacheExtent,
                      clipBehavior: clipBehavior,
                      keyboardDismissBehavior: keyboardDismissBehavior,
                      semanticChildCount: semanticChildCount ?? controls.length,
                      slivers: slivers,
                    )
                  : CustomScrollView(
                      key: PageStorageKey("nested_body_${widget.control.id}"),
                      controller: controller,
                      scrollDirection: scrollDirection,
                      reverse: reverse,
                      shrinkWrap: shrinkWrap,
                      cacheExtent: cacheExtent,
                      clipBehavior: clipBehavior,
                      keyboardDismissBehavior: keyboardDismissBehavior,
                      semanticChildCount: semanticChildCount ?? controls.length,
                      slivers: slivers,
                    ),
              scrollDirection,
              controller);
        }

        var gridDelegate = gridDelegateFor(widget.control);

        var buildControlsOnDemand =
            widget.control.getBool("build_controls_on_demand", true)!;
        Widget child = !buildControlsOnDemand
            ? GridView(
                scrollDirection: horizontal ? Axis.horizontal : Axis.vertical,
                controller: _controller,
                clipBehavior: clipBehavior,
                keyboardDismissBehavior: keyboardDismissBehavior,
                reverse: reverse,
                cacheExtent: cacheExtent,
                semanticChildCount: semanticChildCount,
                shrinkWrap: shrinkWrap,
                padding: padding,
                gridDelegate: gridDelegate,
                children: controls
                    .map((item) => ControlWidget(
                          key: ValueKey(item.getKey("key")?.value ?? item.id),
                          control: item,
                        ))
                    .toList(),
              )
            : GridView.builder(
                scrollDirection: horizontal ? Axis.horizontal : Axis.vertical,
                controller: _controller,
                clipBehavior: clipBehavior,
                keyboardDismissBehavior: keyboardDismissBehavior,
                reverse: reverse,
                cacheExtent: cacheExtent,
                semanticChildCount: semanticChildCount,
                shrinkWrap: shrinkWrap,
                padding: padding,
                gridDelegate: gridDelegate,
                itemCount: controls.length,
                itemBuilder: (context, index) {
                  return ControlWidget(
                    key: ValueKey(controls[index].getKey("key")?.value ??
                        controls[index].id),
                    control: controls[index],
                  );
                },
              );

        if (horizontal &&
            constraints.maxHeight == double.infinity &&
            widget.control.getDouble("height") == null &&
            widget.control.getExpand("expand", 0)! <= 0) {
          return const ErrorControl(
              "Error displaying GridViewControl: height is unbounded.",
              description:
                  "Set a fixed height, a non-zero expand, or place inside "
                  "a control with bounded height.");
        }

        return _scrollable(
            child, horizontal ? Axis.horizontal : Axis.vertical, _controller);
      },
    );

    return LayoutControl(control: widget.control, child: gridView);
  }

  /// Ruby scroll features shared by the box grid and the refreshable grid:
  /// `scroll`/`auto_scroll`/`scroll_to` (same controller) and `on_scroll`.
  Widget _scrollable(
      Widget child, Axis scrollDirection, ScrollController controller) {
    child = ScrollableControl(
        control: widget.control,
        scrollDirection: scrollDirection,
        scrollController: controller,
        child: child);

    if (widget.control.getBool("on_scroll", false)!) {
      child = ScrollNotificationControl(control: widget.control, child: child);
    }

    if (widget.control.getBool("on_end_reached", false)!) {
      child = EndReachedListener(control: widget.control, child: child);
    }

    return child;
  }
}
