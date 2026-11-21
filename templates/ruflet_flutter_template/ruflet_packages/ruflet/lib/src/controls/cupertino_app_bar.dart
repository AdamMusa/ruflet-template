import 'package:flutter/cupertino.dart';

import '../core/control_core.dart';
import '../utils/borders.dart' show parseBorder;
import '../utils/cupertino_theme.dart' show cupertinoStyleTheme;
import '../utils/edge_insets.dart' show parseEdgeInsetsDirectional;
import '../utils/platform_theme.dart' show parseBrightness;
import 'app_bar_core.dart';

/// Cupertino skin of [AppBarCore]: the scaffold's
/// ObstructingPreferredSizeWidget, a CupertinoNavigationBar (large when
/// `large`). It hosts the core its entry created.
class CupertinoAppBarSkin extends AppBarSkin
    implements ObstructingPreferredSizeWidget {
  const CupertinoAppBarSkin({super.key, required super.core});

  @override
  Widget build(BuildContext context) => CoreHost<AppBarCore>.adopt(
      core: core, builder: (context, core) => _bar(context, core));

  static Widget _bar(BuildContext context, AppBarCore core) {
    final p = core.props;
    final title = p.title?.build();
    final ends = core.endWidgets;
    final end = ends.isEmpty
        ? null
        : ends.length == 1
            ? ends.single
            : Row(mainAxisSize: MainAxisSize.min, children: ends);
    final border = parseBorder(p.border.value, cupertinoStyleTheme(context));
    final padding = parseEdgeInsetsDirectional(p.padding.value);
    final brightness = parseBrightness(p.barBrightness.string);
    return p.large
        ? CupertinoNavigationBar.large(
            leading: p.leading,
            automaticallyImplyLeading: p.automaticallyImplyLeading,
            automaticallyImplyTitle: p.automaticallyImplyTitle,
            transitionBetweenRoutes: p.transitionBetweenRoutes,
            border: border,
            previousPageTitle: p.previousPageTitle,
            padding: padding,
            backgroundColor: p.bgcolor,
            automaticBackgroundVisibility: p.automaticBackgroundVisibility,
            enableBackgroundFilterBlur: p.enableBackgroundFilterBlur,
            brightness: brightness,
            largeTitle: title,
            trailing: end)
        : CupertinoNavigationBar(
            leading: p.leading,
            automaticallyImplyLeading: p.automaticallyImplyLeading,
            automaticallyImplyMiddle: p.automaticallyImplyTitle,
            transitionBetweenRoutes: p.transitionBetweenRoutes,
            border: border,
            previousPageTitle: p.previousPageTitle,
            padding: padding,
            backgroundColor: p.bgcolor,
            automaticBackgroundVisibility: p.automaticBackgroundVisibility,
            enableBackgroundFilterBlur: p.enableBackgroundFilterBlur,
            brightness: brightness,
            middle: title,
            trailing: end);
  }

  @override
  Size get preferredSize {
    // Ask the SDK rather than duplicating its large-title height constants.
    return core.sizing.large
        ? const CupertinoNavigationBar.large(largeTitle: SizedBox())
            .preferredSize
        : const CupertinoNavigationBar().preferredSize;
  }

  @override
  bool shouldFullyObstruct(BuildContext context) {
    final Color backgroundColor = CupertinoDynamicColor.maybeResolve(
            core.backgroundIn(context), context) ??
        CupertinoTheme.of(context).barBackgroundColor;
    final alpha8 = (backgroundColor.a * 255.0).round().clamp(0, 255);
    return alpha8 == 0xFF;
  }
}
