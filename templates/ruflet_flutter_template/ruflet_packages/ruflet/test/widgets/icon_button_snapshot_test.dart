// Behaviour snapshots of the four IconButton wire types (IconButton,
// FilledIconButton, FilledTonalIconButton, OutlinedIconButton) on iOS and
// Android: geometry, semantics, what they send to Ruby during scripted taps,
// long presses, mouse hover and keyboard focus, and invoke outcomes. Rewrite
// with `flutter test --update-goldens` only for a change listed in the PR's
// "Parity changes" table.
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart' as material show Icons;
import 'package:ruflet/src/utils/material_icons.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/control_harness.dart';
import '../support/control_snapshot.dart';

const _variants = [
  'IconButton',
  'FilledIconButton',
  'FilledTonalIconButton',
  'OutlinedIconButton',
];

const _events = {
  'on_click': true,
  'on_long_press': true,
  'on_hover': true,
  'on_focus': true,
  'on_blur': true,
};

// Material icon set indexes: 0 is the first icon, 0x10000 | index.
const _icon = 0x10000;
const _otherIcon = 0x10001;

Map<String, dynamic> _column(List<Map<String, dynamic>> controls) =>
    {'_c': 'Column', '_i': 1800, 'controls': controls};

Map<String, dynamic> _button(String type, Map<String, dynamic> props) =>
    {'_c': type, '_i': 1801, 'icon': _icon, ..._events, ...props};

SnapshotStep _longPress() => SnapshotStep('long press', (c) async {
      await c.tester.longPress(c.finder.first);
      await c.tester.pumpAndSettle();
    });

/// A mouse pointer enters the control and leaves it again.
SnapshotStep _hover() => SnapshotStep('hover in and out', (c) async {
      final mouse = await c.tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: const Offset(790, 590));
      await c.tester.pump();
      await mouse.moveTo(c.tester.getCenter(c.finder.first));
      await c.tester.pumpAndSettle();
      await mouse.moveTo(const Offset(790, 590));
      await c.tester.pumpAndSettle();
      await mouse.removePointer();
      await c.tester.pump();
    });

final _fixtures = [
  for (final type in _variants)
    SnapshotFixture(
      'defaults_$type',
      _column([_button(type, {})]),
      target: 1801,
      steps: [
        SnapshotStep.semanticsTap(),
        SnapshotStep.tapAt(const Offset(0.5, 0.5)),
        _longPress(),
        _hover(),
        SnapshotStep.tab(),
        SnapshotStep.invoke('focus'),
        SnapshotStep.invoke('blur'),
      ],
    ),
  SnapshotFixture(
    'selected',
    _column([
      _button('IconButton', {
        'selected': true,
        'selected_icon': _otherIcon,
        'selected_icon_color': '#ff0000',
        'icon_color': '#00ff00',
      }),
    ]),
    target: 1801,
    steps: [SnapshotStep.tapAt(const Offset(0.5, 0.5))],
  ),
  SnapshotFixture(
    'disabled',
    _column([
      _button('IconButton', {'disabled': true, 'disabled_color': '#888888'}),
    ]),
    target: 1801,
    steps: [SnapshotStep.tapAt(const Offset(0.5, 0.5)), _hover()],
  ),
  SnapshotFixture(
    'maximal',
    _column([
      _button('FilledIconButton', {
        'icon_color': '#112233',
        'icon_size': 30.0,
        'bgcolor': '#334455',
        'focus_color': '#445566',
        'hover_color': '#556677',
        'highlight_color': '#667788',
        'splash_color': '#778899',
        'splash_radius': 20.0,
        'padding': 6.0,
        'alignment': {'x': 0.0, 'y': 0.0},
        'mouse_cursor': 'click',
        'enable_feedback': false,
        'size_constraints': {'min_width': 56.0, 'min_height': 56.0},
        'visual_density': 'compact',
        'style': {
          'bgcolor': '#eeeeee',
          'icon_color': {'default': '#123456', 'pressed': '#654321'},
        },
      }),
    ]),
    target: 1801,
    steps: [SnapshotStep.semanticsTap(), _longPress()],
  ),
  SnapshotFixture(
    'app_bar_leading_back',
    {
      '_c': 'AppBar',
      '_i': 1800,
      'title': {'_c': 'Text', '_i': 1802, 'value': 'Title'},
      'leading': {
        '_c': 'IconButton',
        '_i': 1801,
        'icon': (1 << 16) | materialIcons.indexOf(material.Icons.arrow_back),
        'on_click': true
      },
    },
    target: 1801,
    steps: [SnapshotStep.tapAt(const Offset(0.5, 0.5))],
  ),
];

void main() {
  for (final fixture in _fixtures) {
    for (final design in HarnessDesign.values) {
      testWidgets('${fixture.name} on ${design.name}', (tester) async {
        expectSnapshot(await captureSnapshot(tester, design, fixture),
            snapshotPath('IconButton', fixture.name, design));
      });
    }
  }
}
