import 'package:flutter/material.dart';

class MaterialMarkdownCheckbox extends StatelessWidget {
  const MaterialMarkdownCheckbox(
      {super.key, required this.checked, this.size, this.color});
  final bool checked;
  final double? size;
  final Color? color;

  @override
  Widget build(BuildContext context) =>
      Icon(checked ? Icons.check_box : Icons.check_box_outline_blank,
          size: size, color: color);
}

class MaterialMarkdownScrollbar extends StatelessWidget {
  const MaterialMarkdownScrollbar(
      {super.key,
      required this.controller,
      required this.child,
      this.thumbVisibility});

  final ScrollController controller;
  final Widget child;
  final bool? thumbVisibility;

  @override
  Widget build(BuildContext context) => Scrollbar(
      controller: controller, thumbVisibility: thumbVisibility, child: child);
}

class MaterialMarkdownSelectableText extends StatelessWidget {
  const MaterialMarkdownSelectableText({
    super.key,
    required this.textSpan,
    required this.textAlign,
    this.textScaler,
    this.strutStyle,
    this.onSelectionChanged,
    this.onTap,
    this.contextMenuBuilder,
  });

  final TextSpan textSpan;
  final TextAlign textAlign;
  final TextScaler? textScaler;
  final StrutStyle? strutStyle;
  final SelectionChangedCallback? onSelectionChanged;
  final VoidCallback? onTap;
  final EditableTextContextMenuBuilder? contextMenuBuilder;

  @override
  Widget build(BuildContext context) => SelectableText.rich(
        textSpan,
        textAlign: textAlign,
        textScaler: textScaler,
        strutStyle: strutStyle,
        onSelectionChanged: onSelectionChanged,
        onTap: onTap,
        contextMenuBuilder: contextMenuBuilder,
      );
}
