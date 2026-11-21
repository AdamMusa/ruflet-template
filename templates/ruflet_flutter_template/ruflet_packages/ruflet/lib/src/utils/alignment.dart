import 'package:flutter/widgets.dart';

import '../models/control.dart';
import 'enums.dart';
import 'numbers.dart';

MainAxisAlignment? parseMainAxisAlignment(String? value,
    [MainAxisAlignment? defaultValue]) {
  return parseEnum(MainAxisAlignment.values, value, defaultValue);
}

CrossAxisAlignment? parseCrossAxisAlignment(String? value,
    [CrossAxisAlignment? defaultValue]) {
  return parseEnum(CrossAxisAlignment.values, value, defaultValue);
}

WrapAlignment? parseWrapAlignment(String? value,
    [WrapAlignment? defaultValue]) {
  return parseEnum(WrapAlignment.values, value, defaultValue);
}

WrapCrossAlignment? parseWrapCrossAlignment(String? value,
    [WrapCrossAlignment? defaultValue]) {
  return parseEnum(WrapCrossAlignment.values, value, defaultValue);
}

/// The named alignments, keyed by [normalizeEnumName] of their Dart name.
final Map<String, Alignment> _namedAlignments = {
  for (final entry in const {
    'topLeft': Alignment.topLeft,
    'topCenter': Alignment.topCenter,
    'topRight': Alignment.topRight,
    'centerLeft': Alignment.centerLeft,
    'center': Alignment.center,
    'centerRight': Alignment.centerRight,
    'bottomLeft': Alignment.bottomLeft,
    'bottomCenter': Alignment.bottomCenter,
    'bottomRight': Alignment.bottomRight,
  }.entries)
    normalizeEnumName(entry.key): entry.value,
};

/// An alignment is an `{x, y}` map (Flet's wire shape) or a named alignment
/// string such as Ruby's `"center"` or `"top_left"`, folded like [parseEnum].
/// An unknown name gives [defaultValue].
Alignment? parseAlignment(dynamic value, [Alignment? defaultValue]) {
  if (value == null) return defaultValue;
  if (value is String) {
    return _namedAlignments[normalizeEnumName(value)] ?? defaultValue;
  }
  return Alignment(parseDouble(value['x'], 0)!, parseDouble(value['y'], 0)!);
}

extension AlignmentParsers on Control {
  MainAxisAlignment? getMainAxisAlignment(String propertyName,
      [MainAxisAlignment? defaultValue]) {
    return parseMainAxisAlignment(get(propertyName), defaultValue);
  }

  CrossAxisAlignment? getCrossAxisAlignment(String propertyName,
      [CrossAxisAlignment? defaultValue]) {
    return parseCrossAxisAlignment(get(propertyName), defaultValue);
  }

  WrapAlignment? getWrapAlignment(String propertyName,
      [WrapAlignment? defaultValue]) {
    return parseWrapAlignment(get(propertyName), defaultValue);
  }

  WrapCrossAlignment? getWrapCrossAlignment(String propertyName,
      [WrapCrossAlignment? defaultValue]) {
    return parseWrapCrossAlignment(get(propertyName), defaultValue);
  }

  Alignment? getAlignment(String propertyName, [Alignment? defaultValue]) {
    return parseAlignment(get(propertyName), defaultValue);
  }
}
