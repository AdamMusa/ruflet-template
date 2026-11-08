// Radio keys both designs now honor through the shared RadioCore.
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' as material;
import 'package:flutter_test/flutter_test.dart';

import '../support/control_harness.dart';

Map<String, dynamic> _group(Map<String, dynamic> radio) => {
      '_c': 'RadioGroup',
      '_i': 1500,
      'value': 'b',
      'content': {'_c': 'Radio', '_i': 1501, 'value': 'b', ...radio},
    };

void main() {
  testWidgets('Cupertino Radio resolves fill_color state maps', (tester) async {
    await mountWire(
        tester,
        HarnessDesign.ios,
        _group({
          'fill_color': {'selected': '#112233', 'default': '#445566'}
        }));
    final native = tester
        .widget<CupertinoRadio<String>>(find.byType(CupertinoRadio<String>));
    expect(native.fillColor, const Color(0xff112233));
  });

  testWidgets('Material Radio honors disabled inside an enabled group',
      (tester) async {
    final mount = await mountWire(
        tester, HarnessDesign.android, _group({'disabled': true}));
    final native = tester
        .widget<material.Radio<String>>(find.byType(material.Radio<String>));
    expect(native.enabled, isFalse);
    expect(mount.control(1500).disabled, isFalse);
  });
}
