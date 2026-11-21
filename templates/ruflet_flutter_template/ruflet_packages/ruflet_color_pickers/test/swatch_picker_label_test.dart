import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ruflet_color_pickers/src/cupertino_picker/cupertino_picker.dart'
    as native;

void main() {
  testWidgets('swatch labels show #RRGGBB from the color channels',
      (tester) async {
    await tester.pumpWidget(CupertinoApp(
      home: CupertinoPageScaffold(
        child: Center(
          child: native.CupertinoSwatchPicker(
            pickerColor: const Color(0xFFFFEBEE), // red 50
            onColorChanged: (_) {},
            enableLabel: true,
            portraitOnly: true,
          ),
        ),
      ),
    ));

    // Red shades, in palette order: 50 and 100.
    expect(find.text('#FFEBEE  '), findsOneWidget);
    expect(find.text('#FFCDD2  '), findsOneWidget);
    // Never the Color.toString() format (Flutter 3.27+:
    // "Color(alpha: 1.0000, red: ...)").
    expect(find.textContaining('COLOR('), findsNothing);
    expect(find.textContaining('ALPHA'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  test('colorToHex formats from the 8-bit channels', () {
    // A float color that is not exactly representable in 8 bits.
    const color =
        Color.from(alpha: 0.5004, red: 0.1234, green: 0.9876, blue: 0.5);
    expect(native.colorToHex(color, includeHashSign: true), '#801FFC80');
    expect(
        native.colorToHex(const Color(0xFFF44336),
            includeHashSign: true, enableAlpha: false),
        '#F44336');
  });
}
