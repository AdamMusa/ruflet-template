import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' as material;
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:ruflet/ruflet.dart';

Future<TextStyle?> _pumpText(
  WidgetTester tester,
  TargetPlatform platform,
  Map<String, dynamic> props,
) async {
  final backend = RufletBackend(
    pageUri: Uri.parse('inprocess://text-font-family-fallback-test'),
    assetsDir: '',
    extensions: [],
    multiView: false,
  )..platform = platform;
  final control = Control.fromMap({
    '_c': 'Text',
    '_i': 1,
    'value': 'Hello',
    ...props,
  }, backend);
  final body = Align(
    alignment: Alignment.topLeft,
    child: ControlWidget(control: control),
  );
  await tester.pumpWidget(
    ChangeNotifierProvider.value(
      value: backend,
      child: platform == TargetPlatform.iOS
          ? CupertinoApp(home: body)
          : material.MaterialApp(home: material.Scaffold(body: body)),
    ),
  );
  expect(tester.takeException(), isNull);
  return tester.widget<RichText>(find.byType(RichText)).text.style;
}

void main() {
  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    testWidgets('$platform Text honors Ruby font_family_fallback', (
      tester,
    ) async {
      // Ruflet.text("Hello", font_family: "Inter",
      //   font_family_fallback: ["Arial", "Noto Sans"])
      final style = await _pumpText(tester, platform, {
        'font_family': 'Inter',
        'font_family_fallback': ['Arial', 'Noto Sans'],
      });
      expect(style?.fontFamily, 'Inter');
      expect(style?.fontFamilyFallback, ['Arial', 'Noto Sans']);
    });

    testWidgets('$platform TextStyle honors Ruby font_family_fallback', (
      tester,
    ) async {
      // Ruflet.text("Hello", style: Ruflet::TextStyle.new(
      //   font_family: "Inter", font_family_fallback: ["Arial"]))
      final style = await _pumpText(tester, platform, {
        'style': {
          'font_family': 'Inter',
          'font_family_fallback': ['Arial'],
        },
      });
      expect(style?.fontFamily, 'Inter');
      expect(style?.fontFamilyFallback, ['Arial']);
    });
  }
}
