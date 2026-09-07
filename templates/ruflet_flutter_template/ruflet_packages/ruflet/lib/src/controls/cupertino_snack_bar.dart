import 'dart:async';

import 'package:flutter/cupertino.dart';

import '../extensions/control.dart';
import '../models/control.dart';
import '../utils/colors.dart';
import '../utils/edge_insets.dart';
import '../utils/numbers.dart';
import '../utils/time.dart';
import '../widgets/error.dart';

class CupertinoSnackBarControl extends StatefulWidget {
  final Control control;

  const CupertinoSnackBarControl({super.key, required this.control});

  @override
  State<CupertinoSnackBarControl> createState() =>
      _CupertinoSnackBarControlState();
}

class _CupertinoSnackBarControlState extends State<CupertinoSnackBarControl> {
  OverlayEntry? _entry;
  Timer? _timer;

  Control get control => widget.control;

  @override
  void dispose() {
    _removeEntry();
    super.dispose();
  }

  void _removeEntry() {
    _timer?.cancel();
    _timer = null;
    _entry?.remove();
    _entry = null;
  }

  void _dismiss() {
    if (_entry == null) {
      return;
    }
    _removeEntry();
    control.updateProperties({"_dismissed": true});
    control.updateProperties({"_open": false}, python: false);
    control.updateProperties({"open": false});
    control.triggerEvent("dismiss");
  }

  void _show(BuildContext context, Widget content) {
    _removeEntry();

    final actionControl = control.get("action");
    final backgroundColor = control.getColor("bgcolor", context) ??
        CupertinoColors.systemGrey.resolveFrom(context);
    final padding =
        control.getPadding("padding", const EdgeInsets.fromLTRB(16, 10, 8, 10));
    final margin =
        control.getMargin("margin", const EdgeInsets.fromLTRB(12, 0, 12, 12));
    final width = control.getDouble("width");
    final showClose = control.getBool("show_close_icon", false)!;

    _entry = OverlayEntry(builder: (overlayContext) {
      Widget bar = CupertinoPopupSurface(
        isSurfacePainted: false,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: padding!,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(child: DefaultTextStyle.merge(child: content)),
                if (actionControl is Control)
                  CupertinoButton(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    onPressed: actionControl.disabled
                        ? null
                        : () => actionControl.triggerEvent("click"),
                    child: Text(actionControl.getString("label", "Action")!),
                  )
                else if (actionControl is String)
                  CupertinoButton(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    onPressed: () => control.triggerEvent("action"),
                    child: Text(actionControl),
                  ),
                if (showClose)
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size.square(32),
                    onPressed: _dismiss,
                    child: const Icon(CupertinoIcons.xmark, size: 18),
                  ),
              ],
            ),
          ),
        ),
      );
      if (width != null) {
        bar = SizedBox(width: width, child: bar);
      }
      return SafeArea(
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Padding(padding: margin!, child: bar),
        ),
      );
    });

    Overlay.of(context, rootOverlay: true).insert(_entry!);
    control.triggerEvent("visible");

    if (control.getBool("persist", false) != true) {
      final duration =
          control.getDuration("duration", const Duration(milliseconds: 4000))!;
      _timer = Timer(duration, _dismiss);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dismissed = control.getBool("_dismissed", false)!;
    final open = control.getBool("open", false)!;
    final lastOpen = control.getBool("_open", false)!;

    if (!dismissed && open && open != lastOpen) {
      final content = control.buildTextOrWidget("content");
      if (content == null) {
        return const ErrorControl(
            "SnackBar.content must be provided and visible");
      }
      control.updateProperties({"_open": true}, python: false);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _show(context, content);
      });
    } else if (!open && lastOpen) {
      control.updateProperties({"_open": false}, python: false);
      WidgetsBinding.instance.addPostFrameCallback((_) => _removeEntry());
    }

    return const SizedBox.shrink();
  }
}
