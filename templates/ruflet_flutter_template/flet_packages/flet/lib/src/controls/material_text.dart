import '../utils/material_style_theme.dart';
import 'package:flutter/material.dart';

import '../models/control.dart';
import '../utils/colors.dart';
import '../utils/numbers.dart';
import '../utils/text.dart';
import 'base_controls.dart';

class MaterialTextControl extends StatelessWidget {
  final Control control;

  const MaterialTextControl({super.key, required this.control});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = control.getString("value", "")!;
    final selectionCursorColor =
        control.getColor("selection_cursor_color", context);
    final selectionCursorWidth =
        control.getDouble("selection_cursor_width", 2.0)!;
    final selectionCursorHeight = control.getDouble("selection_cursor_height");
    final showSelectionCursor =
        control.getBool("show_selection_cursor", false)!;
    final enableInteractiveSelection =
        control.getBool("enable_interactive_selection", true)!;
    final spans = parseTextSpans(
      control.children("spans"),
      materialStyleTheme(theme),
      (control, eventName, [eventData]) {
        control.triggerEvent(eventName, eventData);
      },
    );
    final semanticsLabel = control.getString("semantics_label");
    final noWrap = control.getBool("no_wrap", false)!;
    final maxLines = control.getInt("max_lines");
    var style = control.getTextStyle("style", materialStyleTheme(theme));
    final themeStyle =
        parseTextThemeStyle(control.getString("theme_style"), context);
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

    void onSelectionChanged(
        TextSelection selection, SelectionChangedCause? cause) {
      control.triggerEvent("selection_change", {
        "selected_text": text,
        "cause": cause?.name ?? "unknown",
        "selection": selection.toMap(),
      });
    }

    final Widget textWidget = control.getBool("selectable", false)!
        ? spans.isNotEmpty
            ? SelectableText.rich(
                TextSpan(text: text, style: style, children: spans),
                maxLines: maxLines,
                textAlign: textAlign,
                cursorColor: selectionCursorColor,
                cursorHeight: selectionCursorHeight,
                cursorWidth: selectionCursorWidth,
                semanticsLabel: semanticsLabel,
                showCursor: showSelectionCursor,
                enableInteractiveSelection: enableInteractiveSelection,
                onSelectionChanged: onSelectionChanged,
                onTap: () => control.triggerEvent("tap"),
              )
            : SelectableText(
                text,
                semanticsLabel: semanticsLabel,
                maxLines: maxLines,
                style: style,
                textAlign: textAlign,
                cursorColor: selectionCursorColor,
                cursorHeight: selectionCursorHeight,
                cursorWidth: selectionCursorWidth,
                showCursor: showSelectionCursor,
                enableInteractiveSelection: enableInteractiveSelection,
                onSelectionChanged: onSelectionChanged,
                onTap: () => control.triggerEvent("tap"),
              )
        : spans.isNotEmpty
            ? Text.rich(
                TextSpan(text: text, style: style, children: spans),
                semanticsLabel: semanticsLabel,
                maxLines: maxLines,
                softWrap: !noWrap,
                textAlign: textAlign,
              )
            : Text(
                text,
                semanticsLabel: semanticsLabel,
                maxLines: maxLines,
                softWrap: !noWrap,
                style: style,
                textAlign: textAlign,
              );
    return LayoutControl(control: control, child: textWidget);
  }
}
