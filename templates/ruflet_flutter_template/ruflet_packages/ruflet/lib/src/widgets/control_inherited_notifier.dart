import 'package:flutter/widgets.dart';

import '../extensions/control.dart';
import '../ruflet_backend.dart';
import '../models/control.dart';
import 'platform_control_theme.dart';

/// InheritedNotifier for a [Control].
///
/// Used to rebuild a control subtree when the
/// corresponding [Control] (a [ChangeNotifier]) changes.
class ControlInheritedNotifier extends InheritedNotifier<Control> {
  const ControlInheritedNotifier({
    super.key,
    super.notifier,
    required super.child,
  }) : super();

  /// Establishes a dependency on the nearest [ControlInheritedNotifier] and
  /// returns its [Control].
  static Control? of(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<ControlInheritedNotifier>()
        ?.notifier;
  }

  @override
  bool updateShouldNotify(ControlInheritedNotifier oldWidget) {
    return notifier != oldWidget.notifier;
  }
}

/// Wraps [builder] with [ControlInheritedNotifier], unless the control opts out.
///
/// If `"skip_inherited_notifier"` internal is `true`, this returns
/// [builder] without a [ControlInheritedNotifier] wrapper.
Widget withControlInheritedNotifier(Control control, WidgetBuilder builder) {
  if (control.internals?["skip_inherited_notifier"] == true) {
    return Builder(builder: builder);
  }

  return ControlInheritedNotifier(
    notifier: control,
    child: Builder(builder: (context) {
      ControlInheritedNotifier.of(context);
      return builder(context);
    }),
  );
}

/// Convenience wrapper that applies both:
/// - [withControlInheritedNotifier]
/// - [withControlTheme]
Widget withControlContext(
  Control control,
  WidgetBuilder builder,
) {
  // Avoid stacking Builders for controls that opt out of the inherited notifier
  // pattern. `withControlTheme()` is also a no-op for these controls.
  if (control.internals?["skip_inherited_notifier"] == true) {
    return Builder(builder: builder);
  }

  return Builder(builder: (context) {
    final child = withControlInheritedNotifier(control, builder);
    return withControlTheme(control, context, child);
  });
}

/// Applies per-control theming (`theme`, `dark_theme`, `theme_mode`) to `child`.
///
/// Returns `child` unchanged when:
/// - `control` is the page/root control
/// - `"skip_inherited_notifier"` internal is `true`
/// - no `theme`/`dark_theme` is set and `theme_mode` is `null`
///
/// Parameters:
/// - `control`: the control whose per-control theme (if any) will be applied.
/// - `context`: used to access `RufletBackend` and the ambient `Theme`.
/// - `child`: the widget subtree to wrap with the per-control `Theme`.
Widget withControlTheme(Control control, BuildContext context, Widget child) {
  if (control == RufletBackend.of(context).page) return child;

  if (control.internals?["skip_inherited_notifier"] == true) return child;

  final hasNoThemes =
      control.get("theme") == null && control.get("dark_theme") == null;
  final themeMode = control.get("theme_mode");
  if (hasNoThemes && themeMode == null) return child;

  return PlatformControlTheme(control: control, child: child);
}

extension ControlContextBuilder on Control {
  /// Builds a widget under this control's standard "control context":
  /// [ControlInheritedNotifier] + per-control theme wrapping.
  ///
  /// This is primarily used by [ControlWidget] and any "special" controls that
  /// must subclass a Flutter widget (e.g. a control that must be a `Tab`) but
  /// still need the same wrapper behavior as a normal `ControlWidget`.
  Widget buildInControlContext(WidgetBuilder builder) {
    return withControlContext(this, builder);
  }
}
