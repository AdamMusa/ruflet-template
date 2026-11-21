import 'package:flutter/material.dart';

import '../models/control.dart';
import 'sliver_app_bar_spec.dart';

/// Material [SliverAppBar]: small (default), medium or large (M3), pinned,
/// floating, snapping and stretching, with an optional flexible space.
class MaterialSliverAppBarControl extends StatelessWidget {
  final Control control;

  const MaterialSliverAppBarControl({super.key, required this.control});

  /// SliverAppBar.medium and .large collapse to this toolbar height (M3).
  static const double _collapsingToolbarHeight = 64;

  @override
  Widget build(BuildContext context) {
    debugPrint("MaterialSliverAppBar build: ${control.id}");

    final spec = SliverAppBarSpec.read(control, context);
    final small = spec.variant == SliverAppBarVariant.small;
    // The SDK asserts that snap is only used with floating.
    final snap = spec.floating && spec.snap;
    if (spec.snap && !spec.floating) {
      debugPrint("Warning: SliverAppBar(${control.id}) snap requires "
          "floating; ignoring snap.");
    }
    final toolbarHeight = spec.toolbarHeight ??
        (small ? kToolbarHeight : _collapsingToolbarHeight);
    var collapsedHeight = spec.collapsedHeight;
    // The SDK asserts collapsed_height >= toolbar_height.
    if (collapsedHeight != null && collapsedHeight < toolbarHeight) {
      debugPrint("Warning: SliverAppBar(${control.id}) collapsed_height "
          "$collapsedHeight is below toolbar_height $toolbarHeight; "
          "using $toolbarHeight.");
      collapsedHeight = toolbarHeight;
    }
    final bottom = spec.bottom;

    var title = spec.title;
    FlexibleSpaceBar? flexibleSpace;
    var expandedHeight = spec.expandedHeight;
    if (spec.flexibleSpace != null) {
      // The title collapses with the flexible space instead of the toolbar.
      flexibleSpace =
          FlexibleSpaceBar(title: title, background: spec.flexibleSpace);
      title = null;
      if (small) {
        expandedHeight ??= 200 + (bottom == null ? 0 : spec.bottomHeight);
      }
    }
    final actions = spec.actions.isEmpty ? null : spec.actions;

    switch (spec.variant) {
      case SliverAppBarVariant.large:
        return SliverAppBar.large(
          leading: spec.leading,
          automaticallyImplyLeading: spec.automaticallyImplyLeading,
          title: title,
          actions: actions,
          flexibleSpace: flexibleSpace,
          bottom: bottom,
          elevation: spec.elevation,
          scrolledUnderElevation: spec.scrolledUnderElevation,
          shadowColor: spec.shadowColor,
          backgroundColor: spec.backgroundColor,
          foregroundColor: spec.foregroundColor,
          centerTitle: spec.centerTitle,
          collapsedHeight: collapsedHeight,
          expandedHeight: expandedHeight,
          floating: spec.floating,
          pinned: spec.pinned,
          snap: snap,
          stretch: spec.stretch,
          toolbarHeight: toolbarHeight,
        );
      case SliverAppBarVariant.medium:
        return SliverAppBar.medium(
          leading: spec.leading,
          automaticallyImplyLeading: spec.automaticallyImplyLeading,
          title: title,
          actions: actions,
          flexibleSpace: flexibleSpace,
          bottom: bottom,
          elevation: spec.elevation,
          scrolledUnderElevation: spec.scrolledUnderElevation,
          shadowColor: spec.shadowColor,
          backgroundColor: spec.backgroundColor,
          foregroundColor: spec.foregroundColor,
          centerTitle: spec.centerTitle,
          collapsedHeight: collapsedHeight,
          expandedHeight: expandedHeight,
          floating: spec.floating,
          pinned: spec.pinned,
          snap: snap,
          stretch: spec.stretch,
          toolbarHeight: toolbarHeight,
        );
      case SliverAppBarVariant.small:
        return SliverAppBar(
          leading: spec.leading,
          automaticallyImplyLeading: spec.automaticallyImplyLeading,
          title: title,
          actions: actions,
          flexibleSpace: flexibleSpace,
          bottom: bottom,
          elevation: spec.elevation,
          scrolledUnderElevation: spec.scrolledUnderElevation,
          shadowColor: spec.shadowColor,
          backgroundColor: spec.backgroundColor,
          foregroundColor: spec.foregroundColor,
          centerTitle: spec.centerTitle,
          collapsedHeight: collapsedHeight,
          expandedHeight: expandedHeight,
          floating: spec.floating,
          pinned: spec.pinned,
          snap: snap,
          stretch: spec.stretch,
          toolbarHeight: toolbarHeight,
        );
    }
  }
}
