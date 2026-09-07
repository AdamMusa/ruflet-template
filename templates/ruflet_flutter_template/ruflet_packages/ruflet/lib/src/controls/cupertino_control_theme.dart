import 'package:flutter/cupertino.dart';

import '../ruflet_backend.dart';
import '../models/control.dart';
import '../models/page_design.dart';
import '../utils/cupertino_theme.dart';
import '../utils/platform_theme.dart';
import '../utils/style_theme.dart';

class CupertinoControlTheme extends StatelessWidget {
  final Control control;
  final Widget child;

  const CupertinoControlTheme({
    super.key,
    required this.control,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final mode = control.getRufletThemeMode("theme_mode");
    final platformBrightness = RufletBackend.of(context).platformBrightness;
    final ambientBrightness =
        CupertinoTheme.of(context).brightness ?? platformBrightness;
    final brightness = mode == null
        ? ambientBrightness
        : mode.usesLight(platformBrightness)
            ? Brightness.light
            : Brightness.dark;
    final property =
        brightness == Brightness.dark && control.get("dark_theme") != null
            ? "dark_theme"
            : "theme";
    return CupertinoTheme(
      data: control.getCupertinoTheme(property, context, brightness,
          parentTheme: context
              .dependOnInheritedWidgetOfExactType<InheritedCupertinoTheme>()
              ?.theme
              .data),
      child: Builder(
        builder: (context) => RufletStyleThemeScope(
          data: cupertinoStyleTheme(context),
          child: DefaultTextStyle(
            style: CupertinoTheme.of(context).textTheme.textStyle,
            child: child,
          ),
        ),
      ),
    );
  }
}
