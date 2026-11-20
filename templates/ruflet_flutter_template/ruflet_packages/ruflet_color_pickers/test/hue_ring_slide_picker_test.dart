// HueRingPicker and SlidePicker mounted from the wire Ruby sends, on both
// designs: configuration, ring/slider geometry, events and Ruby updates.
//
// ruflet-coverage: HueRingPicker SlidePicker
import 'package:flutter/widgets.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart' as upstream;
import 'package:flutter_test/flutter_test.dart';
import 'package:ruflet/ruflet.dart' show HexColor;
import 'package:ruflet_color_pickers/src/cupertino_picker/cupertino_picker.dart'
    as native;

import 'support/harness.dart';

/// The color the ring (or first slider) currently shows.
HSVColor shownHsv(WidgetTester tester, String part) {
  final dynamic widget = tester.widget(byTypeName(part).first);
  return widget.hsvColor as HSVColor;
}

/// The texts inside [finder], in tree order.
List<String> texts(WidgetTester tester, Finder finder) => [
      for (final t in tester.widgetList<Text>(
          find.descendant(of: finder, matching: find.byType(Text))))
        if (t.data != null) t.data!
    ];

void main() {
  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    group('$platform', () {
      testWidgets('HueRingPicker hands Ruby props to the ring', (tester) async {
        await mountWire(tester, platform, {
          '_c': 'HueRingPicker',
          '_i': 1,
          'color': '#0000ff',
          'color_picker_height': 200,
          'hue_ring_stroke_width': 12,
          'enable_alpha': true,
          'portrait_only': true,
          'picker_area_border_radius': 6,
        });
        final dynamic picker = tester.widget(byTypeName('HueRingPicker'));
        expect(
            picker,
            platform == TargetPlatform.iOS
                ? isA<native.HueRingPicker>()
                : isA<upstream.HueRingPicker>());
        expect(picker.pickerColor, const Color(0xff0000ff));
        expect(picker.colorPickerHeight, 200);
        expect(picker.hueRingStrokeWidth, 12);
        expect(picker.enableAlpha, isTrue);
        expect(picker.portraitOnly, isTrue);
        expect(picker.pickerAreaBorderRadius, BorderRadius.circular(6));

        final dynamic ring = tester.widget(byTypeName('ColorPickerHueRing'));
        expect(ring.strokeWidth, 12);
        expect(tester.getSize(byTypeName('ColorPickerHueRing')),
            const Size(200, 200));
        // The HSV square inside the ring.
        expect(tester.getSize(byTypeName('ColorPickerArea')),
            const Size(125, 125));
        // enable_alpha adds the alpha slider.
        expect(byTypeName('ColorPickerSlider'), findsOneWidget);
        expect(shownHsv(tester, 'ColorPickerHueRing').hue, 240);
        expect(tester.takeException(), isNull);
      });

      testWidgets('HueRingPicker defaults match flutter_colorpicker',
          (tester) async {
        await mountWire(tester, platform,
            {'_c': 'HueRingPicker', '_i': 1, 'color': '#0000ff'});
        final dynamic picker = tester.widget(byTypeName('HueRingPicker'));
        expect(picker.colorPickerHeight, 250);
        expect(picker.hueRingStrokeWidth, 20);
        expect(picker.enableAlpha, isFalse);
        expect(picker.portraitOnly, isFalse);
        expect(byTypeName('ColorPickerSlider'), findsNothing);
        expect(tester.getSize(byTypeName('ColorPickerHueRing')),
            const Size(250, 250));
      });

      testWidgets('HueRingPicker ring tap sends color_change and writes back',
          (tester) async {
        final m = await mountWire(tester, platform, {
          '_c': 'HueRingPicker',
          '_i': 1,
          'color': '#0000ff',
          'color_picker_height': 200,
          'on_color_change': true,
        });
        // The top of the ring is hue 90.
        final ring = tester.getRect(byTypeName('ColorPickerHueRing'));
        await tester.tapAt(Offset(ring.center.dx, ring.top + 2));
        await tester.pumpAndSettle();
        final picked = HSVColor.fromColor(const Color(0xff0000ff))
            .withHue(90)
            .toColor()
            .toHex();
        expect(m.backend.events, [(id: 1, name: 'color_change', data: picked)]);
        expect(m.root.get('color'), picked);
        expect(shownHsv(tester, 'ColorPickerHueRing').hue, closeTo(90, 0.5));
      });

      testWidgets('HueRingPicker sends no event unless Ruby subscribed',
          (tester) async {
        final m = await mountWire(tester, platform, {
          '_c': 'HueRingPicker',
          '_i': 1,
          'color': '#0000ff',
          'color_picker_height': 200,
        });
        final ring = tester.getRect(byTypeName('ColorPickerHueRing'));
        await tester.tapAt(Offset(ring.center.dx, ring.top + 2));
        await tester.pumpAndSettle();
        expect(m.backend.events, isEmpty);
        expect(m.backend.writtenBack, {'color'});
      });

      testWidgets('HueRingPicker follows a Ruby color update', (tester) async {
        final m = await mountWire(tester, platform,
            {'_c': 'HueRingPicker', '_i': 1, 'color': '#0000ff'});
        await rubyPatch(tester, m.root, {'color': '#00ff00'});
        expect(shownHsv(tester, 'ColorPickerHueRing').hue, 120);
      });

      testWidgets('SlidePicker hands Ruby props to the sliders',
          (tester) async {
        await mountWire(tester, platform, {
          '_c': 'SlidePicker',
          '_i': 1,
          'color': '#123456',
          'color_model': 'rgb',
          'enable_alpha': false,
          'slider_size': {'width': 300, 'height': 30},
          'indicator_size': {'width': 200, 'height': 40},
          'indicator_border_radius': 4,
          'label_types': ['hex'],
        });
        final dynamic picker = tester.widget(byTypeName('SlidePicker'));
        expect(
            picker,
            platform == TargetPlatform.iOS
                ? isA<native.SlidePicker>()
                : isA<upstream.SlidePicker>());
        expect(picker.pickerColor, const Color(0xff123456));
        expect((picker.colorModel as Enum).name, 'rgb');
        expect(picker.enableAlpha, isFalse);
        expect(picker.sliderSize, const Size(300, 30));
        expect(picker.indicatorSize, const Size(200, 40));
        expect(picker.indicatorBorderRadius, BorderRadius.circular(4));
        expect([for (final t in picker.labelTypes) (t as Enum).name], ['hex']);

        // One slider per RGB channel, each slider_size, with its letter and
        // the channel value of #123456.
        expect(byTypeName('ColorPickerSlider'), findsNWidgets(3));
        expect(texts(tester, byTypeName('SlidePicker')),
            containsAllInOrder(['R', '18', 'G', '52', 'B', '86']));
        final sliderRow = find.ancestor(
            of: byTypeName('ColorPickerSlider').first,
            matching: find.byType(SizedBox));
        expect(tester.getSize(sliderRow.first), const Size(300, 30));
        expect(byTypeName('ColorPickerLabel'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('SlidePicker hsv model, alpha and hidden labels',
          (tester) async {
        await mountWire(tester, platform, {
          '_c': 'SlidePicker',
          '_i': 1,
          'color': '#ff0000',
          'color_model': 'hsv',
          'show_slider_text': false,
          'show_params': false,
          'show_indicator': false,
          'show_label': false,
          'label_types': ['hex'],
        });
        // Hue, saturation, value, then alpha (enable_alpha defaults on).
        expect(byTypeName('ColorPickerSlider'), findsNWidgets(4));
        expect(texts(tester, byTypeName('SlidePicker')), isEmpty);
        expect(byTypeName('ColorPickerLabel'), findsNothing);
      });

      testWidgets('SlidePicker slider tap sends color_change', (tester) async {
        final m = await mountWire(tester, platform, {
          '_c': 'SlidePicker',
          '_i': 1,
          'color': '#123456',
          'enable_alpha': false,
          'on_color_change': true,
        });
        // The middle of the red track is red 128.
        await tester
            .tapAt(tester.getCenter(byTypeName('ColorPickerSlider').first));
        await tester.pumpAndSettle();
        expect(m.backend.events,
            [(id: 1, name: 'color_change', data: '#ff803456')]);
        expect(texts(tester, byTypeName('SlidePicker')), contains('128'));
      });

      testWidgets('SlidePicker writes a pick back and keeps it on updates',
          (tester) async {
        final m = await mountWire(tester, platform, {
          '_c': 'SlidePicker',
          '_i': 1,
          'color': '#123456',
          'enable_alpha': false,
          'on_color_change': true,
        });
        await tester
            .tapAt(tester.getCenter(byTypeName('ColorPickerSlider').first));
        await tester.pumpAndSettle();
        expect(m.backend.eventData('color_change'), ['#ff803456']);
        expect(m.backend.lastWriteBack('color'), '#ff803456');
        expect(m.root.get('color'), '#ff803456');

        // Unrelated Ruby updates (the first one also remounts the sliders)
        // used to show Ruby's red 18 again.
        for (final width in [300, 320]) {
          await rubyPatch(tester, m.root, {'width': width});
          expect(texts(tester, byTypeName('SlidePicker')),
              containsAllInOrder(['R', '128', 'G', '52', 'B', '86']));
        }

        // Ruby setting its first color again now reaches the sliders.
        await rubyPatch(tester, m.root, {'color': '#123456'});
        expect(texts(tester, byTypeName('SlidePicker')),
            containsAllInOrder(['R', '18', 'G', '52', 'B', '86']));
      });

      testWidgets('SlidePicker sends no event unless Ruby subscribed',
          (tester) async {
        final m = await mountWire(tester, platform,
            {'_c': 'SlidePicker', '_i': 1, 'color': '#123456'});
        await tester
            .tapAt(tester.getCenter(byTypeName('ColorPickerSlider').first));
        await tester.pumpAndSettle();
        expect(m.backend.events, isEmpty);
      });

      testWidgets('SlidePicker follows a Ruby color update', (tester) async {
        final m = await mountWire(tester, platform,
            {'_c': 'SlidePicker', '_i': 1, 'color': '#123456'});
        await rubyPatch(tester, m.root, {'color': '#abcdef'});
        expect(texts(tester, byTypeName('SlidePicker')),
            containsAllInOrder(['R', '171', 'G', '205', 'B', '239']));
      });
    });
  }
}
