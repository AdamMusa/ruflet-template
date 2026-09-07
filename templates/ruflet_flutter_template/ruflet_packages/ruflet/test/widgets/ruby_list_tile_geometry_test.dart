import 'package:ruflet/ruflet.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

import 'ruby_layout_attributes_test.dart' show backendFor, host;

void main() {
  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    for (final subtitle in [false, true]) {
      testWidgets(
          '$platform centers list labels inside an explicit row height (subtitle=$subtitle)',
          (tester) async {
        final backend = backendFor(platform);
        final control = Control.fromMap({
          '_c': 'Container',
          '_i': 1,
          'width': 400,
          'height': 60,
          'margin': {'left': 10, 'top': 20, 'right': 0, 'bottom': 0},
          'content': {
            '_c': 'ListTile',
            '_i': 2,
            'content_padding': {'left': 16, 'right': 12, 'top': 0, 'bottom': 0},
            'title': {'_c': 'Text', '_i': 3, 'value': 'Gallery', 'size': 17},
            if (subtitle)
              'subtitle': {
                '_c': 'Text',
                '_i': 4,
                'value': 'Browse all examples',
                'size': 12
              },
          },
        }, backend);
        await tester.pumpWidget(host(backend, ControlWidget(control: control)));
        final title = tester.getRect(find.text('Gallery'));
        final labels = subtitle
            ? title.expandToInclude(
                tester.getRect(find.text('Browse all examples')))
            : title;
        // Cupertino groups labels centrally; Material retains its native
        // baseline-based two-line layout rather than adopting iOS geometry.
        if (platform == TargetPlatform.iOS || !subtitle) {
          expect(labels.center.dy, closeTo(50, 2));
        }
        expect(title.left, 26);
        expect(labels.top, greaterThan(20));
        expect(labels.bottom, lessThan(80));
        if (subtitle) {
          expect(
              tester.getTopLeft(find.text('Browse all examples')).dy -
                  title.bottom,
              lessThan(8));
        }
        expect(tester.takeException(), isNull);
      });
    }
  }
}
