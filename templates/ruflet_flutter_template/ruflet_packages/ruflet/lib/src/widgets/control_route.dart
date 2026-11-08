import 'package:flutter/widgets.dart';

import '../models/control.dart';
import '../utils/numbers.dart';

/// The route each dialog-like control presented, so closing it never pops a
/// route the control does not own.
final _presented = Expando<Route<dynamic>>('Ruflet control route');

/// Routes opened from inside a control's route (e.g. a licenses page), in
/// push order. They belong to that control and close with it.
final _adopted = Expando<List<Route<dynamic>>>('Ruflet control child routes');

/// The routes [control] currently owns besides its own (see
/// [ControlRouteScope]), top-most last.
@visibleForTesting
List<Route<dynamic>> adoptedControlRoutes(Control control) =>
    List.unmodifiable(_adopted[control] ?? const <Route<dynamic>>[]);

/// Presents the route of a dialog-like control (`open: true`).
///
/// Call from `build` when `open` turns true. The route is pushed onto the
/// owning navigator after the frame. If `open` was turned off again before
/// that (or the control left the tree), nothing is pushed and the dismiss
/// lifecycle still completes, so the control can be reopened.
void presentControlRoute(
    BuildContext context, Control control, Route<void> Function() createRoute) {
  control.updateProperties({"_open": true}, python: false);
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!context.mounted || !control.getBool("open", false)!) {
      debugPrint("${control.type}(${control.id}): closed before presenting.");
      _didDismiss(control);
      return;
    }
    final route = createRoute();
    _presented[control] = route;
    _adopted[control] = null;
    Navigator.of(context).push(route).then((_) {
      if (identical(_presented[control], route)) {
        _presented[control] = null;
        _adopted[control] = null;
      }
      debugPrint("Dismissing ${control.type}(${control.id})");
      _didDismiss(control);
    });
  });
}

/// Closes the route a control presented (`open: false`), together with the
/// routes it adopted through [ControlRouteScope].
///
/// Call from `build` when `open` turns false. After the frame, only the
/// control's own routes are closed: each is popped when it is on top and
/// removed when another route (e.g. another control's dialog) covers it. A
/// close that arrives before the route was pushed is completed by
/// [presentControlRoute]; repeated calls are no-ops.
void closeControlRoute(Control control) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    final route = _presented[control];
    if (route == null || !route.isActive) return;
    final adopted = _adopted[control] ?? const [];
    _adopted[control] = null;
    for (final child in adopted.reversed) {
      _closeRoute(child);
    }
    _closeRoute(route);
  });
}

void _closeRoute(Route<dynamic> route) {
  final navigator = route.navigator;
  if (navigator == null || !route.isActive) return;
  if (route.isCurrent) {
    navigator.pop();
  } else {
    navigator.removeRoute(route);
  }
}

/// Exactly one `dismiss` per presentation; `open` is reset for Ruby.
void _didDismiss(Control control) {
  control.updateProperties({"_open": false}, python: false);
  control.updateProperties({"open": false});
  control.triggerEvent("dismiss");
}

/// Wrap the content of a control's route so that routes opened from inside
/// it become part of the control's presentation and close with it.
///
/// Routes pushed the way Flutter's own `showLicensePage`, `showDialog` and
/// `showModalBottomSheet` push (capturing the pusher's [InheritedTheme]s and
/// re-applying them in the new route) carry this scope along; it records the
/// new route as adopted. Use [pushCarryingThemes] to push that way.
class ControlRouteScope extends InheritedTheme {
  final Control control;

  const ControlRouteScope(
      {super.key, required this.control, required super.child});

  @override
  Widget wrap(BuildContext context, Widget child) => ControlRouteScope(
      control: control, child: _AdoptRoute(control: control, child: child));

  @override
  bool updateShouldNotify(ControlRouteScope oldWidget) =>
      control != oldWidget.control;
}

/// Wraps a page with the themes captured from the pushing context.
typedef CapturedThemesWrapper = Widget Function(Widget child);

/// Pushes the route built by [createRoute] the way Flutter's `showLicensePage`
/// does: the new page is wrapped with the [InheritedTheme]s of [context], so
/// it keeps the pusher's theme and a [ControlRouteScope] above [context]
/// adopts the route.
Future<T?> pushCarryingThemes<T>(BuildContext context,
    Route<T> Function(CapturedThemesWrapper wrap) createRoute) {
  final navigator = Navigator.of(context);
  final themes = InheritedTheme.capture(from: context, to: navigator.context);
  return navigator.push(createRoute(themes.wrap));
}

class _AdoptRoute extends StatefulWidget {
  final Control control;
  final Widget child;

  const _AdoptRoute({required this.control, required this.child});

  @override
  State<_AdoptRoute> createState() => _AdoptRouteState();
}

class _AdoptRouteState extends State<_AdoptRoute> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    final owner = _presented[widget.control];
    // A route on its way out (dependencies also change while it animates
    // away) is never adopted again.
    if (route == null ||
        owner == null ||
        identical(route, owner) ||
        !route.isActive) {
      return;
    }
    final adopted = _adopted[widget.control] ??= [];
    if (adopted.contains(route)) return;
    adopted.add(route);
    // Forget it as soon as it is popped or removed, so the control only ever
    // tracks live routes, however often the license pages are opened.
    route.popped.whenComplete(() => adopted.remove(route));
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
