// IconButton keys both designs now honor through IconButtonCore.
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' as material;
import 'package:flutter_test/flutter_test.dart';
import 'package:ruflet/src/utils/material_icons.dart';

import '../support/control_harness.dart';

Map<String, dynamic> _iconButton(Map<String, dynamic> props) => {
      '_c': 'Column',
      '_i': 1900,
      'controls': [
        {'_c': 'IconButton', '_i': 1901, 'icon': 0x10000, ...props}
      ],
    };

Color? _iconColor(WidgetTester tester) =>
    tester.widget<Icon>(find.byType(Icon)).color;

void main() {
  testWidgets('Material IconButton honors the Ruby style map', (tester) async {
    await mountWire(
        tester,
        HarnessDesign.android,
        _iconButton({
          'style': {'bgcolor': '#eeeeee'}
        }));
    final native =
        tester.widget<material.IconButton>(find.byType(material.IconButton));
    expect(native.style?.backgroundColor?.resolve({}), const Color(0xffeeeeee));
  });

  testWidgets('Cupertino IconButton honors selected_icon_color',
      (tester) async {
    await mountWire(
        tester,
        HarnessDesign.ios,
        _iconButton({
          'selected': true,
          'icon_color': '#00ff00',
          'selected_icon_color': '#ff0000',
        }));
    expect(_iconColor(tester), const Color(0xffff0000));
  });

  testWidgets('Cupertino IconButton honors disabled_color', (tester) async {
    await mountWire(
        tester,
        HarnessDesign.ios,
        _iconButton({
          'disabled': true,
          'icon_color': '#00ff00',
          'disabled_color': '#888888',
        }));
    expect(_iconColor(tester), const Color(0xff888888));
    expect(find.byType(CupertinoButton), findsOneWidget);
  });

  // The icon colour rule is the same on both designs: disabled_color while
  // disabled, else selected_icon_color while selected, else icon_color.
  for (final design in HarnessDesign.values) {
    for (final (name, props, expected) in [
      (
        'selected without a selected_icon',
        {'selected': true, 'selected_icon_color': '#ff0000'},
        const Color(0xffff0000),
      ),
      (
        'selected with a selected_icon',
        {
          'selected': true,
          'selected_icon': 0x10001,
          'selected_icon_color': '#ff0000',
        },
        const Color(0xffff0000),
      ),
      (
        'disabled',
        {'disabled': true, 'disabled_color': '#888888'},
        const Color(0xff888888),
      ),
      (
        'disabled and selected',
        {
          'disabled': true,
          'selected': true,
          'disabled_color': '#888888',
          'selected_icon_color': '#ff0000',
        },
        const Color(0xff888888),
      ),
      ('neither', <String, dynamic>{}, const Color(0xff00ff00)),
    ]) {
      testWidgets('${design.name}: icon colour when $name', (tester) async {
        await mountWire(
            tester, design, _iconButton({'icon_color': '#00ff00', ...props}));
        expect(_iconColor(tester), expected);
      });
    }
  }

  // Only a plain IconButton leading an AppBar becomes the iOS back chevron.
  for (final type in [
    'IconButton',
    'FilledIconButton',
    'FilledTonalIconButton',
    'OutlinedIconButton',
  ]) {
    testWidgets('iOS $type leading an AppBar', (tester) async {
      await mountWire(tester, HarnessDesign.ios, {
        '_c': 'AppBar',
        '_i': 1950,
        'leading': {
          '_c': type,
          '_i': 1951,
          'icon': (1 << 16) | materialIcons.indexOf(material.Icons.arrow_back),
        },
        'title': {'_c': 'Text', '_i': 1952, 'value': 'Title'},
      });
      final chevron = type == 'IconButton';
      expect(find.byIcon(CupertinoIcons.back),
          chevron ? findsOneWidget : findsNothing);
      expect(find.byIcon(material.Icons.arrow_back),
          chevron ? findsNothing : findsOneWidget);
    });
  }
}
