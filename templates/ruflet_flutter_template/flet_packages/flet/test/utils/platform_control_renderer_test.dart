import 'package:flet/src/widgets/platform_control_renderer.dart';
import 'package:flet/src/models/page_design.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('neutral theme mode resolves platform brightness', () {
    expect(FletThemeMode.light.usesLight(Brightness.dark), isTrue);
    expect(FletThemeMode.dark.usesLight(Brightness.light), isFalse);
    expect(FletThemeMode.system.usesLight(Brightness.light), isTrue);
    expect(FletThemeMode.system.usesLight(Brightness.dark), isFalse);
    expect(null.usesLight(Brightness.light), isTrue);
  });

  test('Apple platforms resolve to Cupertino controls', () {
    expect(controlDesignForPlatform(TargetPlatform.iOS),
        FletControlDesign.cupertino);
    expect(controlDesignForPlatform(TargetPlatform.macOS),
        FletControlDesign.cupertino);
  });

  test('Android and non-Apple platforms resolve to Material controls', () {
    expect(controlDesignForPlatform(TargetPlatform.android),
        FletControlDesign.material);
    expect(controlDesignForPlatform(TargetPlatform.windows),
        FletControlDesign.material);
    expect(controlDesignForPlatform(TargetPlatform.linux),
        FletControlDesign.material);
    expect(controlDesignForPlatform(TargetPlatform.fuchsia),
        FletControlDesign.material);
  });
}
