import 'package:flutter/widgets.dart';

import '../models/control.dart';
import '../utils/keys.dart';
import 'control_widget.dart';

/// Sliver helpers shared by the refreshable scrollable controls.
///
/// A refreshable ListView/GridView/Column is a `CustomScrollView` (the
/// Cupertino refresh control is a sliver), so list_view_sliver.dart and
/// grid_view_sliver.dart rebuild exactly the slivers that `ListView`/`GridView`
/// build internally. That keeps a list's geometry identical with and without
/// `on_refresh`. Each control's sliver lives in its own file, so a renderer
/// only depends on the code that reads its own Ruby keys.

/// A Ruby child as a sliver item, keyed like the box ListView/GridView items.
Widget sliverItem(Control item) => ControlWidget(
      key: ValueKey(item.getKey("key")?.value ?? item.id),
      control: item,
    );

/// Wraps [sliver] in the list padding the way `BoxScrollView` does: an explicit
/// `padding`, or else the main-axis media padding (safe area), leaving the
/// cross-axis media padding to the items.
Widget paddedSliver(
    BuildContext context, EdgeInsets? padding, Axis axis, Widget sliver) {
  EdgeInsetsGeometry? effectivePadding = padding;
  if (padding == null) {
    final mediaQuery = MediaQuery.maybeOf(context);
    if (mediaQuery != null) {
      final horizontalPadding =
          mediaQuery.padding.copyWith(top: 0.0, bottom: 0.0);
      final verticalPadding =
          mediaQuery.padding.copyWith(left: 0.0, right: 0.0);
      effectivePadding =
          axis == Axis.vertical ? verticalPadding : horizontalPadding;
      sliver = MediaQuery(
        data: mediaQuery.copyWith(
            padding:
                axis == Axis.vertical ? horizontalPadding : verticalPadding),
        child: sliver,
      );
    }
  }
  return effectivePadding == null
      ? sliver
      : SliverPadding(padding: effectivePadding, sliver: sliver);
}
