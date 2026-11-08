import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../models/control.dart';

/// What a NestedScrollView tells the scroll views of its body.
///
/// A body scroll view must scroll with the NestedScrollView's inner
/// [controller], or dragging it would not collapse the header. When the
/// header pins (a pinned SliverAppBar), the body also overlaps the pinned
/// part by [handle]'s extent, which the scroll view injects
/// ([SliverOverlapInjector]) so its first item starts below the header and
/// later items scroll under it.
///
/// Only the controls listed in [scrollables] take part: the body itself, or
/// each page of a TabBarView body. A list nested deeper in the body keeps its
/// own controller, like a Flutter scroll view that is not the primary one.
class NestedScrollBody extends InheritedWidget {
  /// The overlap to inject, or null when the body is already laid out below
  /// the header (a body the scrollables do not fully cover).
  final SliverOverlapAbsorberHandle? handle;

  /// The NestedScrollView's inner controller. A scroll view takes it for its
  /// whole life: swapping a Scrollable's controller to it is not supported.
  final ScrollController controller;

  /// Ids of the body controls that scroll with [controller].
  final Set<int> scrollables;

  const NestedScrollBody(
      {super.key,
      required this.handle,
      required this.controller,
      required this.scrollables,
      required super.child});

  /// The scope when [control] is one of its body scroll views, else null.
  static NestedScrollBody? of(BuildContext context, Control control) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<NestedScrollBody>();
    return scope != null && scope.scrollables.contains(control.id)
        ? scope
        : null;
  }

  /// Whether any of [controls] (TabBarView pages) scrolls with the scope.
  /// A TabBarView builds only its selected page then, as a PageView does:
  /// every built page would scroll along with the visible one. Each page's
  /// scroll view keeps its offset in [PageStorage].
  static bool scrollsAny(BuildContext context, Iterable<Control> controls) =>
      controls.any((control) => of(context, control) != null);

  @override
  bool updateShouldNotify(NestedScrollBody oldWidget) =>
      handle != oldWidget.handle ||
      controller != oldWidget.controller ||
      !setEquals(scrollables, oldWidget.scrollables);
}
