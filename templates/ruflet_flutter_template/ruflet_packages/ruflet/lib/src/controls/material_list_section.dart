import 'package:flutter/material.dart';

import '../extensions/control.dart';
import '../models/control.dart';
import '../utils/borders.dart';
import '../utils/colors.dart';
import '../utils/edge_insets.dart';
import '../utils/list_section.dart';
import '../utils/numbers.dart';
import '../widgets/error.dart';
import 'base_controls.dart';

const EdgeInsets _kInsetMargin =
    EdgeInsets.symmetric(horizontal: 16, vertical: 8);
const double _kInsetRadius = 12.0;
const EdgeInsets _kHeaderPadding = EdgeInsets.fromLTRB(16, 16, 16, 8);
const EdgeInsets _kFooterPadding = EdgeInsets.fromLTRB(16, 8, 16, 0);
// A divider starts where a ListTile's title starts: after the 16 px content
// padding, plus a 40 px leading slot and 16 px gap when rows have leading.
const double _kDividerMargin = 16.0;
const double _kAdditionalDividerMarginWithLeading = 56.0;

/// Material grouped rows: an optional header, a card of rows separated by
/// inset dividers, and an optional footer.
class MaterialListSectionControl extends StatelessWidget {
  final Control control;

  const MaterialListSectionControl({super.key, required this.control});

  @override
  Widget build(BuildContext context) {
    debugPrint("MaterialListSection build: ${control.id}");

    final header = control.buildTextOrWidget("header");
    final footer = control.buildTextOrWidget("footer");
    final rows = control.buildWidgets("controls");
    if (rows.isEmpty && header == null) {
      return const ErrorControl("ListSection needs controls or a header");
    }

    final theme = Theme.of(context);
    final inset = control.getListSectionVariant("variant") ==
        ListSectionVariant.insetGrouped;
    final hasLeading = control.getBool("has_leading", true)!;
    final dividerIndent =
        control.getDouble("divider_margin", _kDividerMargin)! +
            control.getDouble("additional_divider_margin",
                hasLeading ? _kAdditionalDividerMarginWithLeading : 0.0)!;
    final separatorColor = control.getColor("separator_color", context);

    Widget? card;
    if (rows.isNotEmpty) {
      card = Material(
        type: MaterialType.card,
        color: control.getColor("rows_bgcolor", context) ??
            theme.colorScheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: control.getBorderRadius(
              "border_radius",
              inset
                  ? BorderRadius.circular(_kInsetRadius)
                  : BorderRadius.zero)!,
        ),
        clipBehavior: control.getSectionClipBehavior(
            "clip_behavior", inset ? Clip.antiAlias : Clip.none)!,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < rows.length; i++) ...[
              if (i > 0)
                Divider(
                  height: 1,
                  thickness: 1,
                  indent: dividerIndent,
                  endIndent: 0,
                  color: separatorColor,
                ),
              rows[i],
            ],
          ],
        ),
      );
    }

    final margin =
        control.getMargin("margin", inset ? _kInsetMargin : EdgeInsets.zero)! +
            EdgeInsets.only(top: control.getDouble("top_margin", 0)!);
    Widget section = Padding(
      padding: margin,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (header != null)
            Padding(
              padding: _kHeaderPadding,
              child: DefaultTextStyle.merge(
                style: theme.textTheme.titleSmall
                    ?.copyWith(color: theme.colorScheme.primary),
                child: header,
              ),
            ),
          if (card != null) card,
          if (footer != null)
            Padding(
              padding: _kFooterPadding,
              child: DefaultTextStyle.merge(
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                child: footer,
              ),
            ),
        ],
      ),
    );

    final bgcolor = control.getColor("bgcolor", context);
    if (bgcolor != null) {
      section = ColoredBox(color: bgcolor, child: section);
    }

    return LayoutControl(
      control: control,
      skipProperties: const {"margin"},
      child: section,
    );
  }
}
