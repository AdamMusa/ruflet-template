import 'package:ruflet/ruflet.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_code_editor/flutter_code_editor.dart' as fce;
import 'package:flutter_highlight/theme_map.dart';

/// The highlight.js entry [name] selects in [names]. highlight.js names
/// use hyphens (`atom-one-dark`, `clojure-repl`) while Ruby symbols arrive
/// in snake_case (`:atom_one_dark`), so an unmatched name is retried with
/// hyphens; an exact match (e.g. `qtcreator_dark`) wins.
T? highlightEntry<T>(Map<String, T> names, String? name) {
  if (name == null) return null;
  final lower = name.toLowerCase();
  return names[lower] ?? names[lower.replaceAll('_', '-')];
}

fce.CodeThemeData? parseCodeThemeData(Control control, BuildContext context) {
  final codeTheme = control.get("code_theme");
  if (codeTheme is! Map) {
    if (codeTheme is String) {
      final named = highlightEntry(themeMap, codeTheme);
      return named == null ? null : fce.CodeThemeData(styles: named);
    }
    return null;
  }

  final themeName = codeTheme["name"];
  if (themeName is String) {
    final named = highlightEntry(themeMap, themeName);
    if (named != null) {
      return fce.CodeThemeData(styles: named);
    }
  }

  final styles = codeTheme["styles"];
  final Map<dynamic, dynamic> stylesSource;
  if (styles is Map) {
    stylesSource = styles.cast<dynamic, dynamic>();
  } else {
    // CustomCodeTheme is serialized as a flat map of token -> TextStyle.
    final flattened = Map.of(codeTheme);
    flattened.remove("name");
    stylesSource = flattened;
  }

  final parsedStyles = <String, TextStyle>{};
  stylesSource.forEach((key, value) {
    final style = parseTextStyle(value, RufletStyleTheme.of(context));
    if (style != null) {
      parsedStyles[key.toString()] = style;
    }
  });

  if (parsedStyles.isEmpty) {
    return null;
  }

  return fce.CodeThemeData(styles: parsedStyles);
}

fce.GutterStyle? parseGutterStyle(Control control, BuildContext context) {
  final gutterStyle = control.get("gutter_style");
  if (gutterStyle is! Map) {
    return null;
  }

  final textStyle =
      parseTextStyle(gutterStyle["text_style"], RufletStyleTheme.of(context));
  final background =
      parseColor(gutterStyle["background_color"], RufletStyleTheme.of(context));
  final width = parseDouble(gutterStyle["width"]);
  final margin = _parseGutterMargin(gutterStyle["margin"]);

  final showErrors = gutterStyle["show_errors"];
  final showFoldingHandles = gutterStyle["show_folding_handles"];
  final showLineNumbers = gutterStyle["show_line_numbers"];

  return fce.GutterStyle(
    textStyle: textStyle,
    background: background,
    width: width ?? 80.0,
    margin: margin ?? 10.0,
    showErrors: showErrors is bool ? showErrors : true,
    showFoldingHandles: showFoldingHandles is bool ? showFoldingHandles : true,
    showLineNumbers: showLineNumbers is bool ? showLineNumbers : true,
  );
}

double? _parseGutterMargin(dynamic value) {
  final margin = parseDouble(value);
  if (margin != null) {
    return margin;
  }
  final edgeInsets = parseEdgeInsets(value);
  if (edgeInsets == null) {
    return null;
  }
  return (edgeInsets.left + edgeInsets.right) / 2;
}
