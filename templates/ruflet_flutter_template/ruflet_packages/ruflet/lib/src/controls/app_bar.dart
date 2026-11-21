import 'package:flutter/material.dart';

import '../core/control_core.dart';
import '../utils/misc.dart' show parseClip;
import '../utils/theme.dart' show SystemUiOverlayStyleTheme;
import 'app_bar_core.dart';

/// Material skin of [AppBarCore]: the scaffold's PreferredSizeWidget, an
/// AppBar (with the Material 3 large title when `large`). It hosts the core
/// its entry created.
class MaterialAppBarSkin extends AppBarSkin {
  const MaterialAppBarSkin({super.key, required super.core});

  // Material 3 large top app bar, expanded state: a 64 dp toolbar plus an
  // 88 dp area holding the headline title (152 dp in total). Collapsing on
  // scroll belongs to SliverAppBar.
  static const double _largeToolbarHeight = 64;
  static const double _largeTitleHeight = 88;

  @override
  Size get preferredSize {
    final sizing = core.sizing;
    final toolbar = sizing.toolbarHeight ??
        (sizing.large ? _largeToolbarHeight : kToolbarHeight);
    return Size.fromHeight(toolbar + (sizing.large ? _largeTitleHeight : 0));
  }

  @override
  Widget build(BuildContext context) => CoreHost<AppBarCore>.adopt(
      core: core, builder: (context, core) => _bar(context, core));

  static Widget _bar(BuildContext context, AppBarCore core) {
    final p = core.props;
    final large = p.large;
    final title = p.title?.build();
    return AppBar(
      leading: p.leading,
      leadingWidth: p.leadingWidth,
      automaticallyImplyLeading: p.automaticallyImplyLeading,
      title: large ? null : title,
      bottom:
          large ? _largeTitle(context, title, p.color, p.titleTextStyle) : null,
      centerTitle: p.centerTitle,
      toolbarHeight:
          p.toolbarHeight ?? (large ? _largeToolbarHeight : kToolbarHeight),
      foregroundColor: p.color,
      backgroundColor: p.bgcolor,
      elevation: p.elevation,
      actions: core.endWidgets,
      systemOverlayStyle: Theme.of(context)
          .extension<SystemUiOverlayStyleTheme>()
          ?.systemUiOverlayStyle,
      shadowColor: p.shadowColor,
      scrolledUnderElevation: p.elevationOnScroll,
      forceMaterialTransparency: p.forceMaterialTransparency,
      primary: !p.secondary,
      titleSpacing: p.titleSpacing,
      excludeHeaderSemantics: p.excludeHeaderSemantics,
      clipBehavior: parseClip(p.clipBehavior.string),
      titleTextStyle: p.titleTextStyle,
      shape: p.shape,
      toolbarOpacity: p.toolbarOpacity ?? 1,
      toolbarTextStyle: p.toolbarTextStyle,
      actionsPadding: p.actionsPadding,
    );
  }

  /// The expanded large title, styled like Flutter's `SliverAppBar.large`.
  static PreferredSizeWidget _largeTitle(BuildContext context, Widget? title,
      Color? foregroundColor, TextStyle? titleTextStyle) {
    var theme = Theme.of(context);
    var appBarTheme = AppBarTheme.of(context);
    var style = titleTextStyle ??
        appBarTheme.titleTextStyle ??
        theme.textTheme.headlineMedium?.copyWith(
            color: foregroundColor ??
                appBarTheme.foregroundColor ??
                (theme.useMaterial3 ||
                        theme.colorScheme.brightness == Brightness.dark
                    ? theme.colorScheme.onSurface
                    : theme.colorScheme.onPrimary));

    return PreferredSize(
      preferredSize: const Size.fromHeight(_largeTitleHeight),
      child: Align(
        alignment: AlignmentDirectional.bottomStart,
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 28),
          child: DefaultTextStyle(
            style: style ?? const TextStyle(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            child: title ?? const SizedBox.shrink(),
          ),
        ),
      ),
    );
  }
}
