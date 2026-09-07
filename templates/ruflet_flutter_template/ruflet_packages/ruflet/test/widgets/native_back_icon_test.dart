import 'package:ruflet/ruflet.dart';
import 'package:ruflet/src/utils/material_icons.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' as material;
import 'package:flutter_test/flutter_test.dart';

import 'ruby_layout_attributes_test.dart' show backendFor, host;

void main() {
  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    for (final glyph in [
      material.Icons.arrow_back,
      material.Icons.arrow_back_ios,
      material.Icons.arrow_back_ios_new,
      material.Icons.close
    ]) {
      testWidgets(
          '$platform navigation icon $glyph preserves platform semantics',
          (tester) async {
        final backend = backendFor(platform);
        final bar = Control.fromMap({
          '_c': 'AppBar',
          '_i': 100,
          'leading': {
            '_c': 'IconButton',
            '_i': 101,
            'icon': (1 << 16) | materialIcons.indexOf(glyph),
            'icon_size': 27,
            'icon_color': '#123456'
          },
        }, backend);
        // Keep the actual AppBar parent relationship while isolating button
        // geometry from the navigation bar's own leading width constraints.
        await tester.pumpWidget(
            host(backend, ControlWidget(control: bar.child('leading')!)));
        final expected =
            platform == TargetPlatform.iOS && glyph != material.Icons.close
                ? CupertinoIcons.back
                : glyph;
        expect(find.byIcon(expected), findsOneWidget);
        final context = tester.element(find.byIcon(expected));
        expect(IconTheme.of(context).size, 27);
        expect(tester.widget<Icon>(find.byIcon(expected)).color,
            const Color(0xff123456));
        expect(tester.takeException(), isNull);
      });
    }
  }
}
