import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../models/control.dart';
import '../utils/animations.dart';
import '../utils/edge_insets.dart';
import '../utils/misc.dart';
import '../utils/numbers.dart';
import '../utils/time.dart';
import '../widgets/error.dart';
import 'control_widget.dart';

/// The Ruby CarouselView state shared by the Material and Cupertino
/// renderers. Design-neutral.
class CarouselViewModel {
  final Control control;
  final List<Control> items;

  CarouselViewModel(this.control) : items = control.children("controls");

  double? get itemExtent => control.getDouble("item_extent");

  /// `flex_weights` selects the weighted layout; it wins over `item_extent`.
  List<int>? get flexWeights {
    final value = control.get("flex_weights");
    if (value is! List || value.isEmpty) return null;
    return value.map((weight) => parseInt(weight, 0)!).toList();
  }

  bool get weighted => flexWeights != null;

  /// An [ErrorControl] when the Ruby data cannot be rendered, else `null`.
  Widget? get error {
    final weights = flexWeights;
    if (weights != null) {
      return weights.every((weight) => weight > 0)
          ? null
          : const ErrorControl(
              "CarouselView.flex_weights must all be positive integers");
    }
    final extent = itemExtent;
    if (extent == null || extent <= 0) {
      return const ErrorControl(
          "CarouselView needs item_extent or flex_weights",
          description: "Set item_extent: 320 (pixels per item) or "
              "flex_weights: [3, 2, 1]");
    }
    return null;
  }

  Axis get scrollDirection =>
      control.getBool("horizontal", true)! ? Axis.horizontal : Axis.vertical;

  bool get reverse => control.getBool("reverse", false)!;

  bool get itemSnapping => control.getBool("item_snapping", false)!;

  double get shrinkExtent => control.getDouble("shrink_extent", 0)!;

  bool get consumeMaxWeight => control.getBool("consume_max_weight", true)!;

  /// Per-item padding; null keeps the renderer default (4 px on every side).
  EdgeInsets? get padding => control.getPadding("padding");

  double? get elevation => control.getDouble("elevation");

  bool get enableSplash => control.getBool("enable_splash", true)!;

  Clip get itemClipBehavior => parseClip(
      control.getString("item_clip_behavior")?.replaceAll("_", ""),
      Clip.antiAlias)!;

  int get initialItem => clampIndex(control.getInt("initial_item", 0)!);

  int clampIndex(int index) => math.max(0, math.min(index, items.length - 1));

  Widget buildItem(int index) =>
      ControlWidget(key: ValueKey(items[index].id), control: items[index]);

  /// Fires `item_click` with the tapped index; null without a Ruby handler.
  ValueChanged<int>? get onItemClick =>
      !control.disabled && control.getBool("on_item_click", false)!
          ? (index) => control.triggerEvent("item_click", index)
          : null;
}

/// Parsed arguments of the Ruby `animate_to_item(index, duration:, curve:)`
/// method (`"animate_to_item"` invoke).
class CarouselAnimateToItem {
  final int index;
  final Duration duration;
  final Curve curve;

  const CarouselAnimateToItem(this.index, this.duration, this.curve);

  static CarouselAnimateToItem? parse(dynamic args) {
    final map = args is Map ? args : const {};
    final index = parseInt(map["index"]);
    if (index == null) return null;
    return CarouselAnimateToItem(
      index,
      parseDuration(map["duration"], const Duration(milliseconds: 300))!,
      parseCurve(map["curve"]?.toString().replaceAll("_", ""), Curves.ease)!,
    );
  }
}
