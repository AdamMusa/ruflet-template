import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../models/control.dart';
import '../utils/colors.dart';
import '../utils/edge_insets.dart';
import '../utils/enums.dart';
import '../utils/numbers.dart';
import '../widgets/error.dart';
import 'base_controls.dart';
import 'control_widget.dart';

/// A plain (non-data) grid: Ruby `table` with `table_row` children whose
/// `controls` are the cells. Design-neutral.
class TableControl extends StatelessWidget {
  final Control control;

  const TableControl({super.key, required this.control});

  @override
  Widget build(BuildContext context) {
    debugPrint("Table build: ${control.id}");

    var rows = control.children("rows");
    if (rows.isEmpty) rows = control.children("controls");
    for (final row in rows) {
      if (row.type != "TableRow") {
        return LayoutControl(
          control: control,
          child: ErrorControl("Table.rows must contain only TableRow controls",
              description: "Build each row with table_row([...cells]), "
                  "not ${row.type}"),
        );
      }
    }

    // Hidden cells keep their slot so later cells stay in their column.
    final cells = [
      for (final row in rows) row.children("controls", visibleOnly: false)
    ];
    final columns = cells.fold<int>(0, (n, row) => math.max(n, row.length));
    final padding = control.getPadding("cell_padding");
    final alignment = parseEnum(
        TableCellVerticalAlignment.values,
        control.getString("default_vertical_alignment")?.replaceAll("_", ""),
        TableCellVerticalAlignment.top)!;

    Widget cell(Control? cell) {
      if (cell == null || !cell.visible) {
        // Flutter asserts that every row has the same number of cells, so
        // short rows are padded with empty cells.
        return const SizedBox.shrink();
      }
      final child = ControlWidget(control: cell);
      return padding == null
          ? KeyedSubtree(key: ValueKey(cell.id), child: child)
          : Padding(key: ValueKey(cell.id), padding: padding, child: child);
    }

    final table = Table(
      // A table whose rows are all empty would assert: render no rows.
      children: columns == 0
          ? const []
          : [
              for (var r = 0; r < rows.length; r++)
                TableRow(
                  key: ValueKey(rows[r].id),
                  decoration: _rowDecoration(context, rows[r]),
                  children: [
                    for (var c = 0; c < columns; c++)
                      cell(c < cells[r].length ? cells[r][c] : null),
                  ],
                ),
            ],
      columnWidths: _columnWidths(control.get("column_widths")),
      defaultColumnWidth: _columnWidth(control.get("default_column_width")) ??
          const FlexColumnWidth(),
      border: _border(context),
      defaultVerticalAlignment: alignment,
      textBaseline: alignment == TableCellVerticalAlignment.baseline
          ? TextBaseline.alphabetic
          : null,
    );

    return LayoutControl(control: control, child: table);
  }

  Decoration? _rowDecoration(BuildContext context, Control row) {
    final color = row.getColor("bgcolor", context);
    return color == null ? null : BoxDecoration(color: color);
  }

  TableBorder? _border(BuildContext context) {
    final color = control.getColor("border_color", context);
    if (color == null) return null;
    final side =
        BorderSide(color: color, width: control.getDouble("border_width", 1)!);
    final inner =
        control.getBool("inner_borders", true)! ? side : BorderSide.none;
    final radius = control.getDouble("border_radius");
    return TableBorder(
      top: side,
      right: side,
      bottom: side,
      left: side,
      horizontalInside: inner,
      verticalInside: inner,
      borderRadius:
          radius == null ? BorderRadius.zero : BorderRadius.circular(radius),
    );
  }
}

/// Ruby sends `{ "0" => { "type" => "fixed", "value" => 80 } }`; hash keys
/// arrive as strings.
Map<int, TableColumnWidth>? _columnWidths(dynamic value) {
  if (value is! Map) return null;
  final widths = <int, TableColumnWidth>{};
  value.forEach((key, spec) {
    final index = int.tryParse(key.toString());
    final width = _columnWidth(spec);
    if (index != null && index >= 0 && width != null) widths[index] = width;
  });
  return widths.isEmpty ? null : widths;
}

/// `{type: flex|fixed|fraction|intrinsic, value:}`; a bare number is a fixed
/// width and a bare type name uses that type's default value.
TableColumnWidth? _columnWidth(dynamic spec) {
  if (spec is num) return FixedColumnWidth(spec.toDouble());
  final type = (spec is Map ? spec["type"] : spec)?.toString().toLowerCase();
  final value = spec is Map ? parseDouble(spec["value"]) : null;
  switch (type) {
    case "flex":
      return FlexColumnWidth(value ?? 1);
    case "fixed":
      return value == null ? null : FixedColumnWidth(value);
    case "fraction":
      return value == null ? null : FractionColumnWidth(value);
    case "intrinsic":
      return IntrinsicColumnWidth(flex: value);
  }
  return null;
}
