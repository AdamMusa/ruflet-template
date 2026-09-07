import 'package:flutter/widgets.dart';

import '../models/page_design.dart';

class PageContext extends InheritedWidget {
  final PageDesign widgetsDesign;
  final RufletThemeMode? themeMode;
  final Brightness? brightness;
  final TargetPlatform? targetPlatform;

  const PageContext(
      {required this.themeMode,
      required this.brightness,
      required this.widgetsDesign,
      this.targetPlatform,
      required super.child,
      super.key});

  @override
  bool updateShouldNotify(covariant PageContext oldWidget) {
    return themeMode != oldWidget.themeMode ||
        brightness != oldWidget.brightness ||
        targetPlatform != oldWidget.targetPlatform ||
        widgetsDesign != oldWidget.widgetsDesign;
  }

  static PageContext? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<PageContext>();
}
