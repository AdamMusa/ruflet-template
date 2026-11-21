// MaterialPicker mounted from the wire Ruby sends, on both designs: the
// swatch configuration, selected shade geometry, and the color and primary
// events and write-back.
//
// ruflet-coverage: MaterialPicker
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ruflet_color_pickers/src/cupertino_picker/cupertino_picker.dart'
    as native;
import 'package:ruflet_color_pickers/src/material_swatch_picker/material_swatch_picker.dart';

import 'support/harness.dart';

/// The swatch picker the design renders.
String swatchPicker(TargetPlatform platform) => platform == TargetPlatform.iOS
    ? 'CupertinoSwatchPicker'
    : 'MaterialSwatchPicker';

/// The shade or primary bubble filled with [argb].
Finder bubble(int argb, {required bool primary}) =>
    find.byWidgetPredicate((w) =>
        w is AnimatedContainer &&
        w.decoration is BoxDecoration &&
        ((w.decoration as BoxDecoration).shape == BoxShape.circle) == primary &&
        (w.decoration as BoxDecoration).color?.toARGB32() == argb);

/// The width of the shade bar filled with [argb] (250 when selected).
double shadeWidth(WidgetTester tester, int argb) => tester
    .widget<AnimatedContainer>(bubble(argb, primary: false))
    .constraints!
    .maxWidth;

void main() {
  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    group('$platform', () {
      testWidgets('MaterialPicker selects Ruby color in its swatch',
          (tester) async {
        await mountWire(tester, platform, {
          '_c': 'MaterialPicker',
          '_i': 1,
          'color': '#2196f3', // blue 500
          'enable_label': true,
          'portrait_only': true,
        });
        final dynamic picker =
            tester.widget(byTypeName(swatchPicker(platform)));
        expect(
            picker,
            platform == TargetPlatform.iOS
                ? isA<native.CupertinoSwatchPicker>()
                : isA<MaterialSwatchPicker>());
        expect(picker.pickerColor, const Color(0xff2196f3));
        expect(picker.enableLabel, isTrue);
        expect(picker.portraitOnly, isTrue);
        expect(tester.getSize(byTypeName(swatchPicker(platform))),
            const Size(350, 500));
        // The blue shades are listed, 500 selected (wider bar).
        expect(find.text('#2196F3  '), findsOneWidget);
        expect(find.text('#BBDEFB  '), findsOneWidget);
        expect(shadeWidth(tester, 0xff2196f3), 250);
        expect(shadeWidth(tester, 0xffbbdefb), 230);
        expect(find.text('#F44336  '), findsNothing);
        expect(tester.takeException(), isNull);
      });

      testWidgets('MaterialPicker without enable_label draws bare shades',
          (tester) async {
        await mountWire(tester, platform,
            {'_c': 'MaterialPicker', '_i': 1, 'color': '#2196f3'});
        expect(find.text('#2196F3  '), findsNothing);
        expect(shadeWidth(tester, 0xff2196f3), 250);
      });

      testWidgets('MaterialPicker shade tap sends color_change and writes back',
          (tester) async {
        final m = await mountWire(tester, platform, {
          '_c': 'MaterialPicker',
          '_i': 1,
          'color': '#2196f3',
          'enable_label': true,
          'on_color_change': true,
        });
        await tester.tap(find.text('#1E88E5  ')); // blue 600
        await tester.pumpAndSettle();
        expect(m.backend.events,
            [(id: 1, name: 'color_change', data: '#ff1e88e5')]);
        expect(m.root.get('color'), '#ff1e88e5');
        expect(shadeWidth(tester, 0xff1e88e5), 250);
        expect(shadeWidth(tester, 0xff2196f3), 230);
      });

      testWidgets('MaterialPicker primary tap sends primary_change',
          (tester) async {
        final m = await mountWire(tester, platform, {
          '_c': 'MaterialPicker',
          '_i': 1,
          'color': '#2196f3',
          'enable_label': true,
          'on_primary_change': true,
          'on_color_change': true,
        });
        await tester.tap(bubble(0xff9c27b0, primary: true)); // purple
        await tester.pumpAndSettle();
        expect(m.backend.events,
            [(id: 1, name: 'primary_change', data: '#ff9c27b0')]);
        // The purple shades replace the blue ones; no color is picked yet.
        expect(find.text('#9C27B0  '), findsOneWidget);
        expect(find.text('#2196F3  '), findsNothing);
        expect(m.backend.writtenBack, isEmpty);
      });

      testWidgets('MaterialPicker follows a Ruby color update', (tester) async {
        // The swatch kept the shade of its first build, so a Ruby `color`
        // update left the old shade list and selection.
        final m = await mountWire(tester, platform, {
          '_c': 'MaterialPicker',
          '_i': 1,
          'color': '#2196f3',
          'enable_label': true,
          'on_color_change': true,
        });
        await rubyPatch(tester, m.root, {'color': '#f44336'}); // red 500
        expect(find.text('#F44336  '), findsOneWidget);
        expect(find.text('#2196F3  '), findsNothing);
        expect(shadeWidth(tester, 0xfff44336), 250);

        await tester.tap(find.text('#E53935  ')); // red 600
        await tester.pumpAndSettle();
        expect(m.backend.eventData('color_change'), ['#ffe53935']);
        expect(shadeWidth(tester, 0xffe53935), 250);
      });

      testWidgets(
          'MaterialPicker keeps its swatch for a pick and rebuilds it for Ruby',
          (tester) async {
        final m = await mountWire(tester, platform, {
          '_c': 'MaterialPicker',
          '_i': 1,
          'color': '#2196f3',
          'enable_label': true,
          'width': 350,
          'on_color_change': true,
        });
        final first = tester.state(byTypeName(swatchPicker(platform)));
        await tester.tap(find.text('#1E88E5  ')); // blue 600
        await tester.pumpAndSettle();
        await rubyPatch(tester, m.root, {'width': 360});
        expect(tester.state(byTypeName(swatchPicker(platform))), same(first));

        await rubyPatch(tester, m.root, {'color': '#f44336'}); // red 500
        expect(tester.state(byTypeName(swatchPicker(platform))),
            isNot(same(first)));
        expect(shadeWidth(tester, 0xfff44336), 250);
      });

      testWidgets('MaterialPicker sends no event unless Ruby subscribed',
          (tester) async {
        final m = await mountWire(tester, platform, {
          '_c': 'MaterialPicker',
          '_i': 1,
          'color': '#2196f3',
          'enable_label': true,
        });
        await tester.tap(bubble(0xff9c27b0, primary: true));
        await tester.pumpAndSettle();
        await tester.tap(find.text('#9C27B0  '));
        await tester.pumpAndSettle();
        expect(m.backend.events, isEmpty);
        expect(m.backend.lastWriteBack('color'), '#ff9c27b0');
      });
    });
  }
}
