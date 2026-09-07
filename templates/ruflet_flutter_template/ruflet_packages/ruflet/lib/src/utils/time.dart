import '../models/control.dart';
import 'numbers.dart';

enum DurationUnit { microseconds, milliseconds, seconds, minutes, hours, days }

/// Parses a dynamic [value] into a [Duration] object.
///
/// Supported input types:
/// - `null`: Returns [defaultValue].
/// - `num` (int or double): Interpreted as a single time unit specified by [treatNumAs].
/// - `Map`: Must contain one or more of the following keys with numeric values:
///   `days`, `hours`, `minutes`, `seconds`, `milliseconds`, `microseconds`.
///
/// Parameters:
/// - [value]: The input to parse. Can be `null`, `num`, or `Map<String, dynamic>`.
/// - [defaultValue]: The value to return if [value] is `null`.
/// - [treatNumAs]: Specifies the unit of time for numeric input. Defaults to `DurationUnit.milliseconds`.
///
/// Returns:
/// A [Duration] constructed from the parsed input, or [defaultValue] if input is `null`.
Duration? parseDuration(dynamic value,
    [Duration? defaultValue,
    DurationUnit treatNumAs = DurationUnit.milliseconds]) {
  if (value == null) return defaultValue;
  if (value is num) {
    final v = parseInt(value, 0)!;
    return Duration(
      microseconds: treatNumAs == DurationUnit.microseconds ? v : 0,
      milliseconds: treatNumAs == DurationUnit.milliseconds ? v : 0,
      seconds: treatNumAs == DurationUnit.seconds ? v : 0,
      minutes: treatNumAs == DurationUnit.minutes ? v : 0,
      hours: treatNumAs == DurationUnit.hours ? v : 0,
      days: treatNumAs == DurationUnit.days ? v : 0,
    );
  }
  return Duration(
      days: parseInt(value["days"], 0)!,
      hours: parseInt(value["hours"], 0)!,
      minutes: parseInt(value["minutes"], 0)!,
      seconds: parseInt(value["seconds"], 0)!,
      milliseconds: parseInt(value["milliseconds"], 0)!,
      microseconds: parseInt(value["microseconds"], 0)!);
}

extension TimeParsers on Control {
  /// Retrieves and parses a duration value from the control's properties.
  ///
  /// Parameters:
  /// - [propertyName]: The name of the property to retrieve the value from.
  /// - [defaultValue]: The value to return if the property is not set or is `null`.
  /// - [treatNumAs]: Specifies the unit of time for numeric input. Defaults to `DurationUnit.milliseconds`.
  ///
  ///
  /// Returns:
  /// A [Duration] based on the property's value, or [defaultValue] if the value is `null`.
  Duration? getDuration(String propertyName,
      [Duration? defaultValue,
      DurationUnit treatNumAs = DurationUnit.milliseconds]) {
    return parseDuration(get(propertyName), defaultValue, treatNumAs);
  }

  DateTime? getDateTime(String propertyName, [DateTime? defaultValue]) {
    final value = get<DateTime>(propertyName, defaultValue); // UTC time
    return value?.toLocal();
  }
}
