import 'package:flutter/widgets.dart';

import '../extensions/control.dart';
import '../models/control.dart';
import '../utils/edge_insets.dart';
import '../utils/keys.dart';
import '../utils/layout.dart';
import '../utils/misc.dart';
import '../utils/numbers.dart';
import '../widgets/error.dart';
import 'adaptive_refresh_scroll_view.dart';
import 'animated_children.dart';
import 'base_controls.dart';
import 'end_reached_listener.dart';
import 'control_widget.dart';
import 'list_view_sliver.dart';
import 'nested_scroll_body.dart';
import 'scroll_notification_control.dart';
import 'scrollable_control.dart';

class ListViewControl extends StatefulWidget {
  final Control control;

  ListViewControl({Key? key, required this.control})
      : super(key: key ?? ValueKey("control_${control.id}"));

  @override
  State<ListViewControl> createState() => _ListViewControlState();
}

class _ListViewControlState extends State<ListViewControl>
    with TickerProviderStateMixin {
  late final ScrollController _controller;
  AnimatedChildren? _animated;

  @override
  void initState() {
    super.initState();
    _controller = ScrollController();
  }

  @override
  void dispose() {
    _animated?.dispose();
    _controller.dispose();
    super.dispose();
  }

  /// `animate_changes`: the items to show, including removed ones that are
  /// still animating out; null when the list does not animate.
  List<AnimatedChildEntry>? _syncAnimatedChildren(List<Control> controls) {
    if (!widget.control.getBool("animate_changes", false)!) {
      _animated?.dispose();
      _animated = null;
      return null;
    }
    _animated ??= AnimatedChildren(
        vsync: this,
        onChanged: () {
          if (mounted) setState(() {});
        });
    return _animated!.sync(controls, ItemAnimation.of(widget.control));
  }

  @override
  Widget build(BuildContext context) {
    debugPrint("ListViewControl build: ${widget.control.id}");
    var horizontal = widget.control.getBool("horizontal", false)!;
    var spacing = widget.control.getDouble("spacing", 0)!;
    var dividerThickness = widget.control.getDouble("divider_thickness", 0)!;
    var itemExtent = widget.control.getDouble("item_extent");
    var cacheExtent = widget.control.getDouble("cache_extent");
    var semanticChildCount = widget.control.getInt("semantic_child_count");
    var padding = widget.control.getPadding("padding");
    var reverse = widget.control.getBool("reverse", false)!;
    var clipBehavior =
        parseClip(widget.control.getString("clip_behavior"), Clip.hardEdge)!;
    final keyboardDismissBehavior =
        widget.control.getKeyboardDismissBehavior("keyboard_dismiss_behavior");
    var scrollDirection = horizontal ? Axis.horizontal : Axis.vertical;
    var buildControlsOnDemand =
        widget.control.getBool("build_controls_on_demand", true)!;
    var firstItemPrototype =
        widget.control.getBool("first_item_prototype", false)!;
    var controls = widget.control.children("controls");
    final animated = _syncAnimatedChildren(controls);
    if (animated != null) {
      controls = [for (final entry in animated) entry.control];
    }
    Widget item(int index) {
      final control = controls[index];
      final child = ControlWidget(
        key: ValueKey(control.getKey("key")?.value ?? control.id),
        control: control,
      );
      return animated == null
          ? child
          : animated[index].transition(scrollDirection, child);
    }

    var prototypeItem = widget.control.buildWidget("prototype_item") ??
        (firstItemPrototype && controls.isNotEmpty
            ? ControlWidget(control: controls.first)
            : null);

    Widget separator() => listSeparator(
        horizontal: horizontal,
        spacing: spacing,
        dividerThickness: dividerThickness);

    final onRefresh = widget.control.getBool("on_refresh", false)!;
    final refreshable = onRefresh && !horizontal && !reverse;
    if (onRefresh && !refreshable) {
      debugPrint("ListView ${widget.control.id}: on_refresh is ignored on "
          "horizontal or reversed lists");
    }

    Widget listView = LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        debugPrint("ListView constraints.maxWidth: ${constraints.maxWidth}");
        debugPrint("ListView constraints.maxHeight: ${constraints.maxHeight}");

        var shrinkWrap =
            (!horizontal && constraints.maxHeight == double.infinity) ||
                (horizontal && constraints.maxWidth == double.infinity);
        // A NestedScrollView body list scrolls with its inner controller and
        // starts after the pinned header's overlap, so it is built from
        // slivers like the refreshable list.
        final nested = NestedScrollBody.of(context, widget.control);
        if (refreshable || nested != null) {
          final controller = nested?.controller ?? _controller;
          final handle = nested?.handle;
          final slivers = [
            if (handle != null) SliverOverlapInjector(handle: handle),
            listViewSliver(context, widget.control, controls, prototypeItem,
                itemBuilder: item)
          ];
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
        Widget child = !buildControlsOnDemand
            ? ListView(
                controller: _controller,
                cacheExtent: cacheExtent,
                reverse: reverse,
                clipBehavior: clipBehavior,
                keyboardDismissBehavior: keyboardDismissBehavior,
                scrollDirection: scrollDirection,
                shrinkWrap: shrinkWrap,
                padding: padding,
                semanticChildCount: semanticChildCount,
                itemExtent: spacing > 0 ? null : itemExtent,
                prototypeItem: spacing > 0 ? null : prototypeItem,
                children: () {
                  final childWidgets = <Widget>[];
                  for (var index = 0; index < controls.length; index++) {
                    childWidgets.add(item(index));
                    if (spacing > 0 && index < controls.length - 1) {
                      childWidgets.add(separator());
                    }
                  }
                  return childWidgets;
                }(),
              )
            : spacing > 0
                ? ListView.separated(
                    controller: _controller,
                    cacheExtent: cacheExtent,
                    reverse: reverse,
                    clipBehavior: clipBehavior,
                    keyboardDismissBehavior: keyboardDismissBehavior,
                    scrollDirection: scrollDirection,
                    shrinkWrap: shrinkWrap,
                    padding: padding,
                    itemCount: controls.length,
                    itemBuilder: (context, index) => item(index),
                    separatorBuilder: (context, index) {
                      return separator();
                    },
                  )
                : ListView.builder(
                    controller: _controller,
                    clipBehavior: clipBehavior,
                    keyboardDismissBehavior: keyboardDismissBehavior,
                    semanticChildCount: semanticChildCount,
                    reverse: reverse,
                    cacheExtent: cacheExtent,
                    scrollDirection: scrollDirection,
                    shrinkWrap: shrinkWrap,
                    padding: padding,
                    itemCount: controls.length,
                    itemExtent: itemExtent,
                    itemBuilder: (context, index) => item(index),
                    prototypeItem: prototypeItem,
                  );

        if (horizontal &&
            constraints.maxHeight == double.infinity &&
            widget.control.getDouble("height") == null &&
            widget.control.getExpand("expand", 0)! <= 0) {
          return const ErrorControl(
              "Error displaying ListViewControl: height is unbounded.",
              description:
                  "Set a fixed height, a non-zero expand, or place inside "
                  "a control with bounded height.");
        }

        return _scrollable(child, scrollDirection, _controller);
      },
    );

    return LayoutControl(control: widget.control, child: listView);
  }

  /// Ruby scroll features shared by the box list and the refreshable list:
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
