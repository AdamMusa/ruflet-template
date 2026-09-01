import 'package:flutter/widgets.dart';

import '../models/page_design.dart';

class PageContext extends InheritedWidget {
  final PageDesign widgetsDesign;
  final FletThemeMode? themeMode;
  final Brightness? brightness;

  const PageContext(
      {required this.themeMode,
      required this.brightness,
      required this.widgetsDesign,
      required super.child,
      super.key});

  @override
  bool updateShouldNotify(covariant PageContext oldWidget) {
    return themeMode != oldWidget.themeMode ||
        brightness != oldWidget.brightness ||
        widgetsDesign != oldWidget.widgetsDesign;
  }

  static PageContext? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<PageContext>();
}
