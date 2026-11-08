import 'package:flutter/widgets.dart';

import '../models/control.dart';
import '../models/page_design.dart';
import '../widgets/control_inherited_notifier.dart';
import '../widgets/platform_control_renderer.dart';
import '../widgets/platform_design.dart';
import 'cupertino_sliver_app_bar.dart';
import 'material_sliver_app_bar.dart';
import 'sliver_app_bar_spec.dart';

/// `SliverAppBar`: a collapsing app bar sliver inside a CustomScrollView.
///
/// Material renders [SliverAppBar] (small, medium or large). Cupertino renders
/// the iOS large title that collapses into the navigation bar for medium and
/// large, and a plain navigation bar sliver for small.
class AdaptiveSliverAppBarControl extends StatelessWidget {
  final Control control;

  const AdaptiveSliverAppBarControl({super.key, required this.control});

  @override
  Widget build(BuildContext context) {
    debugPrint("AdaptiveSliverAppBar build: ${control.id}");

    return PlatformControlRenderer(
      material: (_) => MaterialSliverAppBarControl(control: control),
      cupertino: (_) => CupertinoSliverAppBarControl(control: control),
    );
  }
}

/// The sliver that follows a SliverAppBar in its CustomScrollView.
///
/// Material shows `flexible_space` inside the collapsing bar, so this sliver
/// is empty there. iOS has no parallax flexible space (deferred): the content
/// scrolls as a plain box right below the navigation bar, which stays pinned.
/// It is always emitted, so a later `flexible_space` patch only rebuilds it.
class SliverAppBarFlexibleSpace extends StatelessWidget {
  final Control control;

  const SliverAppBarFlexibleSpace({super.key, required this.control});

  @override
  Widget build(BuildContext context) {
    return control.buildInControlContext((context) => SliverToBoxAdapter(
        child: effectivePageDesign(context) == PageDesign.cupertino
            ? SliverAppBarSpec.flexibleSpaceOf(control)
            : null));
  }
}
