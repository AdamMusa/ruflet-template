import 'package:flutter/cupertino.dart';

import '../extensions/control.dart';
import '../models/control.dart';
import '../utils/colors.dart';
import '../utils/edge_insets.dart';
import '../utils/numbers.dart';
import '../widgets/error.dart';
import 'control_widget.dart';

class CupertinoBannerControl extends StatefulWidget {
  final Control control;

  const CupertinoBannerControl({super.key, required this.control});

  @override
  State<CupertinoBannerControl> createState() => _CupertinoBannerControlState();
}

class _CupertinoBannerControlState extends State<CupertinoBannerControl> {
  OverlayEntry? _entry;

  Control get control => widget.control;

  @override
  void dispose() {
    _removeEntry();
    super.dispose();
  }

  void _removeEntry() {
    _entry?.remove();
    _entry = null;
  }

  void _show(BuildContext context, Widget content) {
    _removeEntry();
    final leading = control.buildIconOrWidget("leading");
    final actions = control.children("actions");
    final backgroundColor = control.getColor("bgcolor", context) ??
        CupertinoColors.secondarySystemBackground.resolveFrom(context);
    final padding =
        control.getPadding("content_padding", const EdgeInsets.all(16));

    _entry = OverlayEntry(builder: (context) {
      return SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: CupertinoPopupSurface(
            isSurfacePainted: false,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: backgroundColor,
                border: const Border(
                  bottom: BorderSide(color: CupertinoColors.separator),
                ),
              ),
              child: Padding(
                padding: padding!,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (leading != null) ...[
                          leading,
                          const SizedBox(width: 12),
                        ],
                        Expanded(child: content),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: actions
                          .map((action) => CupertinoButton(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                onPressed: action.disabled
                                    ? null
                                    : () => action.triggerEvent("click"),
                                child: action.get("content") != null
                                    ? ControlWidget(control: action)
                                    : Text(action.getString("text", "Action")!),
                              ))
                          .toList(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    });
    Overlay.of(context, rootOverlay: true).insert(_entry!);
    control.triggerEvent("visible");
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
            "Banner.content must be provided and visible");
      }
      if (control.children("actions").isEmpty) {
        return const ErrorControl(
            "Banner.actions must be provided and at least one action should be visible");
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
