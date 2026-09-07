import 'package:ruflet/src/widgets/platform_control_renderer.dart';
import 'package:ruflet/src/models/page_design.dart';
import 'package:flutter/widgets.dart';
import 'package:ruflet/src/widgets/page_context.dart';
import 'package:ruflet/src/widgets/platform_design.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renderer uses per-view design before a backend exists',
      (tester) async {
    Widget tree(PageDesign design, TargetPlatform platform) => Directionality(
          textDirection: TextDirection.ltr,
          child: PageContext(
            themeMode: RufletThemeMode.light,
            brightness: Brightness.light,
            widgetsDesign: design,
            targetPlatform: platform,
            child: PlatformControlRenderer(
              material: (_) => const Text('Material'),
              cupertino: (context) =>
                  Text(effectiveTargetPlatform(context).name),
            ),
          ),
        );
    await tester.pumpWidget(tree(PageDesign.cupertino, TargetPlatform.iOS));
    expect(find.text('iOS'), findsOneWidget);
    await tester.pumpWidget(tree(PageDesign.cupertino, TargetPlatform.macOS));
    expect(find.text('macOS'), findsOneWidget);
    await tester.pumpWidget(tree(PageDesign.material, TargetPlatform.android));
    expect(find.text('Material'), findsOneWidget);
  });

  test('neutral theme mode resolves platform brightness', () {
    expect(RufletThemeMode.light.usesLight(Brightness.dark), isTrue);
    expect(RufletThemeMode.dark.usesLight(Brightness.light), isFalse);
    expect(RufletThemeMode.system.usesLight(Brightness.light), isTrue);
    expect(RufletThemeMode.system.usesLight(Brightness.dark), isFalse);
    expect(null.usesLight(Brightness.light), isTrue);
  });

  test('Apple platforms resolve to Cupertino controls', () {
    expect(controlDesignForPlatform(TargetPlatform.iOS),
        RufletControlDesign.cupertino);
    expect(controlDesignForPlatform(TargetPlatform.macOS),
        RufletControlDesign.cupertino);
  });

  test('Android and non-Apple platforms resolve to Material controls', () {
    expect(controlDesignForPlatform(TargetPlatform.android),
        RufletControlDesign.material);
    expect(controlDesignForPlatform(TargetPlatform.windows),
        RufletControlDesign.material);
    expect(controlDesignForPlatform(TargetPlatform.linux),
        RufletControlDesign.material);
    expect(controlDesignForPlatform(TargetPlatform.fuchsia),
        RufletControlDesign.material);
  });
}
