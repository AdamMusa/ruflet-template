import 'package:flutter/cupertino.dart';

import '../extensions/control.dart';
import '../models/control.dart';
import '../utils/colors.dart';
import '../utils/edge_insets.dart';
import '../utils/numbers.dart';
import '../widgets/error.dart';
import 'base_controls.dart';
import 'control_widget.dart';

class CupertinoChipControl extends StatelessWidget {
  final Control control;

  const CupertinoChipControl({super.key, required this.control});

  @override
  Widget build(BuildContext context) {
    final label = control.buildTextOrWidget("label");
    if (label == null) {
      return const ErrorControl("Chip.label must be provided and visible");
    }
    final selected = control.getBool("selected", false)!;
    final onSelect = control.getBool("on_select", false)!;
    final onClick = control.getBool("on_click", false)!;
    if (onSelect && onClick) {
      return const ErrorControl(
          "Chip cannot have both on_select and on_click events specified");
    }
    final leading = control.buildWidget("leading");
    final deleteIcon = control.buildWidget("delete_icon") ??
        const Icon(CupertinoIcons.xmark_circle_fill, size: 17);
    final chip = DecoratedBox(
      decoration: BoxDecoration(
        color: selected
            ? control.getColor("selected_color", context) ??
                CupertinoColors.activeBlue.resolveFrom(context)
            : control.getColor("bgcolor", context) ??
                CupertinoColors.systemGrey5.resolveFrom(context),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CupertinoButton(
            padding: control.getPadding(
                "padding", const EdgeInsets.symmetric(horizontal: 12)),
            onPressed: control.disabled || (!onSelect && !onClick)
                ? null
                : () {
                    if (onSelect) {
                      control.updateProperties({"selected": !selected},
                          notify: true);
                      control.triggerEvent("select", !selected);
                    } else {
                      control.triggerEvent("click");
                    }
                  },
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              if (leading != null) ...[leading, const SizedBox(width: 6)],
              label,
              if (selected && control.getBool("show_checkmark", true)!) ...[
                const SizedBox(width: 6),
                const Icon(CupertinoIcons.checkmark, size: 16),
              ],
            ]),
          ),
          if (control.getBool("on_delete", false)!)
            CupertinoButton(
              padding: const EdgeInsetsDirectional.only(end: 8),
              minimumSize: const Size.square(30),
              onPressed: control.disabled
                  ? null
                  : () => control.triggerEvent("delete"),
              child: deleteIcon,
            ),
        ],
      ),
    );
    return LayoutControl(control: control, child: chip);
  }
}

class CupertinoDataTableControl extends StatelessWidget {
  final Control control;

  const CupertinoDataTableControl({super.key, required this.control});

  Widget _cell(Control cell) {
    final child = cell.buildTextOrWidget("content") ?? const SizedBox.shrink();
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: cell.getBool("on_tap", false)!
          ? () => cell.triggerEvent("tap")
          : null,
      onDoubleTap: cell.getBool("on_double_tap", false)!
          ? () => cell.triggerEvent("double_tap")
          : null,
      onLongPress: cell.getBool("on_long_press", false)!
          ? () => cell.triggerEvent("long_press")
          : null,
      child: Padding(padding: const EdgeInsets.all(10), child: child),
    );
  }

  @override
  Widget build(BuildContext context) {
    final columns = control.children("columns");
    final rows = control.children("rows");
    if (columns.isEmpty) {
      return const ErrorControl("DataTable.columns must not be empty");
    }
    final borderColor = CupertinoColors.separator.resolveFrom(context);
    final tableRows = <TableRow>[
      TableRow(
        decoration: BoxDecoration(
          color: control.getColor("heading_row_color", context) ??
              CupertinoColors.secondarySystemBackground.resolveFrom(context),
        ),
        children: columns.indexed.map((entry) {
          final (index, column) = entry;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: column.getBool("on_sort", false)!
                ? () => column.triggerEvent("sort", {
                      "ci": index,
                      "asc": control.getBool("sort_ascending", false)
                    })
                : null,
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: DefaultTextStyle.merge(
                style: const TextStyle(fontWeight: FontWeight.w600),
                child: column.buildTextOrWidget("label") ??
                    const SizedBox.shrink(),
              ),
            ),
          );
        }).toList(),
      ),
      ...rows.map((row) => TableRow(
            decoration: BoxDecoration(
              color: row.getColor("color", context) ??
                  (row.getBool("selected", false)!
                      ? CupertinoColors.systemGrey5.resolveFrom(context)
                      : null),
            ),
            children: [
              for (var i = 0; i < columns.length; i++)
                i < row.children("cells").length
                    ? _cell(row.children("cells")[i])
                    : const SizedBox.shrink(),
            ],
          )),
    ];
    final table = SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Table(
        defaultColumnWidth: const IntrinsicColumnWidth(),
        border: TableBorder(
          horizontalInside: BorderSide(color: borderColor, width: 0.5),
          bottom: control.getBool("show_bottom_border", false)!
              ? BorderSide(color: borderColor, width: 0.5)
              : BorderSide.none,
        ),
        children: tableRows,
      ),
    );
    return LayoutControl(control: control, child: table);
  }
}

class CupertinoExpansionPanelListControl extends StatelessWidget {
  final Control control;

  const CupertinoExpansionPanelListControl({super.key, required this.control});

  @override
  Widget build(BuildContext context) {
    final panels = control.children("controls");
    final result = Column(
      mainAxisSize: MainAxisSize.min,
      children: panels.indexed.map((entry) {
        final (index, panel) = entry;
        final expanded = panel.getBool("expanded", false)!;
        return DecoratedBox(
          decoration: BoxDecoration(
            color: panel.getColor("bgcolor", context) ??
                CupertinoColors.secondarySystemBackground.resolveFrom(context),
            border: Border(
              bottom: BorderSide(
                  color: control.getColor("divider_color", context) ??
                      CupertinoColors.separator.resolveFrom(context),
                  width: 0.5),
            ),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            CupertinoButton(
              alignment: AlignmentDirectional.centerStart,
              onPressed: control.disabled
                  ? null
                  : () {
                      panel.updateProperties({"expanded": !expanded},
                          notify: true);
                      control.triggerEvent("change", index);
                    },
              child: Row(children: [
                Expanded(
                    child: panel.buildWidget("header") ?? const Text("Header")),
                Icon(expanded
                    ? CupertinoIcons.chevron_up
                    : CupertinoIcons.chevron_down),
              ]),
            ),
            if (expanded)
              Padding(
                padding: const EdgeInsets.all(12),
                child: panel.buildWidget("content") ?? const SizedBox.shrink(),
              ),
          ]),
        );
      }).toList(),
    );
    return LayoutControl(control: control, child: result);
  }
}

class CupertinoExpansionTileControl extends StatelessWidget {
  final Control control;

  const CupertinoExpansionTileControl({super.key, required this.control});

  @override
  Widget build(BuildContext context) {
    final title = control.buildTextOrWidget("title");
    if (title == null) {
      return const ErrorControl(
          "ExpansionTile.title must be provided and visible");
    }
    final expanded = control.getBool("expanded", false)!;
    final tile = DecoratedBox(
      decoration: BoxDecoration(
        color: control.getColor(
                expanded ? "bgcolor" : "collapsed_bgcolor", context) ??
            CupertinoColors.secondarySystemBackground.resolveFrom(context),
        border: Border(
          bottom: BorderSide(
              color: CupertinoColors.separator.resolveFrom(context),
              width: 0.5),
        ),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        CupertinoButton(
          alignment: AlignmentDirectional.centerStart,
          padding: control.getPadding("tile_padding", const EdgeInsets.all(12)),
          onPressed: control.disabled
              ? null
              : () {
                  control.updateProperties({"expanded": !expanded});
                  control.triggerEvent("change", !expanded);
                },
          child: Row(children: [
            if (control.buildIconOrWidget("leading") case final leading?) ...[
              leading,
              const SizedBox(width: 10)
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  title,
                  if (control.buildTextOrWidget("subtitle")
                      case final subtitle?)
                    subtitle,
                ],
              ),
            ),
            control.buildIconOrWidget("trailing") ??
                Icon(expanded
                    ? CupertinoIcons.chevron_up
                    : CupertinoIcons.chevron_down),
          ]),
        ),
        if (expanded)
          Padding(
            padding: control.getPadding("controls_padding", EdgeInsets.zero)!,
            child: Column(children: control.buildWidgets("controls")),
          ),
      ]),
    );
    return LayoutControl(control: control, child: tile);
  }
}

class CupertinoTabsControl extends StatefulWidget {
  final Control control;

  const CupertinoTabsControl({super.key, required this.control});

  @override
  State<CupertinoTabsControl> createState() => _CupertinoTabsControlState();
}

class _CupertinoTabsControlState extends State<CupertinoTabsControl> {
  late int selectedIndex;

  @override
  void initState() {
    super.initState();
    selectedIndex = widget.control.getInt("selected_index", 0)!;
    widget.control.addInvokeMethodListener(_invokeMethod);
  }

  Future<dynamic> _invokeMethod(String name, dynamic args) async {
    if (name != "move_to") throw Exception("Unknown Tabs method: $name");
    select(args["index"] as int);
  }

  void select(int index) {
    final length = widget.control.getInt("length", 0)!;
    if (length <= 0) return;
    final resolved = index < 0 ? length + index : index;
    final next = resolved.clamp(0, length - 1);
    if (next == selectedIndex) return;
    setState(() => selectedIndex = next);
    widget.control.updateProperties({"selected_index": next});
    widget.control.triggerEvent("change", next);
  }

  @override
  void dispose() {
    widget.control.removeInvokeMethodListener(_invokeMethod);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final backendIndex = widget.control.getInt("selected_index", 0)!;
    if (backendIndex != selectedIndex) selectedIndex = backendIndex;
    final content = widget.control.buildWidget("content");
    if (content == null) {
      return const ErrorControl("Tabs.content must be provided and visible");
    }
    return LayoutControl(control: widget.control, child: content);
  }
}

class CupertinoTabBarControl extends StatelessWidget {
  final Control control;

  const CupertinoTabBarControl({super.key, required this.control});

  @override
  Widget build(BuildContext context) {
    final tabs = context.findAncestorStateOfType<_CupertinoTabsControlState>();
    if (tabs == null) {
      return const ErrorControl("TabBar must be used within a Tabs control");
    }
    final tabControls = control.children("tabs");
    if (tabControls.isEmpty) {
      return const ErrorControl("TabBar.tabs must not be empty");
    }
    final segments = <int, Widget>{
      for (final (index, tab) in tabControls.indexed)
        index: tab.type == "Tab"
            ? CupertinoTabControl(control: tab)
            : ControlWidget(control: tab),
    };
    final bar = CupertinoSlidingSegmentedControl<int>(
      groupValue: tabs.selectedIndex.clamp(0, segments.length - 1),
      backgroundColor: control.getColor("bgcolor", context) ??
          CupertinoColors.systemGrey5.resolveFrom(context),
      thumbColor: control.getColor("indicator_color", context) ??
          CupertinoColors.systemBackground.resolveFrom(context),
      onValueChanged: (index) {
        if (index == null) return;
        tabs.select(index);
        control.triggerEvent("click", index);
      },
      children: segments,
    );
    return BaseControl(control: control, child: bar);
  }
}

class CupertinoTabBarViewControl extends StatelessWidget {
  final Control control;

  const CupertinoTabBarViewControl({super.key, required this.control});

  @override
  Widget build(BuildContext context) {
    final tabs = context.findAncestorStateOfType<_CupertinoTabsControlState>();
    if (tabs == null) {
      return const ErrorControl(
          "TabBarView must be used within a Tabs control");
    }
    final controls = control.buildWidgets("controls");
    if (controls.isEmpty) {
      return const ErrorControl("TabBarView.controls must not be empty");
    }
    final view = IndexedStack(
      index: tabs.selectedIndex.clamp(0, controls.length - 1),
      children: controls,
    );
    return LayoutControl(control: control, child: view);
  }
}

class CupertinoTabControl extends StatelessWidget {
  final Control control;

  const CupertinoTabControl({super.key, required this.control});

  @override
  Widget build(BuildContext context) {
    final icon = control.buildIconOrWidget("icon");
    final label = control.buildTextOrWidget("label");
    return BaseControl(
      control: control,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[icon, const SizedBox(width: 5)],
          if (label != null) Flexible(child: label),
        ]),
      ),
    );
  }
}
