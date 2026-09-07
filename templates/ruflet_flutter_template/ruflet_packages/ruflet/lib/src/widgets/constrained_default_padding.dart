import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Native default spacing yields to explicit control constraints before content
/// is clipped. Use ordinary Padding for padding explicitly supplied by the app.
class ConstrainedDefaultPadding extends SingleChildRenderObjectWidget {
  final EdgeInsets padding;

  const ConstrainedDefaultPadding({
    super.key,
    required this.padding,
    required super.child,
  });

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderConstrainedDefaultPadding(padding);

  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) {
    (renderObject as _RenderConstrainedDefaultPadding).padding = padding;
  }
}

class _RenderConstrainedDefaultPadding extends RenderShiftedBox {
  _RenderConstrainedDefaultPadding(this._padding) : super(null);

  EdgeInsets _padding;
  set padding(EdgeInsets value) {
    if (_padding == value) return;
    _padding = value;
    markNeedsLayout();
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) => constraints.constrain(
      (child?.getDryLayout(constraints.loosen()) ?? Size.zero) +
          Offset(_padding.horizontal, _padding.vertical));

  @override
  double computeMinIntrinsicWidth(double height) =>
      (child?.getMinIntrinsicWidth(math.max(0, height - _padding.vertical)) ??
          0) +
      _padding.horizontal;

  @override
  double computeMaxIntrinsicWidth(double height) =>
      (child?.getMaxIntrinsicWidth(math.max(0, height - _padding.vertical)) ??
          0) +
      _padding.horizontal;

  @override
  double computeMinIntrinsicHeight(double width) =>
      (child?.getMinIntrinsicHeight(math.max(0, width - _padding.horizontal)) ??
          0) +
      _padding.vertical;

  @override
  double computeMaxIntrinsicHeight(double width) =>
      (child?.getMaxIntrinsicHeight(math.max(0, width - _padding.horizontal)) ??
          0) +
      _padding.vertical;

  @override
  void performLayout() {
    child?.layout(constraints.loosen(), parentUsesSize: true);
    final contentSize = child?.size ?? Size.zero;
    size = constraints.constrain(
        contentSize + Offset(_padding.horizontal, _padding.vertical));
    if (child == null) return;

    final horizontal = math.max(0.0, size.width - contentSize.width);
    final vertical = math.max(0.0, size.height - contentSize.height);
    final xScale = _padding.horizontal == 0
        ? 1.0
        : math.min(1.0, horizontal / _padding.horizontal);
    final yScale = _padding.vertical == 0
        ? 1.0
        : math.min(1.0, vertical / _padding.vertical);
    (child!.parentData! as BoxParentData).offset = Offset(
      _padding.left * xScale,
      _padding.top * yScale,
    );
  }
}
