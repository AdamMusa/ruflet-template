// BlockPicker and MultipleChoiceBlockPicker mounted from the wire Ruby
// sends, on both designs: palette, selection, events and write-backs.
//
// ruflet-coverage: BlockPicker MultipleChoiceBlockPicker
import 'package:flutter/widgets.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart' as upstream;
import 'package:flutter_test/flutter_test.dart';
import 'package:ruflet_color_pickers/src/cupertino_picker/cupertino_picker.dart'
    as native;

import 'support/harness.dart';

const _red = Color(0xffff0000);
const _green = Color(0xff00ff00);
const _blue = Color(0xff0000ff);

/// The swatch colors a block picker draws, in order.
List<int> swatchColors(WidgetTester tester, String picker) => [
      for (final w in tester.widgetList<Container>(find.descendant(
          of: byTypeName(picker), matching: find.byType(Container))))
        if (w.decoration
            case BoxDecoration(shape: BoxShape.circle, :final color?))
          color.toARGB32()
    ];

/// The indexes of the swatches showing a check mark.
List<int> checkedSwatches(WidgetTester tester, String picker) {
  final marks = tester
      .widgetList<AnimatedOpacity>(find.descendant(
          of: byTypeName(picker), matching: find.byType(AnimatedOpacity)))
      .toList();
  return [
    for (var i = 0; i < marks.length; i++)
      if (marks[i].opacity == 1) i
  ];
}

Future<void> tapSwatch(WidgetTester tester, String picker, int index) async {
  await tester.tap(find
      .descendant(
          of: byTypeName(picker), matching: find.byType(AnimatedOpacity))
      .at(index));
  await tester.pumpAndSettle();
}

void main() {
  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    group('$platform', () {
      testWidgets('BlockPicker draws Ruby available_colors with color checked',
          (tester) async {
        await mountWire(tester, platform, {
          '_c': 'BlockPicker',
          '_i': 1,
          'color': '#00ff00',
          'available_colors': ['#ff0000', '#00ff00', '#0000ff'],
        });
        final dynamic picker = tester.widget(byTypeName('BlockPicker'));
        // iOS renders the Cupertino fork, Android the upstream picker.
        expect(
            picker,
            platform == TargetPlatform.iOS
                ? isA<native.BlockPicker>()
                : isA<upstream.BlockPicker>());
        expect(picker.pickerColor, _green);
        expect(picker.availableColors, [_red, _green, _blue]);
        expect(swatchColors(tester, 'BlockPicker'),
            [_red, _green, _blue].map((c) => c.toARGB32()).toList());
        expect(checkedSwatches(tester, 'BlockPicker'), [1]);
        // The portrait palette grid.
        expect(tester.getSize(byTypeName('BlockPicker')), const Size(300, 360));
        expect(tester.takeException(), isNull);
      });

      testWidgets('BlockPicker without available_colors shows the palette',
          (tester) async {
        await mountWire(tester, platform,
            {'_c': 'BlockPicker', '_i': 1, 'color': '#f44336'});
        final colors = swatchColors(tester, 'BlockPicker');
        expect(colors, hasLength(20));
        // Red 500 first, black last, as in flutter_colorpicker.
        expect(colors.first, 0xfff44336);
        expect(colors.last, 0xff000000);
        expect(checkedSwatches(tester, 'BlockPicker'), [0]);
      });

      testWidgets('BlockPicker tap sends color_change and writes color back',
          (tester) async {
        final m = await mountWire(tester, platform, {
          '_c': 'BlockPicker',
          '_i': 1,
          'color': '#ff0000',
          'available_colors': ['#ff0000', '#00ff00', '#0000ff'],
          'on_color_change': true,
        });
        await tapSwatch(tester, 'BlockPicker', 2);
        expect(m.backend.events,
            [(id: 1, name: 'color_change', data: '#ff0000ff')]);
        expect(m.backend.lastWriteBack('color'), '#ff0000ff');
        expect(m.root.get('color'), '#ff0000ff');
        expect(checkedSwatches(tester, 'BlockPicker'), [2]);
      });

      testWidgets('BlockPicker sends no event unless Ruby subscribed',
          (tester) async {
        final m = await mountWire(tester, platform, {
          '_c': 'BlockPicker',
          '_i': 1,
          'color': '#ff0000',
          'available_colors': ['#ff0000', '#00ff00'],
        });
        await tapSwatch(tester, 'BlockPicker', 1);
        expect(m.backend.events, isEmpty);
        // Ruby still learns the selection.
        expect(m.backend.lastWriteBack('color'), '#ff00ff00');
      });

      testWidgets('BlockPicker follows a Ruby color update', (tester) async {
        // The picker kept the selection of its first build, so a Ruby
        // `color` update left the old swatch checked.
        final m = await mountWire(tester, platform, {
          '_c': 'BlockPicker',
          '_i': 1,
          'color': '#ff0000',
          'available_colors': ['#ff0000', '#00ff00', '#0000ff'],
          'on_color_change': true,
        });
        await rubyPatch(tester, m.root, {'color': '#0000ff'});
        expect(checkedSwatches(tester, 'BlockPicker'), [2]);

        // Picking still works after the update.
        await tapSwatch(tester, 'BlockPicker', 1);
        expect(m.backend.eventData('color_change'), ['#ff00ff00']);
        expect(checkedSwatches(tester, 'BlockPicker'), [1]);
      });

      testWidgets(
          'BlockPicker keeps its picker for a pick and rebuilds it for Ruby',
          (tester) async {
        // Rebuilding the inner picker drops its check-mark animation, so
        // only a Ruby `color` update does, not the echo of the user's pick.
        final m = await mountWire(tester, platform, {
          '_c': 'BlockPicker',
          '_i': 1,
          'color': '#ff0000',
          'available_colors': ['#ff0000', '#00ff00', '#0000ff'],
          'width': 300,
          'on_color_change': true,
        });
        final first = tester.state(byTypeName('BlockPicker'));
        await tapSwatch(tester, 'BlockPicker', 1);
        await rubyPatch(tester, m.root, {'width': 320});
        expect(tester.state(byTypeName('BlockPicker')), same(first));

        await rubyPatch(tester, m.root, {'color': '#0000ff'});
        expect(tester.state(byTypeName('BlockPicker')), isNot(same(first)));
        expect(checkedSwatches(tester, 'BlockPicker'), [2]);
      });

      testWidgets(
          'MultipleChoiceBlockPicker checks every Ruby color in its palette',
          (tester) async {
        await mountWire(tester, platform, {
          '_c': 'MultipleChoiceBlockPicker',
          '_i': 1,
          'colors': ['#ff0000', '#0000ff'],
          'available_colors': ['#ff0000', '#00ff00', '#0000ff'],
        });
        final dynamic picker =
            tester.widget(byTypeName('MultipleChoiceBlockPicker'));
        expect(
            picker,
            platform == TargetPlatform.iOS
                ? isA<native.MultipleChoiceBlockPicker>()
                : isA<upstream.MultipleChoiceBlockPicker>());
        expect(picker.pickerColors, [_red, _blue]);
        expect(picker.availableColors, [_red, _green, _blue]);
        expect(swatchColors(tester, 'MultipleChoiceBlockPicker'),
            [_red, _green, _blue].map((c) => c.toARGB32()).toList());
        expect(checkedSwatches(tester, 'MultipleChoiceBlockPicker'), [0, 2]);
        expect(tester.getSize(byTypeName('MultipleChoiceBlockPicker')),
            const Size(300, 360));
        expect(tester.takeException(), isNull);
      });

      testWidgets(
          'MultipleChoiceBlockPicker toggles send colors_change and write back',
          (tester) async {
        final m = await mountWire(tester, platform, {
          '_c': 'MultipleChoiceBlockPicker',
          '_i': 1,
          'colors': ['#ff0000'],
          'available_colors': ['#ff0000', '#00ff00', '#0000ff'],
          'on_colors_change': true,
        });
        await tapSwatch(tester, 'MultipleChoiceBlockPicker', 1);
        expect(m.backend.eventData('colors_change'), [
          ['#ffff0000', '#ff00ff00']
        ]);
        expect(m.root.get('colors'), ['#ffff0000', '#ff00ff00']);
        expect(checkedSwatches(tester, 'MultipleChoiceBlockPicker'), [0, 1]);

        await tapSwatch(tester, 'MultipleChoiceBlockPicker', 0);
        expect(m.backend.eventData('colors_change').last, ['#ff00ff00']);
        expect(m.backend.lastWriteBack('colors'), ['#ff00ff00']);
        expect(checkedSwatches(tester, 'MultipleChoiceBlockPicker'), [1]);
      });

      testWidgets('MultipleChoiceBlockPicker follows a Ruby colors update',
          (tester) async {
        final m = await mountWire(tester, platform, {
          '_c': 'MultipleChoiceBlockPicker',
          '_i': 1,
          'colors': ['#ff0000'],
          'available_colors': ['#ff0000', '#00ff00', '#0000ff'],
          'on_colors_change': true,
        });
        await rubyPatch(tester, m.root, {
          'colors': ['#00ff00', '#0000ff']
        });
        expect(checkedSwatches(tester, 'MultipleChoiceBlockPicker'), [1, 2]);

        // Toggling continues from Ruby's selection.
        await tapSwatch(tester, 'MultipleChoiceBlockPicker', 2);
        expect(m.backend.eventData('colors_change'), [
          ['#ff00ff00']
        ]);
        expect(checkedSwatches(tester, 'MultipleChoiceBlockPicker'), [1]);
      });

      testWidgets(
          'MultipleChoiceBlockPicker keeps its picker for toggles and '
          'rebuilds it for Ruby', (tester) async {
        final m = await mountWire(tester, platform, {
          '_c': 'MultipleChoiceBlockPicker',
          '_i': 1,
          'colors': ['#ff0000'],
          'available_colors': ['#ff0000', '#00ff00', '#0000ff'],
          'width': 300,
          'on_colors_change': true,
        });
        final first = tester.state(byTypeName('MultipleChoiceBlockPicker'));
        await tapSwatch(tester, 'MultipleChoiceBlockPicker', 1);
        await tapSwatch(tester, 'MultipleChoiceBlockPicker', 0);
        await rubyPatch(tester, m.root, {'width': 320});
        expect(
            tester.state(byTypeName('MultipleChoiceBlockPicker')), same(first));

        await rubyPatch(tester, m.root, {
          'colors': ['#0000ff']
        });
        expect(tester.state(byTypeName('MultipleChoiceBlockPicker')),
            isNot(same(first)));
        expect(checkedSwatches(tester, 'MultipleChoiceBlockPicker'), [2]);
      });

      testWidgets(
          'MultipleChoiceBlockPicker sends no event unless Ruby subscribed',
          (tester) async {
        final m = await mountWire(tester, platform, {
          '_c': 'MultipleChoiceBlockPicker',
          '_i': 1,
          'colors': ['#ff0000'],
          'available_colors': ['#ff0000', '#00ff00'],
        });
        await tapSwatch(tester, 'MultipleChoiceBlockPicker', 1);
        expect(m.backend.events, isEmpty);
        expect(m.backend.lastWriteBack('colors'), ['#ffff0000', '#ff00ff00']);
      });
    });
  }
}
