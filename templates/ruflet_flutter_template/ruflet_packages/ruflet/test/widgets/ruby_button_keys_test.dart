// Button behaviour both designs now share through ButtonCore.
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' as material;
import 'package:flutter_test/flutter_test.dart';

import '../support/control_harness.dart';

Map<String, dynamic> _dialog(Map<String, dynamic> action) => {
      '_c': 'AlertDialog',
      '_i': 1700,
      'open': true,
      'title': {'_c': 'Text', '_i': 1702, 'value': 'Title'},
      'actions': [
        {'_c': 'Button', '_i': 1701, 'content': 'OK', ...action}
      ],
    };

bool _hasMargin(Widget widget) =>
    widget is Container && widget.margin == const EdgeInsets.all(10);

void main() {
  testWidgets('an iOS alert-dialog action honors layout keys like margin',
      (tester) async {
    await mountWire(tester, HarnessDesign.ios, _dialog({'margin': 10.0}));
    expect(find.byType(CupertinoDialogAction), findsOneWidget);
    expect(
        find.ancestor(
            of: find.byType(CupertinoDialogAction),
            matching: find.byWidgetPredicate(_hasMargin)),
        findsOneWidget);
  });

  testWidgets('the Material dialog action keeps honoring margin',
      (tester) async {
    await mountWire(tester, HarnessDesign.android, _dialog({'margin': 10.0}));
    expect(
        find.ancestor(
            of: find.byType(material.ElevatedButton),
            matching: find.byWidgetPredicate(_hasMargin)),
        findsOneWidget);
  });

  for (final design in HarnessDesign.values) {
    testWidgets('blur is a Button method on ${design.name}', (tester) async {
      final mount = await mountWire(tester, design, {
        '_c': 'Column',
        '_i': 1710,
        'controls': [
          {'_c': 'TextButton', '_i': 1711, 'content': 'Go', 'on_blur': true},
        ],
      });
      final button = mount.control(1711);
      expect((await invokeOutcome(tester, button, 'focus')).error, isNull);
      expect((await invokeOutcome(tester, button, 'blur')).error, isNull);
      await tester.pump();
      expect(mount.backend.sent.map((m) => m.name), contains('blur'));
    });
  }
}
