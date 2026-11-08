import 'package:flutter/widgets.dart';

import '../models/control.dart';
import '../utils/enums.dart';
import '../utils/layout.dart';
import '../utils/misc.dart';
import '../utils/numbers.dart';
import '../widgets/error.dart';
import 'base_controls.dart';
import 'nested_scroll_body.dart';
import 'scroll_notification_control.dart';
import 'scrollable_control.dart';
import 'sliver_children.dart';

/// A scroll view composed of slivers (lists, grids, sticky section headers,
/// boxes and a filler) that all scroll as one, like Flutter's
/// [CustomScrollView]. Design neutral: Cupertino and Material only differ in
/// the platform scroll physics and in the slivers that have a design language.
class CustomScrollViewControl extends StatefulWidget {
  final Control control;

  CustomScrollViewControl({Key? key, required this.control})
      : super(key: key ?? ValueKey("control_${control.id}"));

  @override
  State<CustomScrollViewControl> createState() =>
      _CustomScrollViewControlState();
}

class _CustomScrollViewControlState extends State<CustomScrollViewControl> {
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
    final control = widget.control;
    debugPrint("CustomScrollViewControl build: ${control.id}");

    final horizontal = control.getBool("horizontal", false)!;
    final axis = horizontal ? Axis.horizontal : Axis.vertical;
    final reverse = control.getBool("reverse", false)!;
    final anchor = control.getDouble("anchor", 0)!;
    final cacheExtent = control.getDouble("cache_extent");
    final semanticChildCount = control.getInt("semantic_child_count");
    final clipBehavior =
        parseClip(control.getString("clip_behavior"), Clip.hardEdge)!;
    final keyboardDismissBehavior = parseEnum(
        ScrollViewKeyboardDismissBehavior.values,
        control.getString("keyboard_dismiss_behavior")?.replaceAll("_", ""),
        ScrollViewKeyboardDismissBehavior.manual)!;
    // `slivers:` from the DSL; block children arrive in `controls`.
    final slivers = control.get("slivers") != null
        ? control.children("slivers")
        : control.children("controls");

    final view = LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        if (horizontal &&
            constraints.maxHeight == double.infinity &&
            control.getDouble("height") == null &&
            control.getExpand("expand", 0)! <= 0) {
          return const ErrorControl(
              "Error displaying CustomScrollViewControl: height is unbounded.",
              description:
                  "Set a fixed height, a non-zero expand, or place inside "
                  "a control with bounded height.");
        }

        final shrinkWrap = horizontal
            ? constraints.maxWidth == double.infinity
            : constraints.maxHeight == double.infinity;
        final host = SliverHost(axis: axis, shrinkWrap: shrinkWrap);
        // A NestedScrollView body scrolls with its inner controller and
        // starts after the pinned header's overlap.
        final nested = NestedScrollBody.of(context, control);
        final controller = nested?.controller ?? _controller;
        final overlap = nested?.handle;

        Widget child = CustomScrollView(
          key: nested == null
              ? null
              : PageStorageKey("nested_body_${control.id}"),
          controller: controller,
          scrollDirection: axis,
          reverse: reverse,
          anchor: anchor,
          cacheExtent: cacheExtent,
          clipBehavior: clipBehavior,
          keyboardDismissBehavior: keyboardDismissBehavior,
          semanticChildCount: semanticChildCount,
          shrinkWrap: shrinkWrap,
          slivers: [
            if (overlap != null) SliverOverlapInjector(handle: overlap),
            for (final sliver in slivers) ...buildSlivers(sliver, host)
          ],
        );

        // Same controller as the view: `scroll`, `auto_scroll` and the
        // `scroll_to` invoke behave exactly as on ListView.
        child = ScrollableControl(
            control: control,
            scrollDirection: axis,
            scrollController: controller,
            child: child);

        if (control.getBool("on_scroll", false)!) {
          child = ScrollNotificationControl(control: control, child: child);
        }

        return child;
      },
    );

    return LayoutControl(control: control, child: view);
  }
}
