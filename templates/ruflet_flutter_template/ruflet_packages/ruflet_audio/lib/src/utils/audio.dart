import 'package:audioplayers/audioplayers.dart';
import 'package:ruflet/ruflet.dart';

ReleaseMode? parseReleaseMode(String? value, [ReleaseMode? defaultValue]) {
  if (value == null) return defaultValue;
  return parseEnum(ReleaseMode.values, value, defaultValue);
}
