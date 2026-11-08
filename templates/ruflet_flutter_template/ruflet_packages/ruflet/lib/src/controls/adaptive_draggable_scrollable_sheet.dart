import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../extensions/control.dart';
import '../models/control.dart';
import '../utils/animations.dart';
import '../utils/edge_insets.dart';
import '../utils/numbers.dart';
import '../utils/time.dart';
import '../widgets/error.dart';
import '../widgets/platform_control_renderer.dart';
import 'base_controls.dart';
import 'cupertino_draggable_scrollable_sheet.dart';
import 'material_draggable_scrollable_sheet.dart';

/// A snapping, maps-style sheet that fills its (bounded) parent.
///
/// The sheet, its controller, snapping and the `extent_change` event are
/// design-neutral; only the surface (Material 3 sheet or iOS card) differs.
class DraggableScrollableSheetControl extends StatefulWidget {
  final Control control;

  const DraggableScrollableSheetControl({super.key, required this.control});

  @override
  State<DraggableScrollableSheetControl> createState() =>
      _DraggableScrollableSheetControlState();
}

class _DraggableScrollableSheetControlState
    extends State<DraggableScrollableSheetControl> {
  final _controller = DraggableScrollableController();
  List<double>? _snapSizes;
  Timer? _throttle;
  Map<String, double>? _pending;
  Map<String, double>? _latest;

  Control get control => widget.control;

  @override
  void initState() {
    super.initState();
    control.addInvokeMethodListener(_invokeMethod);
  }

  @override
  void didUpdateWidget(covariant DraggableScrollableSheetControl oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.control != control) {
      oldWidget.control.removeInvokeMethodListener(_invokeMethod);
      control.addInvokeMethodListener(_invokeMethod);
    }
  }

  @override
  void dispose() {
    control.removeInvokeMethodListener(_invokeMethod);
    _throttle?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<dynamic> _invokeMethod(String name, dynamic args) async {
    if (name != "animate_to" && name != "jump_to") return null;
    final params = args is Map ? args : const {};
    final size = parseDouble(params["size"]);
    if (size == null || !_controller.isAttached) return null;
    final target = clampDouble(size, 0, 1);
    final duration =
        parseDuration(params["duration"], const Duration(milliseconds: 300))!;
    if (name == "jump_to" || duration <= Duration.zero) {
      _controller.jumpTo(target);
    } else {
      // Not awaited: a user drag cancels the animation and its future would
      // then never complete, leaving the Ruby call waiting for its timeout.
      unawaited(_controller.animateTo(target,
          duration: duration,
          curve: parseCurve(params["curve"]?.toString(), Curves.easeOut)!));
    }
    return null;
  }

  bool _onExtent(DraggableScrollableNotification notification) {
    if (notification.depth != 0) return false;
    _latest = {
      "extent": notification.extent,
      "min": notification.minExtent,
      "max": notification.maxExtent,
    };
    if (control.hasEventHandler("extent_change")) {
      _pending = _latest;
      if (_throttle == null) _flush();
    }
    return false;
  }

  bool _onScrollEnd(ScrollEndNotification notification) {
    // A finished drag always reports where the sheet ended up.
    if (notification.depth == 0 &&
        _latest != null &&
        control.hasEventHandler("extent_change")) {
      _throttle?.cancel();
      _pending = _latest;
      _flush();
    }
    return false;
  }

  /// Leading + trailing throttle of `extent_change` (`extent_change_interval`).
  void _flush() {
    final data = _pending;
    _pending = null;
    if (data == null) {
      _throttle = null;
      return;
    }
    control.triggerEvent("extent_change", data);
    _throttle = Timer(
        Duration(milliseconds: control.getInt("extent_change_interval", 50)!),
        _flush);
  }

  /// Snap sizes strictly between min and max, sorted and de-duplicated (the
  /// SDK asserts on anything else). The list is reused while unchanged so a
  /// Ruby update does not re-trigger snapping mid-gesture.
  List<double>? _sanitizedSnapSizes(double min, double max) {
    final raw = control.get("snap_sizes");
    if (raw is! List) return _snapSizes = null;
    final sizes = raw
        .map((value) => parseDouble(value))
        .whereType<double>()
        .where((size) => size > min && size < max)
        .toSet()
        .toList()
      ..sort();
    if (_snapSizes != null && listEquals(_snapSizes, sizes)) return _snapSizes;
    return _snapSizes = sizes;
  }

  Widget _list() {
    final controls = control.buildWidgets("controls");
    final spacing = control.getDouble("spacing", 0)!;
    Widget list = spacing > 0
        ? SliverList.separated(
            itemCount: controls.length,
            itemBuilder: (_, index) => controls[index],
            separatorBuilder: (_, __) => SizedBox(height: spacing),
          )
        : SliverList.list(children: controls);
    final padding = control.getPadding("padding");
    if (padding != null) list = SliverPadding(padding: padding, sliver: list);
    return list;
  }

  @override
  Widget build(BuildContext context) {
    debugPrint("DraggableScrollableSheet build: ${control.id}");

    final min = clampDouble(control.getDouble("min_child_size", 0.25)!, 0, 1);
    final max = clampDouble(control.getDouble("max_child_size", 1.0)!, min, 1);
    final initial =
        clampDouble(control.getDouble("initial_child_size", 0.5)!, min, max);
    final snapDuration = control.getDuration("snap_animation_duration");

    final sheet = DraggableScrollableSheet(
      controller: _controller,
      initialChildSize: initial,
      minChildSize: min,
      maxChildSize: max,
      snap: control.getBool("snap", false)!,
      snapSizes: _sanitizedSnapSizes(min, max),
      snapAnimationDuration:
          snapDuration != null && snapDuration > Duration.zero
              ? snapDuration
              : null,
      shouldCloseOnMinExtent:
          control.getBool("should_close_on_min_extent", true)!,
      builder: (context, scrollController) {
        final header = control.buildWidget("header");
        final list = _list();
        return PlatformControlRenderer(
          material: (_) => MaterialDraggableScrollableSheetSurface(
              control: control,
              scrollController: scrollController,
              header: header,
              list: list),
          cupertino: (_) => CupertinoDraggableScrollableSheetSurface(
              control: control,
              scrollController: scrollController,
              header: header,
              list: list),
        );
      },
    );

    return LayoutControl(
      control: control,
      child: LayoutBuilder(builder: (context, constraints) {
        if (!constraints.hasBoundedHeight) {
          return const ErrorControl(
              "DraggableScrollableSheet needs a bounded height: place it in a "
              "Stack or give it a height or expand.");
        }
        return NotificationListener<ScrollEndNotification>(
          onNotification: _onScrollEnd,
          child: NotificationListener<DraggableScrollableNotification>(
            onNotification: _onExtent,
            child: sheet,
          ),
        );
      }),
    );
  }
}
