import 'package:flutter/widgets.dart';

import '../models/control.dart';
import '../models/page_design.dart';
import 'enums.dart';

Brightness? parseBrightness(String? value, [Brightness? defaultValue]) =>
    parseEnum(Brightness.values, value, defaultValue);

FletThemeMode? parseFletThemeMode(String? value,
        [FletThemeMode? defaultValue]) =>
    parseEnum(FletThemeMode.values, value, defaultValue);

extension PlatformThemeParsers on Control {
  Brightness? getBrightness(String propertyName, [Brightness? defaultValue]) =>
      parseBrightness(get(propertyName)?.toString(), defaultValue);

  FletThemeMode? getFletThemeMode(String propertyName,
          [FletThemeMode? defaultValue]) =>
      parseFletThemeMode(get(propertyName)?.toString(), defaultValue);
}
