import 'package:flutter/widgets.dart';

enum PageDesign { material, cupertino }

/// Design-system-neutral theme mode used by page and control protocol state.
enum FletThemeMode { system, light, dark }

extension FletThemeModeBrightness on FletThemeMode? {
  bool usesLight(Brightness platformBrightness) => switch (this) {
        FletThemeMode.light => true,
        FletThemeMode.dark => false,
        FletThemeMode.system || null => platformBrightness == Brightness.light,
      };
}
