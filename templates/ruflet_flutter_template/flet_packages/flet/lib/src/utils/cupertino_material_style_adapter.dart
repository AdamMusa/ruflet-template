import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Converts the active Cupertino typography and colors into the legacy
/// ThemeData-shaped parser input used by Flet's wire style schema.
///
/// This is a schema compatibility adapter only. Cupertino renderers never use
/// the returned object to choose or build Material widgets.
ThemeData materialStyleAdapterFromCupertino(BuildContext context) {
  final theme = CupertinoTheme.of(context);
  final text = theme.textTheme;
  return ThemeData(
    brightness: theme.brightness ?? Brightness.light,
    primaryColor: theme.primaryColor,
    scaffoldBackgroundColor: theme.scaffoldBackgroundColor,
    colorScheme: ColorScheme.fromSeed(
      seedColor: theme.primaryColor,
      brightness: theme.brightness ?? Brightness.light,
    ),
    textTheme: TextTheme(
      displayLarge: text.navLargeTitleTextStyle,
      displayMedium: text.navLargeTitleTextStyle,
      displaySmall: text.navTitleTextStyle,
      headlineLarge: text.navLargeTitleTextStyle,
      headlineMedium: text.navTitleTextStyle,
      headlineSmall: text.navTitleTextStyle,
      titleLarge: text.navTitleTextStyle,
      titleMedium: text.textStyle,
      titleSmall: text.actionTextStyle,
      labelLarge: text.actionTextStyle,
      labelMedium: text.tabLabelTextStyle,
      labelSmall: text.tabLabelTextStyle,
      bodyLarge: text.textStyle,
      bodyMedium: text.textStyle,
      bodySmall: text.tabLabelTextStyle,
    ),
  );
}

/// Returns the legacy ThemeData-shaped schema parser input without requiring
/// platform-neutral controls to import the Material widget library.
ThemeData materialStyleSchemaTheme(BuildContext context) => Theme.of(context);
