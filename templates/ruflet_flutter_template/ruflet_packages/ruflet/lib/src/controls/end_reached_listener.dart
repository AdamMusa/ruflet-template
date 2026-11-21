import 'package:flutter/widgets.dart';

import '../models/control.dart';
import '../utils/numbers.dart';

/// Fires the Ruby `end_reached` event (infinite scroll) for the scroll view
/// below it.
///
/// The event fires once when the trailing edge comes within
/// `end_reached_threshold` (default 200 px), including right after the first
/// layout when the content is shorter than the viewport. It re-arms when the
/// content grows (Ruby appended items) or when the user scrolls back more than
/// twice the threshold away from the end. A `reverse: true` list reaches its
/// end at the visual top, which is the "load older messages" case.
///
/// It only listens (depth 0, never absorbs) and works for box and sliver
/// scroll views alike.
class EndReachedListener extends StatefulWidget {
  static const double defaultThreshold = 200.0;

  final Control control;
  final Widget child;

  const EndReachedListener(
      {super.key, required this.control, required this.child});

  @override
  State<EndReachedListener> createState() => _EndReachedListenerState();
}

class _EndReachedListenerState extends State<EndReachedListener> {
  /// The `maxScrollExtent` the event last fired for; null while armed.
  double? _firedFor;

  bool _onNotification(Notification notification) {
    final ScrollMetrics metrics;
    if (notification is ScrollNotification) {
      if (notification.depth != 0) return false;
      metrics = notification.metrics;
    } else if (notification is ScrollMetricsNotification) {
      if (notification.depth != 0) return false;
      metrics = notification.metrics;
    } else {
      return false;
    }
    if (!metrics.hasContentDimensions) return false;

    final threshold = widget.control.getDouble(
        "end_reached_threshold", EndReachedListener.defaultThreshold)!;
    final firedFor = _firedFor;
    if (firedFor != null &&
        (metrics.maxScrollExtent > firedFor ||
            metrics.extentAfter > 2 * threshold)) {
      _firedFor = null;
    }
    if (_firedFor == null && metrics.extentAfter <= threshold) {
      _firedFor = metrics.maxScrollExtent;
      widget.control.triggerEvent("end_reached", {
        "pixels": metrics.pixels,
        "max_scroll_extent": metrics.maxScrollExtent,
        "viewport_dimension": metrics.viewportDimension,
      });
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollMetricsNotification>(
      onNotification: _onNotification,
      child: NotificationListener<ScrollNotification>(
        onNotification: _onNotification,
        child: widget.child,
      ),
    );
  }
}
