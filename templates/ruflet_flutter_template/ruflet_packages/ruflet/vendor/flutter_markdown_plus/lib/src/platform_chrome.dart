import 'package:flutter/widgets.dart';

import 'cupertino_chrome.dart';
import 'material_chrome.dart';

class MarkdownCheckbox extends StatelessWidget {
  const MarkdownCheckbox(
      {super.key,
      required this.useCupertino,
      required this.checked,
      this.size,
      this.color});

  final bool useCupertino, checked;
  final double? size;
  final Color? color;

  @override
  Widget build(BuildContext context) => useCupertino
      ? CupertinoMarkdownCheckbox(checked: checked, size: size, color: color)
      : MaterialMarkdownCheckbox(checked: checked, size: size, color: color);
}

class MarkdownScrollbar extends StatelessWidget {
  const MarkdownScrollbar({
    super.key,
    required this.useCupertino,
    required this.controller,
    required this.child,
    this.thumbVisibility,
  });

  final bool useCupertino;
  final ScrollController controller;
  final Widget child;
  final bool? thumbVisibility;

  @override
  Widget build(BuildContext context) => useCupertino
      ? CupertinoMarkdownScrollbar(
          controller: controller,
          thumbVisibility: thumbVisibility,
          child: child)
      : MaterialMarkdownScrollbar(
          controller: controller,
          thumbVisibility: thumbVisibility,
          child: child);
}

class MarkdownSelectableText extends StatelessWidget {
  const MarkdownSelectableText({
    super.key,
    required this.textSpan,
    required this.useCupertino,
    required this.textAlign,
    this.textScaler,
    this.strutStyle,
    this.onSelectionChanged,
    this.onTap,
    this.contextMenuBuilder,
    this.cupertinoContextMenuBuilder,
  });

  final TextSpan textSpan;
  final bool useCupertino;
  final TextAlign textAlign;
  final TextScaler? textScaler;
  final StrutStyle? strutStyle;
  final SelectionChangedCallback? onSelectionChanged;
  final VoidCallback? onTap;
  final EditableTextContextMenuBuilder? contextMenuBuilder;
  final SelectableRegionContextMenuBuilder? cupertinoContextMenuBuilder;

  @override
  Widget build(BuildContext context) => useCupertino
      ? CupertinoMarkdownSelectableText(
          textSpan: textSpan,
          textAlign: textAlign,
          textScaler: textScaler,
          strutStyle: strutStyle,
          onSelectionChanged: onSelectionChanged,
          onTap: onTap,
          contextMenuBuilder: cupertinoContextMenuBuilder,
        )
      : MaterialMarkdownSelectableText(
          textSpan: textSpan,
          textAlign: textAlign,
          textScaler: textScaler,
          strutStyle: strutStyle,
          onSelectionChanged: onSelectionChanged,
          onTap: onTap,
          contextMenuBuilder: contextMenuBuilder,
        );
}
