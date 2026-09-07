/// A design-neutral fork of package:shimmer.
///
/// The public API matches shimmer 3.0.0. The implementation deliberately
/// imports no Material or Cupertino widgets so the same renderer can be used
/// beneath either Ruflet app root.
library shimmer;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

enum ShimmerDirection { ltr, rtl, ttb, btt }

@immutable
class Shimmer extends StatefulWidget {
  final Widget child;
  final Duration period;
  final ShimmerDirection direction;
  final Gradient gradient;
  final int loop;
  final bool enabled;

  const Shimmer({
    super.key,
    required this.child,
    required this.gradient,
    this.direction = ShimmerDirection.ltr,
    this.period = const Duration(milliseconds: 1500),
    this.loop = 0,
    this.enabled = true,
  });

  Shimmer.fromColors({
    super.key,
    required this.child,
    required Color baseColor,
    required Color highlightColor,
    this.period = const Duration(milliseconds: 1500),
    this.direction = ShimmerDirection.ltr,
    this.loop = 0,
    this.enabled = true,
  }) : gradient = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.centerRight,
          colors: <Color>[
            baseColor,
            baseColor,
            highlightColor,
            baseColor,
            baseColor,
          ],
          stops: const <double>[0.0, 0.35, 0.5, 0.65, 1.0],
        );

  @override
  State<Shimmer> createState() => _ShimmerState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<Gradient>('gradient', gradient));
    properties.add(EnumProperty<ShimmerDirection>('direction', direction));
    properties.add(DiagnosticsProperty<Duration>('period', period));
    properties.add(DiagnosticsProperty<bool>('enabled', enabled));
    properties.add(DiagnosticsProperty<int>('loop', loop, defaultValue: 0));
  }
}

class _ShimmerState extends State<Shimmer> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  int _count = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.period)
      ..addStatusListener((status) {
        if (status != AnimationStatus.completed) return;
        _count++;
        if (widget.loop <= 0) {
          _controller.repeat();
        } else if (_count < widget.loop) {
          _controller.forward(from: 0);
        }
      });
    if (widget.enabled) _controller.forward();
  }

  @override
  void didUpdateWidget(Shimmer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.period != widget.period) {
      _controller.duration = widget.period;
    }
    widget.enabled ? _controller.forward() : _controller.stop();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _controller,
        child: widget.child,
        builder: (_, child) => _ShimmerRenderWidget(
          direction: widget.direction,
          gradient: widget.gradient,
          percent: _controller.value,
          child: child,
        ),
      );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

@immutable
class _ShimmerRenderWidget extends SingleChildRenderObjectWidget {
  final double percent;
  final ShimmerDirection direction;
  final Gradient gradient;

  const _ShimmerRenderWidget({
    super.child,
    required this.percent,
    required this.direction,
    required this.gradient,
  });

  @override
  _ShimmerFilter createRenderObject(BuildContext context) =>
      _ShimmerFilter(percent, direction, gradient);

  @override
  void updateRenderObject(BuildContext context, _ShimmerFilter renderObject) {
    renderObject
      ..percent = percent
      ..gradient = gradient
      ..direction = direction;
  }
}

class _ShimmerFilter extends RenderProxyBox {
  ShimmerDirection _direction;
  Gradient _gradient;
  double _percent;

  _ShimmerFilter(this._percent, this._direction, this._gradient);

  @override
  ShaderMaskLayer? get layer => super.layer as ShaderMaskLayer?;

  @override
  bool get alwaysNeedsCompositing => child != null;

  set percent(double value) {
    if (value == _percent) return;
    _percent = value;
    markNeedsPaint();
  }

  set gradient(Gradient value) {
    if (value == _gradient) return;
    _gradient = value;
    markNeedsPaint();
  }

  set direction(ShimmerDirection value) {
    if (value == _direction) return;
    _direction = value;
    markNeedsLayout();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (child == null) {
      layer = null;
      return;
    }
    assert(needsCompositing);
    final width = child!.size.width;
    final height = child!.size.height;
    late final Rect rect;
    switch (_direction) {
      case ShimmerDirection.rtl:
        final dx = _offset(width, -width, _percent);
        rect = Rect.fromLTWH(dx - width, 0, 3 * width, height);
      case ShimmerDirection.ttb:
        final dy = _offset(-height, height, _percent);
        rect = Rect.fromLTWH(0, dy - height, width, 3 * height);
      case ShimmerDirection.btt:
        final dy = _offset(height, -height, _percent);
        rect = Rect.fromLTWH(0, dy - height, width, 3 * height);
      case ShimmerDirection.ltr:
        final dx = _offset(-width, width, _percent);
        rect = Rect.fromLTWH(dx - width, 0, 3 * width, height);
    }
    layer ??= ShaderMaskLayer();
    layer!
      ..shader = _gradient.createShader(rect)
      ..maskRect = offset & size
      ..blendMode = BlendMode.srcIn;
    context.pushLayer(layer!, super.paint, offset);
  }

  double _offset(double start, double end, double percent) =>
      start + (end - start) * percent;
}
