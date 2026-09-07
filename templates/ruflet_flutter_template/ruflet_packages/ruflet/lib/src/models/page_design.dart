import 'package:flutter/widgets.dart';

enum PageDesign { material, cupertino }

/// Design-system-neutral theme mode used by page and control protocol state.
enum RufletThemeMode { system, light, dark }

extension RufletThemeModeBrightness on RufletThemeMode? {
  bool usesLight(Brightness platformBrightness) => switch (this) {
        RufletThemeMode.light => true,
        RufletThemeMode.dark => false,
        RufletThemeMode.system || null => platformBrightness == Brightness.light,
      };
}
