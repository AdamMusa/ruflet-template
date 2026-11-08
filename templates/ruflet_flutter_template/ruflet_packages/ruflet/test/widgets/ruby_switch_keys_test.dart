// Switch keys both designs now honor through the shared SwitchCore.
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' as material;
import 'package:flutter_test/flutter_test.dart';

import '../support/control_harness.dart';

const _png =
    'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+a6i8AAAAASUVORK5CYII=';

Map<String, dynamic> _switch(Map<String, dynamic> props) => {
      '_c': 'Column',
      '_i': 1100,
      'controls': [
        {'_c': 'Switch', '_i': 1101, ...props}
      ],
    };

void main() {
  for (final key in ['active_thumb_image_src', 'active_thumb_image']) {
    testWidgets('Material Switch shows the thumb image from $key',
        (tester) async {
      await mountWire(tester, HarnessDesign.android,
          _switch({key: _png, 'inactive_thumb_image': _png}));
      final native =
          tester.widget<material.Switch>(find.byType(material.Switch));
      expect(native.activeThumbImage, isNotNull);
      expect(native.inactiveThumbImage, isNotNull);
      expect(native.onActiveThumbImageError, isNotNull);
    });

    testWidgets('Cupertino Switch shows the thumb image from $key',
        (tester) async {
      await mountWire(tester, HarnessDesign.ios,
          _switch({key: _png, 'inactive_thumb_image': _png}));
      final native =
          tester.widget<CupertinoSwitch>(find.byType(CupertinoSwitch));
      expect(native.activeThumbImage, isNotNull);
      expect(native.inactiveThumbImage, isNotNull);
    });
  }

  testWidgets('Cupertino Switch honors mouse_cursor and label_text_style',
      (tester) async {
    await mountWire(
        tester,
        HarnessDesign.ios,
        _switch({
          'mouse_cursor': 'click',
          'label': 'Styled',
          'label_text_style': {'size': 21.0},
        }));
    final native = tester.widget<CupertinoSwitch>(find.byType(CupertinoSwitch));
    expect(native.mouseCursor?.resolve({}), SystemMouseCursors.click);
    expect(tester.widget<Text>(find.text('Styled')).style?.fontSize, 21.0);
  });

  for (final design in HarnessDesign.values) {
    testWidgets('image errors reach Ruby on ${design.name}', (tester) async {
      final mount = await mountWire(tester, design,
          _switch({'active_thumb_image_src': _png, 'on_image_error': true}));
      final ImageErrorListener? onError = design == HarnessDesign.ios
          ? tester
              .widget<CupertinoSwitch>(find.byType(CupertinoSwitch))
              .onActiveThumbImageError
          : tester
              .widget<material.Switch>(find.byType(material.Switch))
              .onActiveThumbImageError;
      onError!(Exception('broken'), null);
      expect(mount.backend.sent.map((m) => m.toJson()), [
        {'id': 1101, 'event': 'image_error', 'data': 'Exception: broken'}
      ]);
    });
  }
}
