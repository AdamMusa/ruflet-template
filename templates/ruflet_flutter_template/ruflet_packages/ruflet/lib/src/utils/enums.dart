import 'package:collection/collection.dart';

/// The form enum-like names are compared in: case-insensitive and without
/// underscores, so Ruby's `"space_between"` matches Dart's `spaceBetween`.
String normalizeEnumName(String value) =>
    value.replaceAll("_", "").toLowerCase();

T? parseEnum<T extends Enum>(List<T> values, String? value, [T? defaultValue]) {
  if (value == null) return defaultValue;

  final name = normalizeEnumName(value);
  return values.firstWhereOrNull((e) => normalizeEnumName(e.name) == name) ??
      defaultValue;
}
