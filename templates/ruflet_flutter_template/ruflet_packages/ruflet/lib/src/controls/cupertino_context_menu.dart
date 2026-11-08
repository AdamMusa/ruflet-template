import 'package:flutter/cupertino.dart';

import '../extensions/control.dart';
import '../models/control.dart';
import '../utils/numbers.dart';
import '../widgets/error.dart';
import '../widgets/ruflet_store_mixin.dart';
import 'control_widget.dart';

class CupertinoContextMenuControl extends StatefulWidget {
  final Control control;

  CupertinoContextMenuControl({Key? key, required this.control})
      : super(key: key ?? ValueKey("control_${control.id}"));

  @override
  State<CupertinoContextMenuControl> createState() =>
      _CupertinoContextMenuControlState();
}

class _CupertinoContextMenuControlState
    extends State<CupertinoContextMenuControl> with RufletStoreMixin {
  @override
  void initState() {
    super.initState();
    widget.control.addInvokeMethodListener(_invokeMethod);
  }

  @override
  void dispose() {
    widget.control.removeInvokeMethodListener(_invokeMethod);
    super.dispose();
  }

  Future<dynamic> _invokeMethod(String name, dynamic args) async {
    switch (name) {
      case "open":
        // CupertinoContextMenu opens only from its own long-press gesture:
        // the open routine is private and there is no controller (Flutter
        // 3.41), mirroring UIKit, where context menus cannot be presented
        // from code either. Reply at once instead of letting Ruby time out.
        throw UnsupportedError(
            "ContextMenu.open is not supported on iOS and macOS: the native "
            "context menu opens only from the user's long press, and Flutter's "
            "CupertinoContextMenu has no API to open it programmatically. "
            "Use an action_sheet to present the same actions from code.");
      default:
        throw Exception("Unknown ContextMenu method: $name");
    }
  }

  @override
  Widget build(BuildContext context) {
    debugPrint("CupertinoContextMenu build ($hashCode): ${widget.control.id}");

    var content = widget.control.buildWidget("content");
    final (button, items) = _longPressMenu();
    _button = button;

    if (items.isEmpty) {
      return const ErrorControl(
          "at least one action in CupertinoContextMenu.actions must be visible");
    }
    if (content == null) {
      return const ErrorControl("CupertinoContextMenu.content must be visible");
    }

    return CupertinoContextMenu(
      enableHapticFeedback:
          widget.control.getBool("enable_haptic_feedback", false)!,
      actions: items
          .map((item) => _MenuSessionAction(
              menu: this, items: items, child: ControlWidget(control: item)))
          .toList(),
      child: content,
    );
  }

  // CupertinoContextMenu has no open/close callbacks. Its actions exist only
  // while the menu route is up, so their lifetime is the menu session: the
  // last one going away closes the session, and a session without a chosen
  // item is a dismissal, as with Material's ContextMenu.
  int _openActions = 0;
  bool _selected = false;
  int _itemCount = 0;
  String _button = "secondary";

  // iOS has one context-menu gesture, the long press. It stands for the
  // pointer button a desktop user would use for the same menu: primary when
  // `primary_trigger` is long_press, otherwise secondary (the context click)
  // unless `secondary_trigger` is disabled. As on Material, that button's
  // list is shown, else `items`, else `actions`. A menu whose only items are
  // in another per-button list (e.g. tertiary, a middle click) still opens
  // on long press rather than showing an error.
  (String, List<Control>) _longPressMenu() {
    final button = _trigger("primary") == "longPress"
        ? "primary"
        : _trigger("secondary") != "disabled"
            ? "secondary"
            : "primary";
    for (final key in ["${button}_items", "items", "actions"]) {
      final list = widget.control.children(key);
      if (list.isNotEmpty) return (button, list);
    }
    for (final other in const ["primary", "secondary", "tertiary"]) {
      final list = widget.control.children("${other}_items");
      if (list.isNotEmpty) return (other, list);
    }
    return (button, const []);
  }

  static const _defaultTriggers = {
    "primary": "disabled",
    "secondary": "down",
    "tertiary": "down",
  };

  /// The configured trigger name, spelled as Material reports it.
  String _trigger(String button) {
    final value = (widget.control.getString("${button}_trigger") ??
            _defaultTriggers[button]!)
        .toLowerCase()
        .replaceAll("_", "");
    return value == "longpress" ? "longPress" : value;
  }

  void _attach(int itemCount) {
    if (_openActions++ == 0) _selected = false;
    _itemCount = itemCount;
  }

  void _detach() {
    if (--_openActions == 0 && !_selected && mounted) {
      widget.control.triggerEvent("dismiss", _payload());
    }
  }

  void _select(Control item, List<Control> items) {
    _selected = true;
    widget.control.triggerEvent(
        "select",
        _payload(
            itemId: item.id,
            itemIndex: items.contains(item) ? items.indexOf(item) : null));
  }

  // Same keys as the Material ContextMenu payload: the button the long press
  // stands for and its configured trigger. The native menu reports no
  // pointer position.
  Map<String, dynamic> _payload({int? itemId, int? itemIndex}) => {
        "b": _button,
        "tr": _trigger(_button),
        "id": itemId,
        "idx": itemIndex,
        "ic": _itemCount,
        "g": null,
        "l": null,
      };
}

/// Lets a [CupertinoContextMenuActionControl] report the chosen item to the
/// enclosing ContextMenu's `on_select`.
class CupertinoContextMenuSelection extends InheritedWidget {
  final void Function(Control item) onSelected;

  const CupertinoContextMenuSelection(
      {super.key, required this.onSelected, required super.child});

  static CupertinoContextMenuSelection? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<CupertinoContextMenuSelection>();

  @override
  bool updateShouldNotify(CupertinoContextMenuSelection oldWidget) => false;
}

class _MenuSessionAction extends StatefulWidget {
  final _CupertinoContextMenuControlState menu;
  final List<Control> items;
  final Widget child;

  const _MenuSessionAction(
      {required this.menu, required this.items, required this.child});

  @override
  State<_MenuSessionAction> createState() => _MenuSessionActionState();
}

class _MenuSessionActionState extends State<_MenuSessionAction> {
  late final _CupertinoContextMenuControlState _menu = widget.menu;

  @override
  void initState() {
    super.initState();
    _menu._attach(widget.items.length);
  }

  @override
  void dispose() {
    _menu._detach();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CupertinoContextMenuSelection(
      onSelected: (item) => widget.menu._select(item, widget.items),
      child: widget.child);
}
