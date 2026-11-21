import 'package:flutter/cupertino.dart';

import '../models/control.dart';
import '../utils/cupertino_theme.dart';
import 'sliver_app_bar_spec.dart';

/// iOS SliverAppBar.
///
/// medium and large: [CupertinoSliverNavigationBar], the large title that
/// shrinks into the always pinned navigation bar as the content scrolls.
/// small: a [CupertinoNavigationBar] that is pinned ([PinnedHeaderSliver]),
/// floating ([SliverFloatingHeader]) or scrolls away ([SliverToBoxAdapter]).
class CupertinoSliverAppBarControl extends StatelessWidget {
  final Control control;

  const CupertinoSliverAppBarControl({super.key, required this.control});

  @override
  Widget build(BuildContext context) {
    debugPrint("CupertinoSliverAppBar build: ${control.id}");

    final spec = SliverAppBarSpec.read(control, context,
        borderTheme: cupertinoStyleTheme(context));
    final trailing = spec.actions.isEmpty
        ? null
        : Row(mainAxisSize: MainAxisSize.min, children: spec.actions);
    // Keep the SDK hairline unless Ruby sends its own border.
    final border = spec.border ?? const CupertinoNavigationBar().border;
    final bottom = spec.bottom;

    if (spec.variant != SliverAppBarVariant.small) {
      return CupertinoSliverNavigationBar(
        largeTitle: spec.title,
        leading: spec.leading,
        automaticallyImplyLeading: spec.automaticallyImplyLeading,
        alwaysShowMiddle: spec.alwaysShowMiddle,
        previousPageTitle: spec.previousPageTitle,
        trailing: trailing,
        border: border,
        backgroundColor: spec.backgroundColor,
        transitionBetweenRoutes: spec.transitionBetweenRoutes,
        stretch: spec.stretch,
        bottom: bottom,
        bottomMode: bottom == null ? null : NavigationBarBottomMode.automatic,
      );
    }

    final bar = CupertinoNavigationBar(
      leading: spec.leading,
      automaticallyImplyLeading: spec.automaticallyImplyLeading,
      middle: spec.title,
      previousPageTitle: spec.previousPageTitle,
      trailing: trailing,
      border: border,
      backgroundColor: spec.backgroundColor,
      transitionBetweenRoutes: spec.transitionBetweenRoutes,
      bottom: bottom,
    );
    if (spec.pinned) {
      return PinnedHeaderSliver(child: bar);
    }
    if (spec.floating) {
      return SliverFloatingHeader(
        snapMode: spec.snap
            ? FloatingHeaderSnapMode.scroll
            : FloatingHeaderSnapMode.overlay,
        child: bar,
      );
    }
    return SliverToBoxAdapter(child: bar);
  }
}
