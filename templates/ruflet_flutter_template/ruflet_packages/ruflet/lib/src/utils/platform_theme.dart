import 'package:flutter/widgets.dart';

import '../models/control.dart';
import '../models/page_design.dart';
import 'enums.dart';

Brightness? parseBrightness(String? value, [Brightness? defaultValue]) =>
    parseEnum(Brightness.values, value, defaultValue);

RufletThemeMode? parseRufletThemeMode(String? value,
        [RufletThemeMode? defaultValue]) =>
    parseEnum(RufletThemeMode.values, value, defaultValue);

extension PlatformThemeParsers on Control {
  Brightness? getBrightness(String propertyName, [Brightness? defaultValue]) =>
      parseBrightness(get(propertyName)?.toString(), defaultValue);

  RufletThemeMode? getRufletThemeMode(String propertyName,
          [RufletThemeMode? defaultValue]) =>
      parseRufletThemeMode(get(propertyName)?.toString(), defaultValue);
}
