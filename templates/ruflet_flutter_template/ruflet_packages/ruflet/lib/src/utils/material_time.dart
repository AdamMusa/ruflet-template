import 'package:flutter/material.dart';
import '../models/control.dart';
import '../models/ruflet_time.dart';
import 'enums.dart';

TimePickerEntryMode? parseTimePickerEntryMode(String? value,
    [TimePickerEntryMode? defaultValue]) {
  return parseEnum(TimePickerEntryMode.values, value, defaultValue);
}

DatePickerEntryMode? parseDatePickerEntryMode(String? value,
    [DatePickerEntryMode? defaultValue]) {
  return parseEnum(DatePickerEntryMode.values, value, defaultValue);
}

DatePickerMode? parseDatePickerMode(String? value,
    [DatePickerMode? defaultValue]) {
  return parseEnum(DatePickerMode.values, value, defaultValue);
}

extension MaterialTimeParsers on Control {
  TimePickerEntryMode? getTimePickerEntryMode(String propertyName,
      [TimePickerEntryMode? defaultValue]) {
    return parseTimePickerEntryMode(get(propertyName), defaultValue);
  }

  DatePickerEntryMode? getDatePickerEntryMode(String propertyName,
      [DatePickerEntryMode? defaultValue]) {
    return parseDatePickerEntryMode(get(propertyName), defaultValue);
  }

  DatePickerMode? getDatePickerMode(String propertyName,
      [DatePickerMode? defaultValue]) {
    return parseDatePickerMode(get(propertyName), defaultValue);
  }

  TimeOfDay? getTimeOfDay(String propertyName, [TimeOfDay? defaultValue]) {
    final value = get(propertyName);
    return value is RufletTime
        ? TimeOfDay(hour: value.hour, minute: value.minute)
        : value is TimeOfDay
            ? value
            : defaultValue;
  }
}
