import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';

import '../models/control.dart';
import 'colors.dart';
import 'cupertino_colors.dart';
import 'style_theme.dart';
import 'text.dart';

/// Native Cupertino styling plus the additional semantic roles in Ruflet's DSL.
/// Keeping these roles preserves independently configured text and color names
/// even when UIKit uses fewer roles for its built-in widgets.
class RufletCupertinoThemeData extends CupertinoThemeData {
  final Map<String, Color> colorOverrides;
  final Map<String, TextStyle?> textOverrides;

  RufletCupertinoThemeData({
    required CupertinoThemeData nativeTheme,
    Map<String, Color> colorOverrides = const {},
    Map<String, TextStyle?> textOverrides = const {},
  })  : colorOverrides = Map.unmodifiable(colorOverrides),
        textOverrides = Map.unmodifiable(textOverrides),
        super(
          brightness: nativeTheme.brightness,
          primaryColor: nativeTheme.primaryColor,
          primaryContrastingColor: nativeTheme.primaryContrastingColor,
          textTheme: nativeTheme.textTheme,
          barBackgroundColor: nativeTheme.barBackgroundColor,
          scaffoldBackgroundColor: nativeTheme.scaffoldBackgroundColor,
          selectionHandleColor: nativeTheme.selectionHandleColor,
          applyThemeToAll: nativeTheme.applyThemeToAll,
        );

  @override
  RufletCupertinoThemeData resolveFrom(BuildContext context) =>
      RufletCupertinoThemeData(
        nativeTheme: super.resolveFrom(context),
        colorOverrides: colorOverrides.map((key, color) =>
            MapEntry(key, CupertinoDynamicColor.resolve(color, context))),
        textOverrides: textOverrides.map((key, style) => MapEntry(
            key,
            style?.copyWith(
              color: CupertinoDynamicColor.maybeResolve(style.color, context),
              backgroundColor: CupertinoDynamicColor.maybeResolve(
                  style.backgroundColor, context),
              decorationColor: CupertinoDynamicColor.maybeResolve(
                  style.decorationColor, context),
            ))),
      );

  @override
  RufletCupertinoThemeData copyWith({
    Brightness? brightness,
    Color? primaryColor,
    Color? primaryContrastingColor,
    CupertinoTextThemeData? textTheme,
    Color? barBackgroundColor,
    Color? scaffoldBackgroundColor,
    Color? selectionHandleColor,
    bool? applyThemeToAll,
  }) =>
      RufletCupertinoThemeData(
        nativeTheme: super.copyWith(
          brightness: brightness,
          primaryColor: primaryColor,
          primaryContrastingColor: primaryContrastingColor,
          textTheme: textTheme,
          barBackgroundColor: barBackgroundColor,
          scaffoldBackgroundColor: scaffoldBackgroundColor,
          selectionHandleColor: selectionHandleColor,
          applyThemeToAll: applyThemeToAll,
        ),
        colorOverrides: {
          ...colorOverrides,
          if (primaryColor != null) 'primary': primaryColor,
          if (primaryContrastingColor != null)
            'onprimary': primaryContrastingColor,
        },
        textOverrides: textOverrides,
      );

  @override
  bool operator ==(Object other) =>
      other is RufletCupertinoThemeData &&
      super == other &&
      mapEquals(colorOverrides, other.colorOverrides) &&
      mapEquals(textOverrides, other.textOverrides);

  @override
  int get hashCode => Object.hash(
      super.hashCode,
      Object.hashAllUnordered(colorOverrides.entries
          .map((entry) => Object.hash(entry.key, entry.value))),
      Object.hashAllUnordered(textOverrides.entries
          .map((entry) => Object.hash(entry.key, entry.value))));
}

RufletStyleTheme cupertinoStyleTheme(BuildContext context) =>
    _styleTheme(CupertinoTheme.of(context), context);

RufletStyleTheme _styleTheme(CupertinoThemeData theme, BuildContext context) {
  final brightness = theme.brightness ??
      MediaQuery.maybePlatformBrightnessOf(context) ??
      Brightness.light;
  final text = theme.textTheme;
  Color resolve(Color color) {
    if (color is! CupertinoDynamicColor) return color;
    final dark = brightness == Brightness.dark;
    final highContrast = MediaQuery.maybeOf(context)?.highContrast ?? false;
    final elevated = CupertinoUserInterfaceLevel.maybeOf(context) ==
        CupertinoUserInterfaceLevelData.elevated;
    return switch ((dark, highContrast, elevated)) {
      (false, false, false) => color.color,
      (true, false, false) => color.darkColor,
      (false, true, false) => color.highContrastColor,
      (true, true, false) => color.darkHighContrastColor,
      (false, false, true) => color.elevatedColor,
      (true, false, true) => color.darkElevatedColor,
      (false, true, true) => color.highContrastElevatedColor,
      (true, true, true) => color.darkHighContrastElevatedColor,
    };
  }

  final primary = resolve(theme.primaryColor);
  final contrast = resolve(theme.primaryContrastingColor);
  final label = resolve(CupertinoColors.label);
  final background = resolve(theme.scaffoldBackgroundColor);
  final fill = resolve(CupertinoColors.tertiarySystemFill);
  final secondaryBackground =
      resolve(CupertinoColors.secondarySystemBackground);
  final colors = <String, Color>{
    ...cupertinoColors.map((name, color) => MapEntry(name, resolve(color))),
    for (final role in ['primary', 'secondary', 'tertiary']) ...{
      role: primary,
      'on$role': contrast,
      '${role}container': fill,
      'on${role}container': label,
      '${role}fixed': primary,
      '${role}fixeddim': primary.withValues(alpha: 0.8),
      'on${role}fixed': contrast,
      'on${role}fixedvariant': label,
    },
    'error': resolve(CupertinoColors.systemRed),
    'onerror': contrast,
    'errorcontainer':
        resolve(CupertinoColors.systemRed).withValues(alpha: 0.15),
    'onerrorcontainer': resolve(CupertinoColors.systemRed),
    'surface': background,
    'onsurface': label,
    'surfacebright': resolve(CupertinoColors.systemBackground),
    'surfacedim': secondaryBackground,
    'surfacecontainer': secondaryBackground,
    'surfacecontainerlow': background,
    'surfacecontainerlowest': background,
    'surfacecontainerhigh': resolve(CupertinoColors.tertiarySystemBackground),
    'surfacecontainerhighest':
        resolve(CupertinoColors.tertiarySystemBackground),
    'onsurfacevariant': resolve(CupertinoColors.secondaryLabel),
    'outline': resolve(CupertinoColors.separator),
    'outlinevariant': resolve(CupertinoColors.opaqueSeparator),
    'shadow': CupertinoColors.black,
    'scrim': CupertinoColors.black,
    'surfacetint': primary,
    'inversesurface': label,
    'oninversesurface': background,
    'inverseprimary': primary,
    'disabled': resolve(CupertinoColors.tertiaryLabel),
    if (theme is RufletCupertinoThemeData)
      ...theme.colorOverrides
          .map((key, value) => MapEntry(key, resolve(value))),
  };
  return RufletStyleTheme(
    brightness: brightness,
    colors: colors,
    textStyles: {
      'displaylarge': text.navLargeTitleTextStyle,
      'displaymedium': text.navLargeTitleTextStyle,
      'displaysmall': text.navTitleTextStyle,
      'headlinelarge': text.navLargeTitleTextStyle,
      'headlinemedium': text.navTitleTextStyle,
      'headlinesmall': text.navTitleTextStyle,
      'titlelarge': text.navTitleTextStyle,
      'titlemedium': text.textStyle,
      'titlesmall': text.actionTextStyle,
      'labellarge': text.actionTextStyle,
      'labelmedium': text.tabLabelTextStyle,
      'labelsmall': text.tabLabelTextStyle,
      'bodylarge': text.textStyle,
      'bodymedium': text.textStyle,
      'bodysmall': text.tabLabelTextStyle,
      if (theme is RufletCupertinoThemeData) ...theme.textOverrides,
    },
  );
}

/// Interprets the common theme DSL using only Cupertino defaults and roles.
CupertinoThemeData parseCupertinoTheme(
    dynamic value, BuildContext context, Brightness? brightness,
    {CupertinoThemeData? parentTheme}) {
  var native = (parentTheme ?? const CupertinoThemeData())
      .copyWith(brightness: brightness, applyThemeToAll: true);
  var parserTheme = _styleTheme(native, context);
  final scheme = value?['color_scheme'];
  final primary = parseColor(scheme?['primary'], parserTheme) ??
      parseColor(value?['color_scheme_seed'], parserTheme);
  native = native.copyWith(
    primaryColor: primary,
    primaryContrastingColor: parseColor(scheme?['on_primary'], parserTheme),
    barBackgroundColor:
        parseColor(value?['appbar_theme']?['bgcolor'], parserTheme) ??
            parseColor(scheme?['surface'], parserTheme),
    scaffoldBackgroundColor:
        parseColor(value?['scaffold_bgcolor'], parserTheme) ??
            parseColor(scheme?['surface'], parserTheme),
  );
  parserTheme = _styleTheme(native, context);
  final colors = <String, Color>{
    if (parentTheme is RufletCupertinoThemeData) ...parentTheme.colorOverrides,
    if (primary != null) 'primary': primary,
    if (scheme is Map)
      for (final entry in scheme.entries)
        if (parseColor(entry.value, parserTheme) case final Color color)
          entry.key.toString().replaceAll('_', '').toLowerCase(): color,
    if (parseColor(value?['disabled_color'], parserTheme)
        case final Color color)
      'disabled': color,
  };
  parserTheme = RufletStyleTheme(
    brightness: parserTheme.brightness,
    colors: {...parserTheme.colors, ...colors},
    textStyles: parserTheme.textStyles,
  );
  final fontFamily = value?['font_family'] as String?;
  final foreground = parseColor(scheme?['on_surface'], parserTheme);
  final previousText = native.textTheme;
  TextStyle body(TextStyle style) =>
      style.copyWith(fontFamily: fontFamily, color: foreground);
  TextStyle action(TextStyle style) =>
      style.copyWith(fontFamily: fontFamily, color: primary);
  final textMap = value?['text_theme'];
  final textOverrides = <String, TextStyle?>{
    if (parentTheme is RufletCupertinoThemeData) ...parentTheme.textOverrides,
    if (textMap is Map)
      for (final entry in textMap.entries)
        entry.key.toString().replaceAll('_', '').toLowerCase(): body(
                parserTheme.textStyle(entry.key.toString()) ??
                    previousText.textStyle)
            .merge(parseTextStyle(entry.value, parserTheme)),
  };
  native = native.copyWith(
    textTheme: previousText.copyWith(
      primaryColor: primary,
      textStyle: textOverrides['bodymedium'] ??
          textOverrides['bodylarge'] ??
          body(previousText.textStyle),
      actionTextStyle:
          textOverrides['labellarge'] ?? action(previousText.actionTextStyle),
      actionSmallTextStyle: action(previousText.actionSmallTextStyle),
      tabLabelTextStyle:
          textOverrides['labelmedium'] ?? body(previousText.tabLabelTextStyle),
      navTitleTextStyle:
          textOverrides['titlelarge'] ?? body(previousText.navTitleTextStyle),
      navLargeTitleTextStyle: textOverrides['displaylarge'] ??
          textOverrides['headlinelarge'] ??
          body(previousText.navLargeTitleTextStyle),
      navActionTextStyle: action(previousText.navActionTextStyle),
      pickerTextStyle: body(previousText.pickerTextStyle),
      dateTimePickerTextStyle: body(previousText.dateTimePickerTextStyle),
    ),
  );
  return RufletCupertinoThemeData(
    nativeTheme: native,
    colorOverrides: colors,
    textOverrides: textOverrides,
  );
}

extension CupertinoThemeParsers on Control {
  CupertinoThemeData getCupertinoTheme(
          String propertyName, BuildContext context, Brightness? brightness,
          {CupertinoThemeData? parentTheme}) =>
      parseCupertinoTheme(get(propertyName), context, brightness,
          parentTheme: parentTheme);
}
