import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Explicit platform override for embedded math, independent of Material Theme.
class MathSelectionPlatform extends InheritedWidget {
  const MathSelectionPlatform(
      {super.key, required this.platform, required super.child});

  final TargetPlatform platform;

  static TargetPlatform of(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<MathSelectionPlatform>()
          ?.platform ??
      defaultTargetPlatform;

  static bool usesCupertino(BuildContext context) {
    final platform = of(context);
    return platform == TargetPlatform.iOS || platform == TargetPlatform.macOS;
  }

  @override
  bool updateShouldNotify(MathSelectionPlatform oldWidget) =>
      platform != oldWidget.platform;
}
