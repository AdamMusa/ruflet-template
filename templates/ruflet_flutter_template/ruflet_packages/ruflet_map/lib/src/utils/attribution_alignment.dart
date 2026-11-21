import 'package:flutter_map/flutter_map.dart';
import 'package:ruflet/ruflet.dart';

AttributionAlignment? parseAttributionAlignment(String? value,
    [AttributionAlignment? defValue]) {
  if (value == null) return defValue;
  return parseEnum(AttributionAlignment.values, value, defValue);
}
