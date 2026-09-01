import 'package:flutter/cupertino.dart';

import '../extensions/control.dart';
import '../models/control.dart';
import '../utils/edge_insets.dart';
import '../utils/misc.dart';
import '../utils/numbers.dart';
import '../widgets/reorderable_item_scope.dart';
import 'base_controls.dart';
import 'control_widget.dart';
import 'scroll_notification_control.dart';

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
    Widget content = ReorderableItemScope(
      key: key,
      index: index,
      child: ControlWidget(key: key, control: item),
    );
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
    Widget list = ReorderableList(
      controller: _controller,
      scrollDirection: direction,
      reverse: widget.control.getBool("reverse", false)!,
      shrinkWrap: true,
      anchor: widget.control.getDouble("anchor", 0)!,
      cacheExtent: widget.control.getDouble("cache_extent"),
      padding: widget.control.getPadding("padding"),
      clipBehavior:
          widget.control.getClipBehavior("clip_behavior", Clip.hardEdge)!,
      itemExtent: widget.control.getDouble("item_extent"),
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
