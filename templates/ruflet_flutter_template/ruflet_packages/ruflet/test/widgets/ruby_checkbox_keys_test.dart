// Checkbox keys both designs now honor through the shared CheckboxCore.
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' as material;
import 'package:flutter_test/flutter_test.dart';

import '../support/control_harness.dart';

Map<String, dynamic> _checkbox(Map<String, dynamic> props) => {
      '_c': 'Column',
      '_i': 1300,
      'controls': [
        {'_c': 'Checkbox', '_i': 1301, 'label': 'Gap', ...props}
      ],
    };

double _gap(WidgetTester tester, Type native) =>
    tester.getTopLeft(find.text('Gap')).dx -
    tester.getTopRight(find.byType(native)).dx;

void main() {
  testWidgets('Material Checkbox honors spacing and keeps no default gap',
      (tester) async {
    await mountWire(tester, HarnessDesign.android, _checkbox({}));
    expect(_gap(tester, material.Checkbox), 0);
    await mountWire(tester, HarnessDesign.android, _checkbox({'spacing': 6.0}));
    expect(_gap(tester, material.Checkbox), 6);
  });

  testWidgets('Cupertino Checkbox honors spacing with its native default',
      (tester) async {
    await mountWire(tester, HarnessDesign.ios, _checkbox({}));
    expect(_gap(tester, CupertinoCheckbox), 10);
    await mountWire(tester, HarnessDesign.ios, _checkbox({'spacing': 6.0}));
    expect(_gap(tester, CupertinoCheckbox), 6);
  });
}
