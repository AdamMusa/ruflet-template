import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../models/control.dart';
import '../utils/layout.dart';

// Box-content slivers for refreshable flex hosts (Column, View). Kept apart
// from scroll_slivers.dart (list/grid slivers) so a View does not depend on
// list and grid code.

/// Whether a flex host (Column, View) has a child that Ruby marked `expand`;
/// such a child becomes `Expanded`, which needs a bounded main axis.
bool hasExpandedChild(Control control) => control
    .children("controls")
    .any((child) => (child.getExpand("expand") ?? 0) > 0);

/// A box (a Column, a page body) as a sliver of a refreshable scroll view.
///
/// The box is at least as tall as the viewport, so main-axis alignment
/// (`alignment: "center"`, `"end"`, ...) lays out exactly as it does without
/// scrolling, and it grows past the viewport (and scrolls) when the content is
/// taller. Unlike `SliverFillRemaining` this never asks the box for its
/// intrinsic size, which LayoutBuilder-based children cannot answer. The
/// minimum ignores preceding slivers, so while the iOS refresh control is open
/// the content is pushed down (as in native iOS) instead of re-aligned.
///
/// With [fillViewport] the box is exactly one viewport tall instead, so
/// `expand` children keep flexing (an unbounded box would make them throw);
/// the view can then still be pulled, but not scrolled further.
Widget boxSliver(Widget child, {bool fillViewport = false}) =>
    SliverLayoutBuilder(
      builder: (context, constraints) {
        // A shrink-wrapping (unbounded) viewport reports an infinite extent.
        final viewport = constraints.viewportMainAxisExtent;
        final extent = viewport.isFinite ? math.max(0.0, viewport) : 0.0;
        final vertical = constraints.axis == Axis.vertical;
        final BoxConstraints box = fillViewport && viewport.isFinite
            ? (vertical
                ? BoxConstraints.tightFor(height: extent)
                : BoxConstraints.tightFor(width: extent))
            : (vertical
                ? BoxConstraints(minHeight: extent)
                : BoxConstraints(minWidth: extent));
        return SliverToBoxAdapter(
          child: ConstrainedBox(constraints: box, child: child),
        );
      },
    );
