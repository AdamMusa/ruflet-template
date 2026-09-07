import 'package:flutter/widgets.dart';

/// Design-neutral values consumed by the wire style parsers.
///
/// Each renderer supplies its native colors and typography. Parsers never
/// construct, look up, or convert an opposite-design theme.
@immutable
class RufletStyleTheme {
  final Brightness brightness;
  final Map<String, Color> colors;
  final Map<String, TextStyle?> textStyles;

  const RufletStyleTheme({
    this.brightness = Brightness.light,
    this.colors = const {},
    this.textStyles = const {},
  });

  Color? color(String name) => colors[name.toLowerCase().replaceAll('_', '')];

  TextStyle? textStyle(String name) =>
      textStyles[name.toLowerCase().replaceAll('_', '')];

  static RufletStyleTheme of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<RufletStyleThemeScope>();
    if (scope != null) return scope.data;
    // Also supports design-neutral controls embedded in a plain WidgetsApp.
    return RufletStyleTheme(
      brightness:
          MediaQuery.maybePlatformBrightnessOf(context) ?? Brightness.light,
      textStyles: {'bodymedium': DefaultTextStyle.of(context).style},
    );
  }
}

class RufletStyleThemeScope extends InheritedWidget {
  final RufletStyleTheme data;

  const RufletStyleThemeScope({
    super.key,
    required this.data,
    required super.child,
  });

  @override
  bool updateShouldNotify(RufletStyleThemeScope oldWidget) =>
      data != oldWidget.data;
}
