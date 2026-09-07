import 'package:flutter/widgets.dart';

/// Design-neutral values consumed by the wire style parsers.
///
/// Each renderer supplies its native colors and typography. Parsers never
/// construct, look up, or convert an opposite-design theme.
@immutable
class FletStyleTheme {
  final Brightness brightness;
  final Map<String, Color> colors;
  final Map<String, TextStyle?> textStyles;

  const FletStyleTheme({
    this.brightness = Brightness.light,
    this.colors = const {},
    this.textStyles = const {},
  });

  Color? color(String name) => colors[name.toLowerCase().replaceAll('_', '')];

  TextStyle? textStyle(String name) =>
      textStyles[name.toLowerCase().replaceAll('_', '')];

  static FletStyleTheme of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<FletStyleThemeScope>();
    if (scope != null) return scope.data;
    // Also supports design-neutral controls embedded in a plain WidgetsApp.
    return FletStyleTheme(
      brightness:
          MediaQuery.maybePlatformBrightnessOf(context) ?? Brightness.light,
      textStyles: {'bodymedium': DefaultTextStyle.of(context).style},
    );
  }
}

class FletStyleThemeScope extends InheritedWidget {
  final FletStyleTheme data;

  const FletStyleThemeScope({
    super.key,
    required this.data,
    required super.child,
  });

  @override
  bool updateShouldNotify(FletStyleThemeScope oldWidget) =>
      data != oldWidget.data;
}
