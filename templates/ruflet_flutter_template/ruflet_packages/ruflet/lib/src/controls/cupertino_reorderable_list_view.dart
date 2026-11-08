import 'package:flutter/cupertino.dart';

import '../extensions/control.dart';
import '../models/control.dart';
import '../utils/edge_insets.dart';
import '../utils/misc.dart';
import '../utils/numbers.dart';
import '../widgets/list_spacing.dart';
import '../widgets/reorderable_item_scope.dart';
import 'base_controls.dart';
import 'control_widget.dart';
import 'scroll_notification_control.dart';
import 'scrollable_control.dart';

class CupertinoReorderableListViewControl extends StatefulWidget {
  final Control control;

  const CupertinoReorderableListViewControl({super.key, required this.control});

  @override
  State<CupertinoReorderableListViewControl> createState() =>
      _CupertinoReorderableListViewControlState();
}

class _CupertinoReorderableListViewControlState
    extends State<CupertinoReorderableListViewControl> {
  late final ScrollController _controller;
  late List<Control> _controls;

  @override
  void initState() {
    super.initState();
    _controller = ScrollController();
    _controls = [...widget.control.children("controls")];
  }

  @override
  void didUpdateWidget(
      covariant CupertinoReorderableListViewControl oldWidget) {
    super.didUpdateWidget(oldWidget);
    _controls = [...widget.control.children("controls")];
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _reorder(int oldIndex, int newIndex) {
    setState(() {
      if (oldIndex < newIndex) newIndex -= 1;
      final item = _controls.removeAt(oldIndex);
      _controls.insert(newIndex, item);
    });
    widget.control.triggerEvent(
        "reorder", {"old_index": oldIndex, "new_index": newIndex});
  }

  Widget _item(int index, bool defaultHandle) {
    final item = _controls[index];
    final key = ValueKey(item.get("key") ?? item.id);
    Widget child = ControlWidget(key: key, control: item);
    final spacing = widget.control.getDouble("spacing", 0)!;
    if (spacing > 0 && index < _controls.length - 1) {
      child = withListItemSeparator(child,
          horizontal: widget.control.getBool("horizontal", false)!,
          spacing: spacing,
          dividerThickness: widget.control.getDouble("divider_thickness", 0)!);
    }
    Widget content = ReorderableItemScope(key: key, index: index, child: child);
    if (defaultHandle) {
      content = ReorderableDelayedDragStartListener(
        key: key,
        index: index,
        enabled: !widget.control.disabled,
        child: content,
      );
    }
    return content;
  }

  @override
  Widget build(BuildContext context) {
    final horizontal = widget.control.getBool("horizontal", false)!;
    final direction = horizontal ? Axis.horizontal : Axis.vertical;
    final defaultHandles =
        widget.control.getBool("show_default_drag_handles", true)!;
    // As in ListView, spacing replaces fixed item extents.
    final spacing = widget.control.getDouble("spacing", 0)!;
    final prototype = widget.control.buildWidget("prototype_item") ??
        (widget.control.getBool("first_item_prototype", false)! &&
                _controls.isNotEmpty
            ? ControlWidget(control: _controls.first)
            : null);
    Widget list = ReorderableList(
      controller: _controller,
      scrollDirection: direction,
      keyboardDismissBehavior: widget.control
          .getKeyboardDismissBehavior("keyboard_dismiss_behavior"),
      reverse: widget.control.getBool("reverse", false)!,
      shrinkWrap: true,
      anchor: widget.control.getDouble("anchor", 0)!,
      cacheExtent: widget.control.getDouble("cache_extent"),
      padding: widget.control.getPadding("padding"),
      clipBehavior:
          widget.control.getClipBehavior("clip_behavior", Clip.hardEdge)!,
      itemExtent: spacing > 0 ? null : widget.control.getDouble("item_extent"),
      prototypeItem: spacing > 0 || prototype == null
          ? null
          : ReorderableItemScope(index: 0, child: prototype),
      autoScrollerVelocityScalar:
          widget.control.getDouble("auto_scroller_velocity_scalar"),
      itemCount: _controls.length,
      itemBuilder: (context, index) => _item(index, defaultHandles),
      onReorder: widget.control.disabled ? (_, __) {} : _reorder,
      onReorderStart: widget.control.disabled
          ? null
          : (index) => widget.control
              .triggerEvent("reorder_start", {"old_index": index}),
      onReorderEnd: widget.control.disabled
          ? null
          : (index) =>
              widget.control.triggerEvent("reorder_end", {"new_index": index}),
    );
    // Same wrapper as the Material renderer, so Ruby `scroll_to`,
    // `auto_scroll` and `scroll` work on iOS/macOS too.
    list = ScrollableControl(
        control: widget.control,
        scrollDirection: direction,
        scrollController: _controller,
        child: list);
    if (widget.control.getBool("on_scroll", false)!) {
      list = ScrollNotificationControl(control: widget.control, child: list);
    }
    final header = widget.control.buildWidget("header");
    final footer = widget.control.buildWidget("footer");
    if (header != null || footer != null) {
      list = horizontal
          ? Row(children: [
              if (header != null) header,
              list,
              if (footer != null) footer
            ])
          : Column(children: [
              if (header != null) header,
              list,
              if (footer != null) footer
            ]);
    }
    return LayoutControl(control: widget.control, child: list);
  }
}
