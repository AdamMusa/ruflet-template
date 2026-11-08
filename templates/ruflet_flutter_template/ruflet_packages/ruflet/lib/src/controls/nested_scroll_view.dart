import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../models/control.dart';
import '../models/control_type.dart';
import '../utils/misc.dart';
import '../utils/numbers.dart';
import '../widgets/error.dart';
import 'base_controls.dart';
import 'control_widget.dart';
import 'nested_scroll_body.dart';
import 'scroll_notification_control.dart';
import 'scrollable_control.dart';
import 'sliver_children.dart';

/// Header slivers that collapse above a scrolling body, like Flutter's
/// [NestedScrollView]: the "collapsing app bar over tabs" layout.
///
/// The header slivers are built exactly like a CustomScrollView's
/// ([buildSlivers]), so a SliverAppBar keeps its iOS flexible space sibling.
/// They sit in one [SliverOverlapAbsorber]; the body's scroll views (the body
/// itself, or each TabBarView page) scroll with the inner controller and
/// inject the absorbed overlap ([NestedScrollBody]), so a pinned app bar never
/// hides the first rows. Any other body is laid out below the pinned header.
///
/// Design neutral: the designs only differ in scroll physics and in the
/// slivers and body controls, which render themselves.
class NestedScrollViewControl extends StatefulWidget {
  final Control control;

  NestedScrollViewControl({Key? key, required this.control})
      : super(key: key ?? ValueKey("control_${control.id}"));

  @override
  State<NestedScrollViewControl> createState() =>
      _NestedScrollViewControlState();
}

class _NestedScrollViewControlState extends State<NestedScrollViewControl> {
  /// The outer (header) scroll: `scroll`, `auto_scroll`, `scroll_to`.
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
    debugPrint("NestedScrollViewControl build: ${control.id}");

    final horizontal = control.getBool("horizontal", false)!;
    final axis = horizontal ? Axis.horizontal : Axis.vertical;
    final reverse = control.getBool("reverse", false)!;
    final floatHeaderSlivers = control.getBool("float_header_slivers", false)!;
    final clipBehavior =
        parseClip(control.getString("clip_behavior"), Clip.hardEdge)!;
    // `header_slivers:` from the DSL; block children arrive in `controls`.
    final headers = control.get("header_slivers") != null
        ? control.children("header_slivers")
        : control.children("controls");
    final body = control.child("body");

    final view = LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final unbounded = horizontal
            ? constraints.maxWidth == double.infinity
            : constraints.maxHeight == double.infinity;
        if (unbounded) {
          return ErrorControl(
              "Error displaying NestedScrollViewControl: "
              "${horizontal ? "width" : "height"} is unbounded.",
              description: "Set a fixed ${horizontal ? "width" : "height"}, "
                  "a non-zero expand, or place inside a control with bounded "
                  "${horizontal ? "width" : "height"}.");
        }
        final host = SliverHost(axis: axis, shrinkWrap: false);

        Widget child = NestedScrollView(
          controller: _controller,
          scrollDirection: axis,
          reverse: reverse,
          floatHeaderSlivers: floatHeaderSlivers,
          clipBehavior: clipBehavior,
          headerSliverBuilder: (context, innerBoxIsScrolled) => [
            SliverOverlapAbsorber(
              handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
              sliver: _HeaderSlivers(slivers: [
                for (final header in headers) ...buildSlivers(header, host),
              ]),
            ),
          ],
          body: Builder(
              builder: (context) =>
                  _NestedBody(control: body, axis: axis, reverse: reverse)),
        );

        // `scroll_to`, `scroll` and `auto_scroll` move the outer position,
        // which the NestedScrollView treats as the whole scroll: offset 0
        // expands the header and returns the body scroll views to the top.
        child = ScrollableControl(
            control: control,
            scrollDirection: axis,
            scrollController: _controller,
            child: child);

        if (control.getBool("on_scroll", false)!) {
          // Depth 0 is the outer scroll: the header collapsing or expanding.
          child = ScrollNotificationControl(control: control, child: child);
        }

        return child;
      },
    );

    return LayoutControl(control: control, child: view);
  }
}

/// The NestedScrollView body: the Ruby `body` control and the
/// [NestedScrollBody] scope its scroll views read.
class _NestedBody extends StatelessWidget {
  final Control? control;
  final Axis axis;
  final bool reverse;

  const _NestedBody(
      {required this.control, required this.axis, required this.reverse});

  @override
  Widget build(BuildContext context) {
    final body = control;
    if (body == null) {
      return const ErrorControl(
          "NestedScrollView.body must be provided and visible");
    }
    final handle = NestedScrollView.sliverOverlapAbsorberHandleFor(context);
    final pages = body.canonicalType == "TabBarView"
        ? body.children("controls")
        : const <Control>[];
    final scrollables = <int>{
      if (_scrollsAlong(body, axis))
        body.id
      else
        for (final page in pages)
          if (_scrollsAlong(page, axis)) page.id,
    };
    // The scroll views inject the overlap when they cover the whole body;
    // otherwise the body as a whole starts below the pinned header.
    final injected = _scrollsAlong(body, axis) ||
        (pages.isNotEmpty && pages.every((page) => _scrollsAlong(page, axis)));

    Widget child = ControlWidget(control: body);
    if (!injected) {
      child = _BelowHeader(handle: handle, axis: axis, child: child);
    }
    child = NestedScrollBody(
      handle: injected ? handle : null,
      controller: PrimaryScrollController.of(context),
      scrollables: scrollables,
      child: child,
    );
    // The header owns the leading edge (and its safe area padding, which a
    // primary SliverAppBar already includes): a body list must not pad by it
    // again below the pinned header.
    final mediaQuery = MediaQuery.maybeOf(context);
    if (mediaQuery == null) return child;
    final vertical = axis == Axis.vertical;
    return MediaQuery(
      data: mediaQuery.removePadding(
        removeTop: vertical && !reverse,
        removeBottom: vertical && reverse,
        removeLeft: !vertical && !reverse,
        removeRight: !vertical && reverse,
      ),
      child: child,
    );
  }
}

/// Whether [control] renders as a scroll view along [axis] that can scroll
/// with a NestedScrollView (ListView, GridView, CustomScrollView, or a
/// Column/Row with `scroll`). A refreshable Column keeps its own scroll view.
bool _scrollsAlong(Control control, Axis axis) {
  final horizontal = axis == Axis.horizontal;
  switch (control.canonicalType) {
    case "ListView":
    case "GridView":
    case "CustomScrollView":
      return control.getBool("horizontal", false)! == horizontal;
    case "Column":
    case "Row":
      final flowsAlong = (control.canonicalType == "Row") == horizontal;
      return flowsAlong &&
          !control.getBool("wrap", false)! &&
          !control.getBool("on_refresh", false)! &&
          control.getScrollMode("scroll", ScrollMode.none) != ScrollMode.none;
    default:
      return false;
  }
}

/// A body that is not one of the scroll views, laid out below the pinned
/// header: a non-scrolling viewport whose [SliverOverlapInjector] takes the
/// absorbed overlap and whose remaining extent is the body's box.
class _BelowHeader extends StatelessWidget {
  final SliverOverlapAbsorberHandle handle;
  final Axis axis;
  final Widget child;

  const _BelowHeader(
      {required this.handle, required this.axis, required this.child});

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      scrollDirection: axis,
      primary: false,
      physics: const NeverScrollableScrollPhysics(),
      slivers: [
        SliverOverlapInjector(handle: handle),
        SliverFillRemaining(child: child),
      ],
    );
  }
}

/// The header slivers as one sliver for the [SliverOverlapAbsorber], which
/// takes a single child.
///
/// A [SliverMainAxisGroup] lays them out in sequence (pinned ones stacking)
/// but reports no scroll obstruction, so the absorber would absorb nothing;
/// this group reports the sum of its slivers' obstructions (the pinned
/// extent). The NestedScrollView never scrolls the header past that pinned
/// extent, so the group never pushes its pinned slivers out.
class _HeaderSlivers extends MultiChildRenderObjectWidget {
  const _HeaderSlivers({required List<Widget> slivers})
      : super(children: slivers);

  @override
  RenderSliverMainAxisGroup createRenderObject(BuildContext context) =>
      _RenderHeaderSlivers();
}

class _RenderHeaderSlivers extends RenderSliverMainAxisGroup {
  @override
  void performLayout() {
    super.performLayout();
    final geometry = this.geometry!;
    if (geometry.scrollOffsetCorrection != null) return;
    var obstruction = 0.0;
    for (var child = firstChild; child != null; child = childAfter(child)) {
      obstruction += child.geometry!.maxScrollObstructionExtent;
    }
    this.geometry = geometry.copyWith(maxScrollObstructionExtent: obstruction);
  }
}
