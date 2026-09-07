import 'dart:math' as math;

import 'package:ruflet/ruflet.dart';
import 'package:ruflet/src/controls/cupertino_control_chrome.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

/// Cupertino's table renderer owns its cells, selection controls and scrolling.
/// No Material DataTable, theme, ink response or checkbox is mounted here.
class CupertinoDataTable2Control extends StatefulWidget {
  final Control control;

  const CupertinoDataTable2Control({super.key, required this.control});

  @override
  State<CupertinoDataTable2Control> createState() =>
      _CupertinoDataTable2ControlState();
}

class _CupertinoDataTable2ControlState
    extends State<CupertinoDataTable2Control> {
  final _horizontal = ScrollController();
  final _fixedHorizontal = ScrollController();
  final _vertical = ScrollController();
  final _fixedVertical = ScrollController();
  bool _syncing = false;

  Control get control => widget.control;

  @override
  void initState() {
    super.initState();
    _horizontal.addListener(() => _sync(_horizontal, _fixedHorizontal));
    _fixedHorizontal.addListener(() => _sync(_fixedHorizontal, _horizontal));
    _vertical.addListener(() => _sync(_vertical, _fixedVertical));
    _fixedVertical.addListener(() => _sync(_fixedVertical, _vertical));
  }

  void _sync(ScrollController source, ScrollController target) {
    if (_syncing || !target.hasClients || !source.hasClients) return;
    _syncing = true;
    target.jumpTo(source.offset.clamp(
        target.position.minScrollExtent, target.position.maxScrollExtent));
    _syncing = false;
  }

  @override
  void dispose() {
    _horizontal.dispose();
    _fixedHorizontal.dispose();
    _vertical.dispose();
    _fixedVertical.dispose();
    super.dispose();
  }

  void _selectAll(List<Control> rows, bool? selected) {
    if (control.hasEventHandler('select_all')) {
      control.triggerEvent('select_all', selected);
    } else {
      for (final row in rows.where((r) => r.hasEventHandler('select_change'))) {
        if (row.getBool('selected', false) != selected) {
          row.triggerEvent('select_change', selected);
        }
      }
    }
  }

  Color? _stateColor(Control source, String name,
          {bool selected = false, Set<WidgetState> states = const {}}) =>
      source.getWidgetStateColor(name, RufletStyleTheme.of(context))?.resolve({
        ...states,
        if (source.disabled) WidgetState.disabled,
        if (selected) WidgetState.selected,
      });

  Widget _checkbox(
      {required bool? selected,
      bool heading = false,
      ValueChanged<bool?>? onChanged}) {
    final raw = control
        .get(heading ? 'heading_checkbox_theme' : 'data_row_checkbox_theme');
    final style = raw is Map ? raw : const {};
    final theme = RufletStyleTheme.of(context);
    final states = <WidgetState>{
      if (selected == true) WidgetState.selected,
      if (onChanged == null || control.disabled) WidgetState.disabled,
    };
    return Align(
      alignment: control.getAlignment('checkbox_alignment', Alignment.center)!,
      child: CupertinoCheckbox(
        value: selected,
        tristate: heading,
        fillColor: parseWidgetStateColor(style['fill_color'], theme),
        checkColor:
            parseWidgetStateColor(style['check_color'], theme)?.resolve(states),
        side: parseBorderSide(style['border_side'], theme),
        shape: parseShape(style['shape'], theme),
        mouseCursor:
            parseWidgetStateMouseCursor(style['mouse_cursor'])?.resolve(states),
        onChanged: control.disabled || onChanged == null
            ? null
            : (value) => onChanged(heading ? selected != true : value),
      ),
    );
  }

  Widget _heading(Control column, int index) {
    final active = control.getInt('sort_column_index') == index;
    final ascending = control.getBool('sort_ascending', false)!;
    Widget label = Row(
      mainAxisAlignment: column.getMainAxisAlignment('heading_row_alignment') ??
          (column.getBool('numeric', false)!
              ? MainAxisAlignment.end
              : MainAxisAlignment.start),
      children: [
        Flexible(child: column.buildTextOrWidget('label') ?? const SizedBox()),
        if (active)
          AnimatedRotation(
            turns: ascending ? 0 : .5,
            duration: control.getDuration('sort_arrow_animation_duration',
                const Duration(milliseconds: 150))!,
            child: Icon(
              control.getIconData('sort_arrow_icon') ?? CupertinoIcons.arrow_up,
              size: 16,
              color: control.getColor('sort_arrow_icon_color', context) ??
                  CupertinoTheme.of(context).primaryColor,
            ),
          ),
      ],
    );
    final sort = column.hasEventHandler('sort') && !control.disabled
        ? () => column.triggerEvent(
            'sort', {'ci': index, 'asc': active ? !ascending : true})
        : null;
    label = _keyboardAction(
        sort,
        Semantics(
          button: column.hasEventHandler('sort'),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: sort,
            child: label,
          ),
        ));
    if (column.get('tooltip') != null) {
      label = CupertinoControlTooltip(control: column, child: label);
    }
    return label;
  }

  Widget _cell(Control row, Control cell, Control column) {
    Widget child = Row(
      mainAxisAlignment: column.getBool('numeric', false)!
          ? MainAxisAlignment.end
          : MainAxisAlignment.start,
      children: [
        Flexible(child: cell.buildWidget('content') ?? const SizedBox()),
        if (cell.getBool('show_edit_icon', false)!)
          const Padding(
            padding: EdgeInsetsDirectional.only(start: 8),
            child: Icon(CupertinoIcons.pencil, size: 18),
          ),
      ],
    );
    if (cell.getBool('placeholder', false)!) {
      child = Opacity(opacity: .6, child: child);
    }
    final handlesCell = [
      'tap',
      'double_tap',
      'long_press',
      'tap_down',
      'tap_cancel'
    ].any(cell.hasEventHandler);
    if (!handlesCell) return child;
    // DataTable2 intentionally emits the cell callback followed by its row
    // callback. Keep that wire behavior for each native cell interaction.
    void emit(String event) {
      cell.triggerEvent(event);
      row.triggerEvent(event);
    }

    return _keyboardAction(
        () => emit('tap'),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => emit('tap'),
          onDoubleTap: () => emit('double_tap'),
          onLongPress: () => emit('long_press'),
          onSecondaryTap: row.hasEventHandler('secondary_tap')
              ? () => row.triggerEvent('secondary_tap')
              : null,
          onSecondaryTapDown: row.hasEventHandler('secondary_tap_down')
              ? (details) =>
                  row.triggerEvent('secondary_tap_down', details.toMap())
              : null,
          onTapCancel: cell.hasEventHandler('tap_cancel')
              ? () => cell.triggerEvent('tap_cancel')
              : null,
          onTapDown: cell.hasEventHandler('tap_down')
              ? (details) => cell.triggerEvent('tap_down', details.toMap())
              : null,
          child: child,
        ));
  }

  Widget _keyboardAction(VoidCallback? action, Widget child) =>
      FocusableActionDetector(
        enabled: action != null && !control.disabled,
        shortcuts: const {
          SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
          SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
        },
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) {
            action?.call();
            return null;
          })
        },
        child: child,
      );

  Widget _rowGesture(Control row, Widget child) => Semantics(
        selected: row.getBool('selected', false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: row.hasEventHandler('tap')
              ? () => row.triggerEvent('tap')
              : row.hasEventHandler('select_change')
                  ? () => row.triggerEvent(
                      'select_change', !row.getBool('selected', false)!)
                  : null,
          onLongPress: row.hasEventHandler('long_press')
              ? () => row.triggerEvent('long_press')
              : null,
          onDoubleTap: row.hasEventHandler('double_tap')
              ? () => row.triggerEvent('double_tap')
              : null,
          onSecondaryTap: row.hasEventHandler('secondary_tap')
              ? () => row.triggerEvent('secondary_tap')
              : null,
          onSecondaryTapDown: row.hasEventHandler('secondary_tap_down')
              ? (details) =>
                  row.triggerEvent('secondary_tap_down', details.toMap())
              : null,
          child: child,
        ),
      );

  @override
  Widget build(BuildContext context) {
    final columns = control.children('columns');
    final rows = control.children('rows');
    for (final node in [
      ...columns,
      ...rows,
      ...rows.expand((r) => r.children('cells'))
    ]) {
      node.notifyParent = true;
    }
    final selectable =
        rows.where((r) => r.hasEventHandler('select_change')).toList();
    final checkboxes = control.getBool('show_checkbox_column', false)! &&
        selectable.isNotEmpty;
    final selected =
        selectable.where((r) => r.getBool('selected', false)!).length;
    final theme = RufletStyleTheme.of(context);
    final separator = CupertinoColors.separator.resolveFrom(context);
    final horizontalLine = control.getBorderSide('horizontal_lines', theme) ??
        BorderSide(
            color: separator,
            width: control.getDouble('divider_thickness', 1)!);
    final verticalLine = control.getBorderSide('vertical_lines', theme);
    final headingHeight = control.getDouble('heading_row_height', 56)!;
    final rowHeights = [
      headingHeight,
      ...rows.map((r) =>
          r.getDouble('specific_row_height') ??
          control.getDouble('data_row_height', 48)!)
    ];
    final fixedRows =
        control.getInt('fixed_top_rows', 1)!.clamp(0, rowHeights.length);
    final headerHeight = rowHeights.take(fixedRows).fold(0.0, (a, b) => a + b);
    final margin = control.getDouble('horizontal_margin', 24)!;
    final spacing = control.getDouble('column_spacing', 56)!;
    final checkboxWidth =
        40 + 2 * control.getDouble('checkbox_horizontal_margin', margin)!;

    Widget table = LayoutBuilder(builder: (context, constraints) {
      final viewWidth =
          constraints.hasBoundedWidth ? constraints.maxWidth : 600.0;
      final requestedWidth =
          math.max(viewWidth, control.getDouble('min_width', viewWidth)!);
      final explicitWidths = columns.fold(
          0.0, (sum, c) => sum + (c.getDouble('fixed_width') ?? 0));
      double weight(Control column) =>
          switch (column.getString('size', 's')!.toLowerCase()) {
            'm' => 1,
            'l' => control.getDouble('lm_ratio', 1.2)!,
            _ => control.getDouble('sm_ratio', .67)!,
          };
      final flexibleColumns =
          columns.where((c) => c.getDouble('fixed_width') == null);
      final totalWeight =
          flexibleColumns.fold(0.0, (sum, c) => sum + weight(c));
      final flexibleSpace = math.max(0.0,
          requestedWidth - explicitWidths - (checkboxes ? checkboxWidth : 0));
      final widths = [
        if (checkboxes) checkboxWidth,
        ...columns.map((c) =>
            c.getDouble('fixed_width') ??
            (totalWeight == 0 ? 0.0 : flexibleSpace * weight(c) / totalWeight))
      ];
      final tableWidth = widths.fold(0.0, (a, b) => a + b);
      final fixedColumns =
          control.getInt('fixed_left_columns', 0)!.clamp(0, widths.length);
      final fixedWidth = widths.take(fixedColumns).fold(0.0, (a, b) => a + b);
      final remainingWidth = math.max(0.0, tableWidth - fixedWidth);

      Widget makeRow(int rowIndex, int start, int end) {
        final heading = rowIndex == 0;
        final row = heading ? null : rows[rowIndex - 1];
        final isSelected = row?.getBool('selected', false) ?? false;
        return _TableStateRegion(builder: (states) {
          final fixed = start == 0 && fixedColumns > 0;
          final background = fixed && rowIndex < fixedRows
              ? control.getColor('fixed_corner_color', context)
              : fixed
                  ? control.getColor('fixed_columns_color', context)
                  : null;
          final rowColor = background ??
              (heading
                  ? _stateColor(control, 'heading_row_color', states: states)
                  : _stateColor(row!, 'color',
                          selected: isSelected, states: states) ??
                      _stateColor(control, 'data_row_color',
                          selected: isSelected, states: states)) ??
              (isSelected
                  ? CupertinoTheme.of(context)
                      .primaryColor
                      .withValues(alpha: .12)
                  : null);
          final cells = row?.children('cells') ?? const <Control>[];
          Widget content = Row(children: [
            for (var col = start; col < end; col++)
              Container(
                width: widths[col],
                height: rowHeights[rowIndex],
                padding: checkboxes && col == 0
                    ? EdgeInsets.zero
                    : EdgeInsetsDirectional.only(
                        start:
                            col == (checkboxes ? 1 : 0) ? margin : spacing / 2,
                        end: col == widths.length - 1 ? margin : spacing / 2),
                decoration: BoxDecoration(
                    border: BorderDirectional(
                        end: col < widths.length - 1
                            ? verticalLine ?? BorderSide.none
                            : BorderSide.none)),
                child: checkboxes && col == 0
                    ? heading
                        ? control.getBool('show_heading_checkbox', true)!
                            ? _checkbox(
                                heading: true,
                                selected: selected == 0
                                    ? false
                                    : selected == selectable.length
                                        ? true
                                        : null,
                                onChanged: (value) =>
                                    _selectAll(rows, value ?? true))
                            : const SizedBox()
                        : _checkbox(
                            selected: isSelected,
                            onChanged: row!.hasEventHandler('select_change')
                                ? (value) =>
                                    row.triggerEvent('select_change', value)
                                : null)
                    : heading
                        ? _heading(columns[col - (checkboxes ? 1 : 0)],
                            col - (checkboxes ? 1 : 0))
                        : _cell(row!, cells[col - (checkboxes ? 1 : 0)],
                            columns[col - (checkboxes ? 1 : 0)]),
              ),
          ]);
          content = DefaultTextStyle(
            style: control.getTextStyle(
                    heading ? 'heading_text_style' : 'data_text_style',
                    theme) ??
                CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                    fontWeight: heading ? FontWeight.w600 : FontWeight.normal),
            child: content,
          );
          content = Container(
            key: ValueKey(
                'table-pane-${fixed ? 'fixed' : 'scroll'}-${row?.id ?? 'heading'}'),
            decoration: (heading
                    ? control.getBoxDecoration(
                        'heading_row_decoration', context)
                    : row!.getBoxDecoration('decoration', context)) ??
                BoxDecoration(color: rowColor),
            foregroundDecoration: BoxDecoration(
                border: Border(
                    bottom: rowIndex < rows.length ||
                            control.getBool('show_bottom_border', false)!
                        ? horizontalLine
                        : BorderSide.none)),
            child: content,
          );
          return row == null ? content : _rowGesture(row, content);
        });
      }

      Widget pane(int fromRow, int toRow, int fromCol, int toCol) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var r = fromRow; r < toRow; r++) makeRow(r, fromCol, toCol)
            ],
          );

      final bodyHeight = math.max(
          0.0,
          (constraints.hasBoundedHeight
                  ? constraints.maxHeight
                  : rowHeights.fold(0.0, (a, b) => a + b) +
                      control.getDouble('bottom_margin', 0)!) -
              headerHeight);
      Widget body = SingleChildScrollView(
        controller: _horizontal,
        scrollDirection: Axis.horizontal,
        child: SizedBox(
            width: remainingWidth,
            child: SingleChildScrollView(
              controller: _vertical,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                pane(fixedRows, rowHeights.length, fixedColumns, widths.length),
                if (rows.isEmpty)
                  control.buildWidget('empty') ?? const SizedBox(),
                SizedBox(height: control.getDouble('bottom_margin', 0)!),
              ]),
            )),
      );
      body = CupertinoScrollbar(
        controller: _vertical,
        thumbVisibility: control.getBool('visible_vertical_scroll_bar', false),
        notificationPredicate: (n) => n.metrics.axis == Axis.vertical,
        child: CupertinoScrollbar(
          controller: _horizontal,
          thumbVisibility:
              control.getBool('visible_horizontal_scroll_bar', false),
          notificationPredicate: (n) => n.metrics.axis == Axis.horizontal,
          child: body,
        ),
      );
      return SizedBox(
          width: viewWidth,
          height: headerHeight + bodyHeight,
          child: Column(children: [
            if (fixedRows > 0)
              SizedBox(
                  height: headerHeight,
                  child: Row(children: [
                    if (fixedColumns > 0)
                      SizedBox(
                          width: fixedWidth,
                          child: pane(0, fixedRows, 0, fixedColumns)),
                    Expanded(
                        child: SingleChildScrollView(
                      controller: _fixedHorizontal,
                      scrollDirection: Axis.horizontal,
                      child: SizedBox(
                          width: remainingWidth,
                          child:
                              pane(0, fixedRows, fixedColumns, widths.length)),
                    )),
                  ])),
            SizedBox(
                height: bodyHeight,
                child: Row(children: [
                  if (fixedColumns > 0)
                    SizedBox(
                        width: fixedWidth,
                        child: SingleChildScrollView(
                          controller: _fixedVertical,
                          child:
                              Column(mainAxisSize: MainAxisSize.min, children: [
                            pane(fixedRows, rowHeights.length, 0, fixedColumns),
                            SizedBox(
                                height: control.getDouble('bottom_margin', 0)!),
                          ]),
                        )),
                  Expanded(child: body),
                ])),
          ]));
    });
    table = Container(
      decoration: BoxDecoration(
        color: control.getColor('bgcolor', context),
        border: control.getBorder('border', theme),
        borderRadius: control.getBorderRadius('border_radius'),
        gradient: control.getGradient('gradient', theme),
      ),
      clipBehavior: control.getClipBehavior('clip_behavior', Clip.none)!,
      child: IgnorePointer(ignoring: control.disabled, child: table),
    );
    return LayoutControl(control: control, child: table);
  }
}

class _TableStateRegion extends StatefulWidget {
  final Widget Function(Set<WidgetState>) builder;
  const _TableStateRegion({required this.builder});
  @override
  State<_TableStateRegion> createState() => _TableStateRegionState();
}

class _TableStateRegionState extends State<_TableStateRegion> {
  final _states = <WidgetState>{};
  void _set(WidgetState state, bool value) {
    if (_states.contains(state) == value) return;
    setState(() => value ? _states.add(state) : _states.remove(state));
  }

  @override
  Widget build(BuildContext context) => MouseRegion(
        onEnter: (_) => _set(WidgetState.hovered, true),
        onExit: (_) => _set(WidgetState.hovered, false),
        child: Listener(
          onPointerDown: (_) => _set(WidgetState.pressed, true),
          onPointerUp: (_) => _set(WidgetState.pressed, false),
          onPointerCancel: (_) => _set(WidgetState.pressed, false),
          child: Focus(
            canRequestFocus: false,
            onFocusChange: (value) => _set(WidgetState.focused, value),
            child: widget.builder(_states),
          ),
        ),
      );
}
