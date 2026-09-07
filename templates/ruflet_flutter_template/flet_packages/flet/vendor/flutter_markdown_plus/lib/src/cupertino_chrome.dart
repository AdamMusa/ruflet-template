import 'package:flutter/cupertino.dart';

class CupertinoMarkdownCheckbox extends StatelessWidget {
  const CupertinoMarkdownCheckbox(
      {super.key, required this.checked, this.size, this.color});
  final bool checked;
  final double? size;
  final Color? color;

  @override
  Widget build(BuildContext context) =>
      Icon(checked ? CupertinoIcons.checkmark_square : CupertinoIcons.square,
          size: size, color: color);
}

class CupertinoMarkdownScrollbar extends StatelessWidget {
  const CupertinoMarkdownScrollbar(
      {super.key,
      required this.controller,
      required this.child,
      this.thumbVisibility});

  final ScrollController controller;
  final Widget child;
  final bool? thumbVisibility;

  @override
  Widget build(BuildContext context) => CupertinoScrollbar(
      controller: controller, thumbVisibility: thumbVisibility, child: child);
}

class CupertinoMarkdownSelectableText extends StatefulWidget {
  const CupertinoMarkdownSelectableText({
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
  final SelectableRegionContextMenuBuilder? contextMenuBuilder;

  @override
  State<CupertinoMarkdownSelectableText> createState() =>
      _CupertinoMarkdownSelectableTextState();
}

class _CupertinoMarkdownSelectableTextState
    extends State<CupertinoMarkdownSelectableText> {
  final FocusNode _focus = FocusNode();
  final SelectionListenerNotifier _selection = SelectionListenerNotifier();

  @override
  void initState() {
    super.initState();
    _selection.addListener(_selectionChanged);
  }

  void _selectionChanged() {
    if (!_selection.registered) return;
    final range = _selection.selection.range;
    if (range == null) return;
    widget.onSelectionChanged?.call(
      TextSelection(
          baseOffset: range.startOffset, extentOffset: range.endOffset),
      null,
    );
  }

  @override
  void dispose() {
    _selection.removeListener(_selectionChanged);
    _selection.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: widget.onTap,
        child: SelectableRegion(
          focusNode: _focus,
          selectionControls: cupertinoTextSelectionHandleControls,
          contextMenuBuilder: widget.contextMenuBuilder ??
              (context, state) =>
                  CupertinoAdaptiveTextSelectionToolbar.buttonItems(
                    anchors: state.contextMenuAnchors,
                    buttonItems: state.contextMenuButtonItems,
                  ),
          child: SelectionListener(
            selectionNotifier: _selection,
            child: Text.rich(widget.textSpan,
                textAlign: widget.textAlign,
                textScaler: widget.textScaler,
                strutStyle: widget.strutStyle),
          ),
        ),
      );
}
