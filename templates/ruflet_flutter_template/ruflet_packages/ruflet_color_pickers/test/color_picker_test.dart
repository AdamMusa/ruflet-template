// ColorPicker mounted from the wire Ruby sends, on both designs: the
// configuration it hands the picker, area geometry, and the color, HSV and
// history events and write-backs.
//
// ruflet-coverage: ColorPicker
import 'package:flutter/widgets.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart' as upstream;
import 'package:flutter_test/flutter_test.dart';
import 'package:ruflet/ruflet.dart' show HexColor;
import 'package:ruflet_color_pickers/src/cupertino_picker/cupertino_picker.dart'
    as native;

import 'support/harness.dart';

const _red = Color(0xffff0000);
const _green = Color(0xff00ff00);
const _blue = Color(0xff0000ff);

Map<String, dynamic> wire(Map<String, dynamic> props) =>
    {'_c': 'ColorPicker', '_i': 1, ...props};

dynamic colorPicker(WidgetTester tester) =>
    tester.widget(byTypeName('ColorPicker'));

/// The color the picker's own state currently shows (its first indicator).
Color shownColor(WidgetTester tester) {
  final dynamic indicator = tester.widget(byTypeName('ColorIndicator').first);
  return (indicator.hsvColor as HSVColor).toColor();
}

void main() {
  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    group('$platform', () {
      testWidgets('ColorPicker hands Ruby props to the picker', (tester) async {
        await mountWire(
            tester,
            platform,
            wire({
              'color': '#ff0000',
              'color_picker_width': 200,
              'picker_area_height_percent': 0.5,
              'picker_area_border_radius': 8,
              'enable_alpha': false,
              'display_thumb_color': false,
              'hex_input_bar': false,
              'palette_type': 'hsl_with_hue',
              'label_types': ['hex', 'rgb'],
              'color_history': ['#00ff00', '#0000ff'],
            }));
        final dynamic picker = colorPicker(tester);
        expect(
            picker,
            platform == TargetPlatform.iOS
                ? isA<native.ColorPicker>()
                : isA<upstream.ColorPicker>());
        expect(picker.pickerColor, _red);
        expect(picker.pickerHsvColor, isNull);
        expect(picker.colorPickerWidth, 200);
        expect(picker.pickerAreaHeightPercent, 0.5);
        expect(picker.pickerAreaBorderRadius, BorderRadius.circular(8));
        expect(picker.enableAlpha, isFalse);
        expect(picker.displayThumbColor, isFalse);
        expect(picker.hexInputBar, isFalse);
        expect((picker.paletteType as Enum).name, 'hslWithHue');
        expect([for (final t in picker.labelTypes) (t as Enum).name],
            ['hex', 'rgb']);
        expect(picker.colorHistory, [_green, _blue]);

        // The area is color_picker_width wide and height_percent of that.
        expect(tester.getSize(byTypeName('ColorPickerArea')),
            const Size(200, 100));
        // Hue slider only: no alpha slider.
        expect(byTypeName('ColorPickerSlider'), findsOneWidget);
        // The current color, then one indicator per history entry.
        expect(byTypeName('ColorIndicator'), findsNWidgets(3));
        expect(shownColor(tester), _red);
        expect(tester.takeException(), isNull);
      });

      testWidgets('ColorPicker defaults match flutter_colorpicker',
          (tester) async {
        await mountWire(tester, platform, wire({'color': '#00ff00'}));
        final dynamic picker = colorPicker(tester);
        expect(picker.colorPickerWidth, 300);
        expect(picker.pickerAreaHeightPercent, 1.0);
        expect(picker.enableAlpha, isTrue);
        expect(picker.hexInputBar, isTrue);
        expect((picker.paletteType as Enum).name, 'hsvWithHue');
        expect([for (final t in picker.labelTypes) (t as Enum).name],
            ['rgb', 'hsv', 'hsl']);
        expect(picker.colorHistory, isNull);
        expect(tester.getSize(byTypeName('ColorPickerArea')),
            const Size(300, 300));
        // Hue and alpha sliders.
        expect(byTypeName('ColorPickerSlider'), findsNWidgets(2));
      });

      testWidgets('ColorPicker hsv_color takes precedence over color',
          (tester) async {
        await mountWire(
            tester,
            platform,
            wire({
              'color': '#ff0000',
              'hsv_color': {
                'alpha': 1,
                'hue': 120,
                'saturation': 0.5,
                'value': 0.5
              },
            }));
        const hsv = HSVColor.fromAHSV(1, 120, 0.5, 0.5);
        expect(colorPicker(tester).pickerHsvColor, hsv);
        expect(shownColor(tester), hsv.toColor());
      });

      testWidgets('ColorPicker area drag sends color and HSV events',
          (tester) async {
        final m = await mountWire(
            tester,
            platform,
            wire({
              'color': '#ff0000',
              'color_picker_width': 200,
              'on_color_change': true,
              'on_hsv_color_change': true,
            }));
        // hsv_with_hue: x is saturation, y is (1 - value).
        await tester.tapAt(tester.getCenter(byTypeName('ColorPickerArea')));
        await tester.pumpAndSettle();
        const picked = HSVColor.fromAHSV(1, 0, 0.5, 0.5);
        expect(m.backend.eventData('color_change'), [picked.toColor().toHex()]);
        expect(m.backend.eventData('hsv_color_change'), [
          {'alpha': 1.0, 'hue': 0.0, 'saturation': 0.5, 'value': 0.5}
        ]);
        expect(m.backend.lastWriteBack('hsv_color'),
            {'alpha': 1.0, 'hue': 0.0, 'saturation': 0.5, 'value': 0.5});
        expect(shownColor(tester), picked.toColor());
      });

      testWidgets('ColorPicker writes a pick back to Ruby color',
          (tester) async {
        // Ruby sends and reads `color`; the renderer used to write the pick
        // to `picker_color`, which Ruby never sends, leaving `color` stale.
        final m = await mountWire(tester, platform, wire({'color': '#ff0000'}));
        await tester.tapAt(tester.getCenter(byTypeName('ColorPickerArea')));
        await tester.pumpAndSettle();
        final picked =
            const HSVColor.fromAHSV(1, 0, 0.5, 0.5).toColor().toHex();
        expect(m.backend.lastWriteBack('color'), picked);
        expect(m.root.get('color'), picked);
        expect(m.backend.writtenBack, isNot(contains('picker_color')));
      });

      testWidgets('ColorPicker sends no event unless Ruby subscribed',
          (tester) async {
        final m = await mountWire(tester, platform, wire({'color': '#ff0000'}));
        await tester.tapAt(tester.getCenter(byTypeName('ColorPickerArea')));
        await tester.pumpAndSettle();
        expect(m.backend.events, isEmpty);
        expect(m.backend.writtenBack, contains('hsv_color'));
      });

      testWidgets('ColorPicker indicator tap adds to the history',
          (tester) async {
        final m = await mountWire(
            tester,
            platform,
            wire({
              'color': '#0000ff',
              'color_history': ['#00ff00'],
              'on_history_change': true,
            }));
        await tester.tap(byTypeName('ColorIndicator').first);
        await tester.pumpAndSettle();
        expect(m.backend.eventData('history_change'), [
          ['#ff00ff00', '#ff0000ff']
        ]);
        expect(m.backend.lastWriteBack('color_history'),
            ['#ff00ff00', '#ff0000ff']);
        expect(byTypeName('ColorIndicator'), findsNWidgets(3));
      });

      testWidgets('ColorPicker follows a Ruby color update after a pick',
          (tester) async {
        // A pick writes back hsv_color too; a later Ruby `color` must still
        // win over that written-back HSV value.
        final m = await mountWire(tester, platform, wire({'color': '#ff0000'}));
        await tester.tapAt(tester.getCenter(byTypeName('ColorPickerArea')));
        await tester.pumpAndSettle();
        expect(shownColor(tester), isNot(_red));

        await rubyPatch(tester, m.root, {'color': '#0000ff'});
        expect(shownColor(tester), _blue);
        expect(colorPicker(tester).pickerColor, _blue);

        // An unrelated update keeps Ruby's color.
        await rubyPatch(tester, m.root, {'enable_alpha': false});
        expect(shownColor(tester), _blue);

        // A later pick is HSV-exact again.
        await tester.tapAt(tester.getCenter(byTypeName('ColorPickerArea')));
        await tester.pumpAndSettle();
        expect(colorPicker(tester).pickerHsvColor,
            const HSVColor.fromAHSV(1, 240, 0.5, 0.5));
      });

      testWidgets('ColorPicker follows a Ruby color sent with hsv_color',
          (tester) async {
        final m = await mountWire(
            tester,
            platform,
            wire({
              'color': '#ff0000',
              'hsv_color': {'alpha': 1, 'hue': 0, 'saturation': 1, 'value': 1},
            }));
        await rubyPatch(tester, m.root, {'color': '#00ff00'});
        expect(shownColor(tester), _green);
        await rubyPatch(tester, m.root, {
          'hsv_color': {'alpha': 1, 'hue': 240, 'saturation': 1, 'value': 1}
        });
        expect(shownColor(tester), _blue);
      });

      testWidgets('ColorPicker follows a Ruby hsv_color update',
          (tester) async {
        final m = await mountWire(
            tester,
            platform,
            wire({
              'hsv_color': {'alpha': 1, 'hue': 0, 'saturation': 1, 'value': 1},
            }));
        expect(shownColor(tester), _red);
        await rubyPatch(tester, m.root, {
          'hsv_color': {'alpha': 1, 'hue': 240, 'saturation': 1, 'value': 1}
        });
        expect(shownColor(tester), _blue);
      });
    });
  }
}
