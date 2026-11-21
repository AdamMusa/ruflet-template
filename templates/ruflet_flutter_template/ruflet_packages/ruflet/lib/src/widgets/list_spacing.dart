import 'package:flutter/widgets.dart';

/// The gap ListView puts between items for Ruby `spacing`, with an optional
/// centered line `divider_thickness` thick (same look as ListView).
Widget listItemSeparator(
    {required bool horizontal,
    required double spacing,
    required double dividerThickness}) {
  final gap = SizedBox(
      width: horizontal ? spacing : null, height: horizontal ? null : spacing);
  if (dividerThickness == 0) return gap;
  return SizedBox(
    width: horizontal ? spacing : null,
    height: horizontal ? null : spacing,
    child: Center(
      child: SizedBox(
        width: horizontal ? dividerThickness : double.infinity,
        height: horizontal ? double.infinity : dividerThickness,
        child: const ColoredBox(color: Color(0x1F000000)),
      ),
    ),
  );
}

/// Reorderable lists have no separator builder and move each item as one
/// widget, so the separator after an item is laid out inside it.
Widget withListItemSeparator(Widget item,
        {required bool horizontal,
        required double spacing,
        required double dividerThickness}) =>
    Flex(
      direction: horizontal ? Axis.horizontal : Axis.vertical,
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        item,
        listItemSeparator(
            horizontal: horizontal,
            spacing: spacing,
            dividerThickness: dividerThickness),
      ],
    );
