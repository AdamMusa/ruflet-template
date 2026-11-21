import 'package:flutter/cupertino.dart';

import '../extensions/control.dart';
import '../models/control.dart';
import '../utils/borders.dart';
import '../utils/colors.dart';
import '../utils/edge_insets.dart';
import '../utils/list_section.dart';
import '../utils/numbers.dart';
import '../widgets/error.dart';
import 'base_controls.dart';

// CupertinoListSection defaults that its non-nullable parameters need again
// when Ruby leaves a value unset (Flutter 3.41 cupertino/list_section.dart).
const double _kBaseTopMargin = 22.0;
const EdgeInsets _kBaseRowsMargin = EdgeInsets.only(bottom: 8.0);
// Separators start where a Ruflet ListTile title starts. Ruflet tiles use the
// non-notched iOS geometry (20 padding, 28 leading, 16 gap) in both variants,
// so the SDK's insetGrouped defaults (14 + 42, sized for notched tiles) would
// leave every separator 8pt short of the titles above it.
const double _kDividerMargin = 20.0;
const double _kAdditionalDividerMarginWithLeading = 44.0;
const BorderRadius _kInsetGroupedBorderRadius =
    BorderRadius.all(Radius.circular(10.0));

/// iOS grouped rows: [CupertinoListSection] (`base`) or
/// [CupertinoListSection.insetGrouped] (`insetGrouped`, the default).
class CupertinoListSectionControl extends StatelessWidget {
  final Control control;

  const CupertinoListSectionControl({super.key, required this.control});

  @override
  Widget build(BuildContext context) {
    debugPrint("CupertinoListSection build: ${control.id}");

    final header = control.buildTextOrWidget("header");
    final footer = control.buildTextOrWidget("footer");
    // Rows span the section like Material's stretched column, so a plain
    // Text or Switch row starts at the leading edge instead of centering.
    List<Widget> rows = [
      for (final row in control.buildWidgets("controls"))
        SizedBox(width: double.infinity, child: row)
    ];
    if (rows.isEmpty && header == null) {
      return const ErrorControl("ListSection needs controls or a header");
    }

    final inset = control.getListSectionVariant("variant") ==
        ListSectionVariant.insetGrouped;
    final rowsColor = control.getColor("rows_bgcolor", context);
    final radius = control.getBorderRadius("border_radius");
    var clipBehavior = control.getSectionClipBehavior(
        "clip_behavior", inset ? Clip.hardEdge : Clip.none)!;

    // `decoration` replaces the SDK's rounded rows background entirely, so it
    // is only supplied when Ruby customizes it, and then keeps the rounding.
    BoxDecoration? decoration;
    if (rowsColor != null || radius != null) {
      decoration = BoxDecoration(
        color: rowsColor ??
            CupertinoColors.secondarySystemGroupedBackground
                .resolveFrom(context),
        borderRadius:
            radius ?? (inset ? _kInsetGroupedBorderRadius : BorderRadius.zero),
      );
    }
    // The SDK always clips rows to its own 10pt radius. A Ruby radius clips
    // the first and last rows to that radius instead, so a tapped row's
    // highlight follows the corners that are drawn.
    if (radius != null && clipBehavior != Clip.none) {
      rows = _clipEdgeRows(rows, radius, clipBehavior);
      clipBehavior = Clip.none;
    }

    final backgroundColor = control.getColor("bgcolor", context) ??
        CupertinoColors.systemGroupedBackground;
    final margin = control.getMargin("margin");
    final dividerMargin = control.getDouble("divider_margin");
    final hasLeading = control.getBool("has_leading", true)!;
    final additionalDividerMargin = control.getDouble(
        "additional_divider_margin",
        hasLeading ? _kAdditionalDividerMarginWithLeading : 0.0);
    final separatorColor = control.getColor("separator_color", context);
    final children = rows.isEmpty ? null : rows;

    final topMargin = control.getDouble("top_margin");

    Widget section = inset
        ? CupertinoListSection.insetGrouped(
            header: header,
            footer: footer,
            margin: margin,
            backgroundColor: backgroundColor,
            decoration: decoration,
            clipBehavior: clipBehavior,
            dividerMargin: dividerMargin ?? _kDividerMargin,
            additionalDividerMargin: additionalDividerMargin,
            hasLeading: hasLeading,
            separatorColor: separatorColor,
            children: children,
          )
        : CupertinoListSection(
            header: header,
            footer: footer,
            margin: margin ?? _kBaseRowsMargin,
            backgroundColor: backgroundColor,
            decoration: decoration,
            clipBehavior: clipBehavior,
            dividerMargin: dividerMargin ?? _kDividerMargin,
            additionalDividerMargin: additionalDividerMargin,
            topMargin: topMargin ?? _kBaseTopMargin,
            hasLeading: hasLeading,
            separatorColor: separatorColor,
            children: children,
          );

    // CupertinoListSection.insetGrouped accepts but never applies topMargin;
    // Ruby's top_margin adds the same grouped-background space on both variants.
    if (inset && topMargin != null) {
      section = ColoredBox(
        color: CupertinoDynamicColor.resolve(backgroundColor, context),
        child:
            Padding(padding: EdgeInsets.only(top: topMargin), child: section),
      );
    }

    return LayoutControl(
      control: control,
      skipProperties: const {"margin"},
      child: section,
    );
  }
}

List<Widget> _clipEdgeRows(
    List<Widget> rows, BorderRadius radius, Clip clipBehavior) {
  final last = rows.length - 1;
  return [
    for (var i = 0; i < rows.length; i++)
      if (i == 0 || i == last)
        ClipRRect(
          clipBehavior: clipBehavior,
          borderRadius: BorderRadius.only(
            topLeft: i == 0 ? radius.topLeft : Radius.zero,
            topRight: i == 0 ? radius.topRight : Radius.zero,
            bottomLeft: i == last ? radius.bottomLeft : Radius.zero,
            bottomRight: i == last ? radius.bottomRight : Radius.zero,
          ),
          child: rows[i],
        )
      else
        rows[i],
  ];
}
