import 'package:flutter/cupertino.dart';
import '../widgets/platform_design.dart';

import '../models/control.dart';
import '../utils/colors.dart';
import '../utils/cupertino_theme.dart';
import '../utils/numbers.dart';
import '../utils/text.dart';
import 'base_controls.dart';

class CupertinoTextControl extends StatelessWidget {
  final Control control;

  const CupertinoTextControl({super.key, required this.control});

  @override
  Widget build(BuildContext context) {
    final theme = cupertinoStyleTheme(context);
    final text = control.getString("value", "")!;
    final spans = parseTextSpans(
      control.children("spans"),
      theme,
      (control, eventName, [eventData]) {
        control.triggerEvent(eventName, eventData);
      },
    );
    var style = control.getTextStyle("style", theme);
    final themeStyle = theme.textStyle(control.getString("theme_style") ?? "");
    if (style == null && themeStyle != null) {
      style = themeStyle;
    } else if (style != null && themeStyle != null) {
      style = themeStyle.merge(style);
    }
    final fontWeight = control.getString("weight", "")!;
    final variations = <FontVariation>[];
    if (fontWeight.startsWith("w")) {
      variations
          .add(FontVariation('wght', parseDouble(fontWeight.substring(1), 0)!));
    }
    // Let native parents supply their role-specific typography (navigation
    // titles, list subtitles, buttons). Explicit DSL styles still override it.
    style = (style ?? const TextStyle()).copyWith(
      overflow: control.getTextOverflow("overflow"),
      fontSize: control.getDouble("size"),
      fontWeight: parseFontWeight(fontWeight),
      fontStyle: control.getBool("italic", false)! ? FontStyle.italic : null,
      fontFamily: control.getString("font_family"),
      fontVariations: variations,
      color: control.getColor("color", context) ??
          (spans.isNotEmpty ? DefaultTextStyle.of(context).style.color : null),
      backgroundColor: control.getColor("bgcolor", context),
    );
    final textAlign =
        parseTextAlign(control.getString("text_align"), TextAlign.start)!;
    final semanticsLabel = control.getString("semantics_label");
    final maxLines = control.getInt("max_lines");
    final noWrap = control.getBool("no_wrap", false)!;
    final richText = TextSpan(text: text, style: style, children: spans);
    final plain = spans.isEmpty;
    final textWidget = plain
        ? Text(
            text,
            semanticsLabel: semanticsLabel,
            maxLines: maxLines,
            softWrap: !noWrap,
            style: style,
            textAlign: textAlign,
          )
        : Text.rich(
            richText,
            semanticsLabel: semanticsLabel,
            maxLines: maxLines,
            softWrap: !noWrap,
            textAlign: textAlign,
          );

    Widget result = textWidget;
    if (control.getBool("selectable", false)! &&
        control.getBool("enable_interactive_selection", true)!) {
      result = _CupertinoSelectableText(
        fullText: richText.toPlainText(),
        cursorColor: control.getColor("selection_cursor_color", context) ??
            CupertinoColors.activeBlue.resolveFrom(context),
        onSelectionChanged: (selected) {
          final start =
              selected.isEmpty ? -1 : richText.toPlainText().indexOf(selected);
          final end = start < 0 ? -1 : start + selected.length;
          control.triggerEvent("selection_change", {
            "selected_text": selected,
            "cause": "user",
            "selection": {
              "start": start,
              "end": end,
              "base_offset": start,
              "extent_offset": end,
              "affinity": "downstream",
              "directional": false,
              "collapsed": selected.isEmpty,
              "valid": start >= 0,
              "normalized": true,
            },
          });
        },
        child: textWidget,
      );
    }
    if (control.getBool("on_tap", false)!) {
      result = GestureDetector(
        onTap: () => control.triggerEvent("tap"),
        child: result,
      );
    }
    return LayoutControl(control: control, child: result);
  }
}

class _CupertinoSelectableText extends StatefulWidget {
  final String fullText;
  final Color cursorColor;
  final ValueChanged<String> onSelectionChanged;
  final Widget child;

  const _CupertinoSelectableText({
    required this.fullText,
    required this.cursorColor,
    required this.onSelectionChanged,
    required this.child,
  });

  @override
  State<_CupertinoSelectableText> createState() =>
      _CupertinoSelectableTextState();
}

class _CupertinoSelectableTextState extends State<_CupertinoSelectableText> {
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controls = effectiveTargetPlatform(context) == TargetPlatform.macOS
        ? cupertinoDesktopTextSelectionHandleControls
        : cupertinoTextSelectionHandleControls;
    return DefaultSelectionStyle(
      cursorColor: widget.cursorColor,
      selectionColor: widget.cursorColor.withValues(alpha: 0.25),
      child: SelectableRegion(
        focusNode: _focusNode,
        selectionControls: controls,
        contextMenuBuilder: (context, state) =>
            CupertinoAdaptiveTextSelectionToolbar.buttonItems(
          anchors: state.contextMenuAnchors,
          buttonItems: state.contextMenuButtonItems,
        ),
        onSelectionChanged: (selection) {
          widget.onSelectionChanged(selection?.plainText ?? "");
        },
        child: widget.child,
      ),
    );
  }
}
