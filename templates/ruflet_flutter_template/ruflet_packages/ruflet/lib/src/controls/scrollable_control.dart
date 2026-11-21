import 'package:flutter/widgets.dart';

import '../models/control.dart';
import '../utils/animations.dart';
import '../utils/keys.dart';
import '../utils/misc.dart';
import '../utils/numbers.dart';
import '../utils/time.dart';
import '../widgets/platform_design.dart';
import '../widgets/platform_scrollbar.dart';
import 'nested_scroll_body.dart';
import 'scroll_notification_control.dart';

class ScrollableControl extends StatefulWidget {
  final Control control;
  final Widget child;
  final Axis scrollDirection;
  final ScrollController? scrollController;
  final bool wrapIntoScrollableView;

  ScrollableControl(
      {Key? key,
      required this.control,
      required this.child,
      required this.scrollDirection,
      this.scrollController,
      this.wrapIntoScrollableView = false})
      : super(key: key ?? ValueKey("control_${control.id}"));

  @override
  State<ScrollableControl> createState() => _ScrollableControlState();
}

class _ScrollableControlState extends State<ScrollableControl> {
  ScrollController? _ownController;

  /// The controller of a NestedScrollView this control scrolls with as its
  /// body (a Column/Row with `scroll`), set by [build].
  ScrollController? _nestedController;

  /// The controller `scroll_to`, `auto_scroll` and the scrollbar act on: the
  /// renderer's (a NestedScrollView body list passes the inner controller),
  /// the NestedScrollView's for a body Column/Row, or this state's own.
  ScrollController get _controller =>
      widget.scrollController ??
      _nestedController ??
      (_ownController ??= ScrollController());

  @override
  void initState() {
    super.initState();
    widget.control.addInvokeMethodListener(_invokeMethod);
  }

  Future<dynamic> _invokeMethod(String name, dynamic args) async {
    debugPrint("ScrollableControl.$name($args)");
    switch (name) {
      case "scroll_to":
        var offset = parseDouble(args["offset"]);
        var delta = parseDouble(args["delta"]);
        var scrollKey = parseKey(args["scroll_key"]);
        var globalKey = scrollKey != null
            ? widget.control.backend.globalKeys[scrollKey.toString()]
            : null;
        var duration = parseDuration(args["duration"], Duration.zero)!;
        var curve = parseCurve(args["curve"], Curves.ease)!;
        if (globalKey != null) {
          var ctx = globalKey.currentContext;
          if (ctx != null) {
            await Scrollable.ensureVisible(ctx,
                duration: duration, curve: curve);
          }
        } else if (offset != null) {
          if (!_controller.hasClients) return null;
          if (offset < 0) {
            offset = _controller.position.maxScrollExtent + offset + 1;
          }
          if (duration.inMilliseconds < 1) {
            _controller.jumpTo(offset);
          } else {
            await _controller.animateTo(offset,
                duration: duration, curve: curve);
          }
        } else if (delta != null) {
          if (!_controller.hasClients) return null;
          var offset = _controller.position.pixels + delta;
          if (duration.inMilliseconds < 1) {
            _controller.jumpTo(offset);
          } else {
            await _controller.animateTo(offset,
                duration: duration, curve: curve);
          }
        }
    }
  }

  /// How `auto_scroll` moves to the end (Flet's `auto_scroll_animation`):
  /// `{duration, curve}`, a duration in milliseconds or `true` (1 second,
  /// linear, like every Flet animation value); 1 second `ease` when unset. A
  /// zero duration, or `false`, jumps.
  ImplicitAnimationDetails _autoScrollAnimation() {
    final fallback = ImplicitAnimationDetails(
        duration: const Duration(seconds: 1), curve: Curves.ease);
    var value = widget.control.get("auto_scroll_animation");
    if (value == false) {
      return ImplicitAnimationDetails(
          duration: Duration.zero, curve: Curves.ease);
    }
    if (value is double) value = value.round();
    if (value != null && value != true && value is! int && value is! Map) {
      return fallback;
    }
    return parseAnimation(value, fallback)!;
  }

  @override
  void dispose() {
    _ownController?.dispose();
    widget.control.removeInvokeMethodListener(_invokeMethod);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    debugPrint("ScrollableControl build: ${widget.control.id}");
    ScrollMode scrollMode =
        widget.control.getScrollMode("scroll", ScrollMode.none)!;
    // A NestedScrollView body scroll view: the renderer's own (ListView,
    // GridView, CustomScrollView) or, for a Column/Row, this one.
    final nested = scrollMode != ScrollMode.none
        ? NestedScrollBody.of(context, widget.control)
        : null;
    _nestedController =
        widget.wrapIntoScrollableView ? nested?.controller : null;

    if (widget.control.getBool("auto_scroll", false)!) {
      final animation = _autoScrollAnimation();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_controller.hasClients) return;
        final end = _controller.position.maxScrollExtent;
        if (animation.duration <= Duration.zero) {
          _controller.jumpTo(end);
        } else {
          _controller.animateTo(end,
              duration: animation.duration, curve: animation.curve);
        }
      });
    }
    final platform = effectiveTargetPlatform(context);
    final mobile =
        platform == TargetPlatform.iOS || platform == TargetPlatform.android;
    return scrollMode != ScrollMode.none
        ? PlatformScrollbar(
            // todo: create class ScrollBarConfiguration on Py end, for more customizability
            // The inner controller of a NestedScrollView is shared by the
            // pages of a TabBarView body, two of which are attached mid-swipe,
            // where an always visible (interactive) thumb cannot attach. Its
            // body scroll views show the thumb while they scroll.
            thumbVisibility: nested == null &&
                (scrollMode == ScrollMode.always ||
                    (scrollMode == ScrollMode.adaptive && !mobile)) &&
                scrollMode != ScrollMode.hidden,
            thickness: scrollMode == ScrollMode.hidden
                ? 0
                : mobile
                    ? 4.0
                    : null,
            controller: _controller,
            child: ScrollConfiguration(
              behavior:
                  ScrollConfiguration.of(context).copyWith(scrollbars: false),
              child: !widget.wrapIntoScrollableView
                  ? widget.child
                  : nested != null
                      ? _nestedScrollView(nested)
                      : SingleChildScrollView(
                          controller: _controller,
                          scrollDirection: widget.scrollDirection,
                          keyboardDismissBehavior: widget.control
                              .getKeyboardDismissBehavior(
                                  "keyboard_dismiss_behavior"),
                          child: widget.child,
                        ),
            ))
        : widget.child;
  }

  /// The Column/Row as a NestedScrollView body: the same box content after
  /// the overlap of the pinned header, scrolling with the inner controller.
  Widget _nestedScrollView(NestedScrollBody nested) {
    final handle = nested.handle;
    return CustomScrollView(
      key: PageStorageKey("nested_body_${widget.control.id}"),
      controller: _controller,
      scrollDirection: widget.scrollDirection,
      keyboardDismissBehavior: widget.control
          .getKeyboardDismissBehavior("keyboard_dismiss_behavior"),
      slivers: [
        if (handle != null) SliverOverlapInjector(handle: handle),
        SliverToBoxAdapter(child: widget.child),
      ],
    );
  }
}

/// Gives a multi-child control without a scroll view of its own (Flet's
/// ResponsiveRow and ExpansionPanelList are ScrollableControls) Column's
/// scroll surface along [axis]: `scroll` wraps [child] in a scroll view with
/// `auto_scroll`, `auto_scroll_animation` and `scroll_to`, and `on_scroll`
/// reports its position. Without `scroll`, [child] lays out as before.
Widget wrapInScrollableControl(Control control, Widget child,
    {Axis axis = Axis.vertical}) {
  Widget result = ScrollableControl(
      control: control,
      scrollDirection: axis,
      wrapIntoScrollableView: true,
      child: child);
  if (control.getBool("on_scroll", false)!) {
    result = ScrollNotificationControl(control: control, child: result);
  }
  return result;
}
