import 'package:flutter/widgets.dart';

import '../extensions/control.dart';
import '../models/control.dart';
import '../utils/borders.dart';
import '../utils/colors.dart';
import '../utils/enums.dart';
import '../utils/numbers.dart';
import '../utils/style_theme.dart';

/// Wire type of the collapsing app bar sliver built by CustomScrollView.
const String sliverAppBarType = "SliverAppBar";

enum SliverAppBarVariant { small, medium, large }

/// Ruby's `SliverAppBar` keywords, read once for both design renderers.
///
/// Keys that only one design honors are read here too, so both renderers
/// agree on names and defaults; each renderer maps what applies to it.
class SliverAppBarSpec {
  final SliverAppBarVariant variant;
  final Widget? title;
  final Widget? leading;
  final List<Widget> actions;
  final Widget? flexibleSpace;
  final Widget? bottomContent;
  final double bottomHeight;

  /// Explicit `pinned`, else medium and large pin and small scrolls away.
  final bool pinned;
  final bool floating;
  final bool snap;
  final bool stretch;
  final bool automaticallyImplyLeading;
  final Color? backgroundColor;

  // Material only.
  final double? expandedHeight;
  final double? collapsedHeight;
  final double? toolbarHeight;
  final Color? foregroundColor;
  final double? elevation;
  final double? scrolledUnderElevation;
  final Color? shadowColor;
  final bool? centerTitle;

  // Cupertino only.
  final String? previousPageTitle;
  final Border? border;
  final bool alwaysShowMiddle;
  final bool transitionBetweenRoutes;

  const SliverAppBarSpec._({
    required this.variant,
    required this.title,
    required this.leading,
    required this.actions,
    required this.flexibleSpace,
    required this.bottomContent,
    required this.bottomHeight,
    required this.pinned,
    required this.floating,
    required this.snap,
    required this.stretch,
    required this.automaticallyImplyLeading,
    required this.backgroundColor,
    required this.expandedHeight,
    required this.collapsedHeight,
    required this.toolbarHeight,
    required this.foregroundColor,
    required this.elevation,
    required this.scrolledUnderElevation,
    required this.shadowColor,
    required this.centerTitle,
    required this.previousPageTitle,
    required this.border,
    required this.alwaysShowMiddle,
    required this.transitionBetweenRoutes,
  });

  /// [borderTheme] resolves `border` colors; renderers that ignore `border`
  /// (Material) omit it.
  factory SliverAppBarSpec.read(Control bar, BuildContext context,
      {RufletStyleTheme? borderTheme}) {
    final variant = parseEnum(
        SliverAppBarVariant.values,
        bar.getString("variant")?.replaceAll("_", ""),
        SliverAppBarVariant.small)!;
    return SliverAppBarSpec._(
      variant: variant,
      title: bar.buildTextOrWidget("title"),
      leading: bar.buildWidget("leading"),
      actions: bar.buildWidgets("actions"),
      flexibleSpace: flexibleSpaceOf(bar),
      bottomContent: bar.buildWidget("bottom"),
      bottomHeight: bar.getDouble("bottom_height", 48)!,
      pinned: bar.getBool("pinned") ?? variant != SliverAppBarVariant.small,
      floating: bar.getBool("floating", false)!,
      snap: bar.getBool("snap", false)!,
      stretch: bar.getBool("stretch", false)!,
      automaticallyImplyLeading:
          bar.getBool("automatically_imply_leading", true)!,
      backgroundColor: bar.getColor("bgcolor", context),
      expandedHeight: bar.getDouble("expanded_height"),
      collapsedHeight: bar.getDouble("collapsed_height"),
      toolbarHeight: bar.getDouble("toolbar_height"),
      foregroundColor: bar.getColor("color", context),
      elevation: bar.getDouble("elevation"),
      scrolledUnderElevation: bar.getDouble("scrolled_under_elevation"),
      shadowColor: bar.getColor("shadow_color", context),
      centerTitle: bar.getBool("center_title"),
      previousPageTitle: bar.getString("previous_page_title"),
      border: borderTheme == null ? null : bar.getBorder("border", borderTheme),
      alwaysShowMiddle: bar.getBool("always_show_middle", true)!,
      // Off by default: a page app bar may also be a navigation hero.
      transitionBetweenRoutes: bar.getBool("transition_between_routes", false)!,
    );
  }

  /// `flexible_space` content (shown below the bar on iOS).
  static Widget? flexibleSpaceOf(Control bar) =>
      bar.buildWidget("flexible_space");

  /// `bottom` sized by `bottom_height` (both designs need a preferred size).
  PreferredSize? get bottom => bottomContent == null
      ? null
      : PreferredSize(
          preferredSize: Size.fromHeight(bottomHeight), child: bottomContent!);
}
