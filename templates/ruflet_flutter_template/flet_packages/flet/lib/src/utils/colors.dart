import 'package:flutter/widgets.dart';

import '../models/control.dart';
import 'color_palette.dart';
import 'style_theme.dart';
import 'numbers.dart';
import 'widget_state.dart';

Map<String, Color> _plainColors = {
  "white10": FletColors.white10,
  "white12": FletColors.white12,
  "white24": FletColors.white24,
  "white30": FletColors.white30,
  "white38": FletColors.white38,
  "white54": FletColors.white54,
  "white60": FletColors.white60,
  "white70": FletColors.white70,
  "white": FletColors.white,
  "black12": FletColors.black12,
  "black26": FletColors.black26,
  "black38": FletColors.black38,
  "black45": FletColors.black45,
  "black54": FletColors.black54,
  "black87": FletColors.black87,
  "black": FletColors.black,
  "transparent": FletColors.transparent
};

Map<String, ColorSwatch<int>> _materialColors = {
  "red": FletColors.red,
  "pink": FletColors.pink,
  "purple": FletColors.purple,
  "deeppurple": FletColors.deepPurple,
  "indigo": FletColors.indigo,
  "blue": FletColors.blue,
  "lightblue": FletColors.lightBlue,
  "cyan": FletColors.cyan,
  "teal": FletColors.teal,
  "green": FletColors.green,
  "lightgreen": FletColors.lightGreen,
  "lime": FletColors.lime,
  "yellow": FletColors.yellow,
  "amber": FletColors.amber,
  "orange": FletColors.orange,
  "deeporange": FletColors.deepOrange,
  "brown": FletColors.brown,
  "bluegrey": FletColors.blueGrey,
  "grey": FletColors.grey
};

Map<String, ColorSwatch<int>> _materialAccentColors = {
  "redaccent": FletColors.redAccent,
  "pinkaccent": FletColors.pinkAccent,
  "purpleaccent": FletColors.purpleAccent,
  "deeppurpleaccent": FletColors.deepPurpleAccent,
  "indigoaccent": FletColors.indigoAccent,
  "blueaccent": FletColors.blueAccent,
  "lightblueaccent": FletColors.lightBlueAccent,
  "cyanaccent": FletColors.cyanAccent,
  "tealaccent": FletColors.tealAccent,
  "greenaccent": FletColors.greenAccent,
  "lightgreenaccent": FletColors.lightGreenAccent,
  "limeaccent": FletColors.limeAccent,
  "yellowaccent": FletColors.yellowAccent,
  "amberaccent": FletColors.amberAccent,
  "orangeaccent": FletColors.orangeAccent,
  "deeporangeaccent": FletColors.deepOrangeAccent,
};

// https://stackoverflow.com/questions/50081213/how-do-i-use-hexadecimal-color-strings-in-flutter
extension HexColor on Color {
  static Color? fromString(FletStyleTheme? theme, String? colorString,
      [Color? defaultColor]) {
    if (colorString == null || colorString.isEmpty) {
      return defaultColor;
    }
    var colorParts = colorString.split(",");

    var colorValue = colorParts[0];
    var colorOpacity = colorParts.length > 1 ? colorParts[1] : null;

    Color? color;
    if (colorValue.startsWith("#")) {
      color = HexColor._fromHex(colorValue.substring(1));
    } else if (colorValue.startsWith("0x")) {
      color = HexColor._fromHex(colorValue.substring(2));
    } else {
      color = HexColor._fromNamedColor(theme, colorValue);
    }

    if (color != null && colorOpacity != null) {
      color = color.withValues(alpha: parseDouble(colorOpacity, 1.0)!);
    }

    return color ?? defaultColor;
  }

  static Color? _fromNamedColor(FletStyleTheme? theme, String colorName) {
    RegExp namedColor = RegExp(r'^([a-zA-Z]+)([0-9]*)$');
    var matches = namedColor.allMatches(colorName);
    if (matches.isEmpty) {
      return null;
    }
    var name = matches.first.group(1) ?? "";
    var shade = int.tryParse(matches.first.group(2)!) ?? 0;

    // scheme color
    if (theme != null) {
      Color? color = theme.color(name);
      if (color != null) {
        return color;
      }
    }

    // plain color
    Color? color = _plainColors[colorName.toLowerCase()];
    if (color != null) {
      return color;
    }

    // find material color
    ColorSwatch<int>? primaryColor = _materialColors[name.toLowerCase()];
    if (primaryColor != null) {
      var shadedColor = primaryColor[shade];
      return shadedColor ?? primaryColor;
    }

    // Cupertino semantic names are supplied by the native style scope.

    // accent color
    ColorSwatch<int>? accentColor = _materialAccentColors[name.toLowerCase()];
    if (accentColor != null) {
      var shadedColor = accentColor[shade];
      return shadedColor ?? accentColor;
    }

    return null;
  }

  /// String is in the format "aabbcc" or "ffaabbcc" with an optional leading "#".
  static Color _fromHex(String hexString) {
    final buffer = StringBuffer();
    if (hexString.length == 6) buffer.write('ff');
    buffer.write(hexString);
    return Color(int.parse(buffer.toString(), radix: 16));
  }

  /// Prefixes a hash sign if [leadingHashSign] is set to `true` (default is `true`).
  String toHex({bool leadingHashSign = true}) {
    int to8bit(double component) => (component * 255.0).round().clamp(0, 255);

    final alpha8 = to8bit(a);
    final red8 = to8bit(r);
    final green8 = to8bit(g);
    final blue8 = to8bit(b);

    return '${leadingHashSign ? '#' : ''}'
        '${alpha8.toRadixString(16).padLeft(2, '0')}'
        '${red8.toRadixString(16).padLeft(2, '0')}'
        '${green8.toRadixString(16).padLeft(2, '0')}'
        '${blue8.toRadixString(16).padLeft(2, '0')}';
  }
}

extension ColorExtension on Color {
  /// Convert the color to a darken color based on the [percent]
  Color darken([int percent = 40]) {
    assert(1 <= percent && percent <= 100);
    final value = 1 - percent / 100;
    int to8bit(double component) => (component * 255.0).round().clamp(0, 255);

    return Color.fromARGB(
      to8bit(a),
      (to8bit(r) * value).round().clamp(0, 255),
      (to8bit(g) * value).round().clamp(0, 255),
      (to8bit(b) * value).round().clamp(0, 255),
    );
  }
}

WidgetStateProperty<Color?>? parseWidgetStateColor(
    dynamic value, FletStyleTheme theme,
    {Color? defaultColor, WidgetStateProperty<Color?>? defaultValue}) {
  if (value == null) return defaultValue;

  return getWidgetStateProperty<Color?>(
      value, (jv) => HexColor.fromString(theme, jv as String), defaultColor);
}

Color? parseColor(String? value, FletStyleTheme? theme,
        [Color? defaultColor]) =>
    HexColor.fromString(theme, value, defaultColor);

extension ColorParsers on Control {
  Color? getColor(String propertyName, BuildContext? context,
      [Color? defaultValue]) {
    return parseColor(getString(propertyName),
        context != null ? FletStyleTheme.of(context) : null, defaultValue);
  }

  WidgetStateProperty<Color?>? getWidgetStateColor(
      String propertyName, FletStyleTheme theme,
      {Color? defaultColor, WidgetStateProperty<Color?>? defaultValue}) {
    return parseWidgetStateColor(get(propertyName), theme,
        defaultColor: defaultColor, defaultValue: defaultValue);
  }
}
