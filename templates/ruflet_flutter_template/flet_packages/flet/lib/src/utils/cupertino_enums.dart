import 'package:flutter/cupertino.dart';
import '../models/control.dart';
import 'enums.dart';

CupertinoDatePickerMode? parseCupertinoDatePickerMode(String? value,
    [CupertinoDatePickerMode? defaultValue]) {
  return parseEnum(CupertinoDatePickerMode.values, value, defaultValue);
}

CupertinoTimerPickerMode? parseCupertinoTimerPickerMode(String? value,
    [CupertinoTimerPickerMode? defaultValue]) {
  return parseEnum(CupertinoTimerPickerMode.values, value, defaultValue);
}

DatePickerDateOrder? parseDatePickerDateOrder(String? value,
    [DatePickerDateOrder? defaultValue]) {
  return parseEnum(DatePickerDateOrder.values, value, defaultValue);
}

CupertinoButtonSize? parseCupertinoButtonSize(String? value,
    [CupertinoButtonSize? defaultValue]) {
  return parseEnum(CupertinoButtonSize.values, value, defaultValue);
}

extension CupertinoEnumParsers on Control {
  CupertinoDatePickerMode? getCupertinoDatePickerMode(String propertyName,
      [CupertinoDatePickerMode? defaultValue]) {
    return parseCupertinoDatePickerMode(get(propertyName), defaultValue);
  }

  CupertinoTimerPickerMode? getCupertinoTimerPickerMode(String propertyName,
      [CupertinoTimerPickerMode? defaultValue]) {
    return parseCupertinoTimerPickerMode(get(propertyName), defaultValue);
  }

  DatePickerDateOrder? getDatePickerDateOrder(String propertyName,
      [DatePickerDateOrder? defaultValue]) {
    return parseDatePickerDateOrder(get(propertyName), defaultValue);
  }

  CupertinoButtonSize? getCupertinoButtonSize(String propertyName,
      [CupertinoButtonSize? defaultValue]) {
    return parseCupertinoButtonSize(get(propertyName), defaultValue);
  }
}

OverlayVisibilityMode? parseOverlayVisibilityMode(String? value,
    [OverlayVisibilityMode? defaultValue]) {
  return parseEnum(OverlayVisibilityMode.values, value, defaultValue);
}

extension CupertinoInputParsers on Control {
  OverlayVisibilityMode? getOverlayVisibilityMode(String propertyName,
      [OverlayVisibilityMode? defaultValue]) {
    return parseOverlayVisibilityMode(get(propertyName), defaultValue);
  }
}
