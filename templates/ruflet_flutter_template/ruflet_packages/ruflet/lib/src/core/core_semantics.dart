import 'package:flutter/widgets.dart';

/// Accessibility a native widget has no parameter for.
///
/// When a spec declares an accessibility key for both skins and one design's
/// native widget cannot take it (for example `CupertinoAlertDialog` has no
/// `semanticLabel`), that skin wraps the native widget in [CoreSemantics] so
/// the Ruby value reaches the semantics tree on both designs.
class CoreSemantics extends StatelessWidget {
  const CoreSemantics({
    super.key,
    required this.child,
    this.label,
    this.scopesRoute,
    this.namesRoute,
    this.excludeSemantics = false,
  });

  final Widget child;
  final String? label;
  final bool? scopesRoute;
  final bool? namesRoute;

  /// Hides the native subtree's own semantics (Ruby `exclude_from_semantics`).
  final bool excludeSemantics;

  @override
  Widget build(BuildContext context) {
    if (label == null &&
        scopesRoute == null &&
        namesRoute == null &&
        !excludeSemantics) {
      return child;
    }
    return Semantics(
      label: label,
      scopesRoute: scopesRoute,
      namesRoute: namesRoute,
      // A route scope keeps its children as separate nodes (framework rule).
      explicitChildNodes: scopesRoute ?? false,
      excludeSemantics: excludeSemantics,
      child: child,
    );
  }
}
