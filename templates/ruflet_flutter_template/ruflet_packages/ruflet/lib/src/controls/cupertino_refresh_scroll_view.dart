import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';

import '../models/control.dart';
import '../utils/colors.dart';
import '../utils/numbers.dart';

/// Cupertino pull-to-refresh: a [CupertinoSliverRefreshControl] as the first
/// sliver of a bouncing [CustomScrollView], like a native iOS table view.
class CupertinoRefreshScrollView extends StatelessWidget {
  static const double defaultTriggerDistance = 100.0;
  static const double indicatorExtent = 60.0;

  final Control control;
  final ScrollController? controller;
  final List<Widget> slivers;
  final bool shrinkWrap;
  final double? cacheExtent;
  final Clip clipBehavior;
  final int? semanticChildCount;
  final ScrollViewKeyboardDismissBehavior? keyboardDismissBehavior;
  final RefreshCallback onRefresh;

  const CupertinoRefreshScrollView({
    super.key,
    required this.control,
    required this.controller,
    required this.slivers,
    required this.shrinkWrap,
    required this.cacheExtent,
    required this.clipBehavior,
    required this.semanticChildCount,
    required this.keyboardDismissBehavior,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    debugPrint("CupertinoRefreshScrollView build: ${control.id}");
    final color = control.getColor("refresh_color", context);
    // The trigger distance must leave room for the open indicator.
    final triggerDistance = math.max(
        control.getDouble("refresh_trigger_distance", defaultTriggerDistance)!,
        indicatorExtent);
    return CustomScrollView(
      controller: controller,
      // The refresh control is driven by overscroll, which only bouncing
      // physics produce; "always" lets a short list be pulled too.
      physics:
          const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      shrinkWrap: shrinkWrap,
      cacheExtent: cacheExtent,
      clipBehavior: clipBehavior,
      semanticChildCount: semanticChildCount,
      keyboardDismissBehavior: keyboardDismissBehavior,
      slivers: [
        CupertinoSliverRefreshControl(
          onRefresh: onRefresh,
          refreshTriggerPullDistance: triggerDistance,
          refreshIndicatorExtent: indicatorExtent,
          builder: color == null
              ? CupertinoSliverRefreshControl.buildRefreshIndicator
              : _coloredIndicatorBuilder(color),
        ),
        ...slivers,
      ],
    );
  }
}

// Same geometry as CupertinoSliverRefreshControl.buildRefreshIndicator
// (cupertino/refresh.dart), with the Ruby `refresh_color` applied.
const double _kActivityIndicatorRadius = 14.0;
const double _kActivityIndicatorMargin = 16.0;

RefreshControlIndicatorBuilder _coloredIndicatorBuilder(Color color) => (
      BuildContext context,
      RefreshIndicatorMode refreshState,
      double pulledExtent,
      double refreshTriggerPullDistance,
      double refreshIndicatorExtent,
    ) {
      final percentageComplete =
          clampDouble(pulledExtent / refreshTriggerPullDistance, 0.0, 1.0);
      return Center(
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              top: _kActivityIndicatorMargin,
              left: 0.0,
              right: 0.0,
              child: _indicatorFor(refreshState, percentageComplete, color),
            ),
          ],
        ),
      );
    };

Widget _indicatorFor(
    RefreshIndicatorMode refreshState, double percentageComplete, Color color) {
  switch (refreshState) {
    case RefreshIndicatorMode.drag:
      const Curve opacityCurve = Interval(0.0, 0.35, curve: Curves.easeInOut);
      return Opacity(
        opacity: opacityCurve.transform(percentageComplete),
        child: CupertinoActivityIndicator.partiallyRevealed(
          color: color,
          radius: _kActivityIndicatorRadius,
          progress: percentageComplete,
        ),
      );
    case RefreshIndicatorMode.armed:
    case RefreshIndicatorMode.refresh:
      return CupertinoActivityIndicator(
          color: color, radius: _kActivityIndicatorRadius);
    case RefreshIndicatorMode.done:
      return CupertinoActivityIndicator(
          color: color, radius: _kActivityIndicatorRadius * percentageComplete);
    case RefreshIndicatorMode.inactive:
      return const SizedBox.shrink();
  }
}
