import 'package:flutter/material.dart';

import '../ruflet_backend.dart';
import '../models/control.dart';
import '../models/page_design.dart';
import '../utils/theme.dart';
import '../utils/material_style_theme.dart';
import '../utils/style_theme.dart';

class MaterialControlTheme extends StatelessWidget {
  final Control control;
  final Widget child;

  const MaterialControlTheme({
    super.key,
    required this.control,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final mode = control.getRufletThemeMode("theme_mode");
    final parentTheme = mode == null ? Theme.of(context) : null;
    final platformBrightness = RufletBackend.of(context).platformBrightness;
    final brightness = mode == null
        ? parentTheme?.brightness ?? platformBrightness
        : mode.usesLight(platformBrightness)
            ? Brightness.light
            : Brightness.dark;
    final property =
        brightness == Brightness.dark && control.get("dark_theme") != null
            ? "dark_theme"
            : "theme";
    return Theme(
      data: control.getTheme(
        property,
        context,
        brightness,
        parentTheme: parentTheme,
      ),
      child: Builder(
          builder: (context) => RufletStyleThemeScope(
                data: materialStyleTheme(Theme.of(context)),
                child: child,
              )),
    );
  }
}
