// Behaviour snapshots of the five Button wire types (Button, FilledButton,
// FilledTonalButton, OutlinedButton, TextButton) on iOS and Android:
// geometry, semantics, what they send to Ruby during scripted taps, long
// presses, mouse hover and keyboard focus, and invoke outcomes. Rewrite with
// `flutter test --update-goldens` only for a change listed in the PR's
// "Parity changes" table.
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter_test/flutter_test.dart';

import '../support/control_harness.dart';
import '../support/control_snapshot.dart';

const _variants = [
  'Button',
  'FilledButton',
  'FilledTonalButton',
  'OutlinedButton',
  'TextButton',
];

const _events = {
  'on_click': true,
  'on_long_press': true,
  'on_hover': true,
  'on_focus': true,
  'on_blur': true,
};

Map<String, dynamic> _column(List<Map<String, dynamic>> controls) =>
    {'_c': 'Column', '_i': 1600, 'controls': controls};

Map<String, dynamic> _button(String type, Map<String, dynamic> props) =>
    {'_c': type, '_i': 1601, ..._events, ...props};

SnapshotStep _longPress(String text) =>
    SnapshotStep('long press "$text"', (c) async {
      await c.tester.longPress(find.text(text));
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
      _column([
        _button(type, {'content': 'Go'}),
      ]),
      target: 1601,
      steps: [
        SnapshotStep.semanticsTap(),
        SnapshotStep.tapText('Go'),
        _longPress('Go'),
        _hover(),
        SnapshotStep.tab(),
        SnapshotStep.invoke('focus'),
        SnapshotStep.invoke('blur'),
      ],
    ),
  SnapshotFixture(
    'icon',
    _column([
      _button('Button',
          {'content': 'Add', 'icon': 0x10000, 'icon_color': '#ff0000'}),
    ]),
    target: 1601,
    steps: [SnapshotStep.tapText('Add')],
  ),
  SnapshotFixture(
    'icon_outlined',
    _column([
      _button('OutlinedButton', {'content': 'Add', 'icon': 0x10000}),
    ]),
    target: 1601,
    steps: [SnapshotStep.tapText('Add'), _hover()],
  ),
  SnapshotFixture(
    'maximal',
    _column([
      _button('Button', {
        'content': 'Maximal',
        'icon': 0x10000,
        'icon_color': '#112233',
        'color': '#223344',
        'bgcolor': '#334455',
        'disabled_bgcolor': '#445566',
        'focus_color': '#556677',
        'elevation': 3.0,
        'clip_behavior': 'antiAlias',
        'autofocus': false,
        'alignment': {'x': -1.0, 'y': 0.0},
        'border_radius': 6.0,
        'min_size': {'width': 120.0, 'height': 50.0},
        'mouse_cursor': 'click',
        'opacity_on_click': 0.5,
        'padding': 10.0,
        'size': 'medium',
        'style': {
          'color': {'default': '#123456', 'pressed': '#654321'},
          'bgcolor': '#eeeeee',
          'padding': 12.0,
          'text_style': {'size': 21.0},
          'side': {'color': '#888888', 'width': 2.0},
        },
      }),
    ]),
    target: 1601,
    steps: [SnapshotStep.semanticsTap(), _longPress('Maximal')],
  ),
  SnapshotFixture(
    'disabled',
    _column([
      _button('FilledButton', {'content': 'Off', 'disabled': true}),
    ]),
    target: 1601,
    steps: [SnapshotStep.tapText('Off'), _hover()],
  ),
  SnapshotFixture(
    'dialog_action',
    {
      '_c': 'AlertDialog',
      '_i': 1600,
      'open': true,
      'title': {'_c': 'Text', '_i': 1602, 'value': 'Title'},
      'actions': [
        _button('Button', {
          'content': 'Delete',
          'default': true,
          'destructive': true,
          'text_style': {'size': 19.0},
        }),
      ],
    },
    target: 1601,
    steps: [SnapshotStep.tapText('Delete')],
  ),
];

void main() {
  for (final fixture in _fixtures) {
    for (final design in HarnessDesign.values) {
      testWidgets('${fixture.name} on ${design.name}', (tester) async {
        expectSnapshot(await captureSnapshot(tester, design, fixture),
            snapshotPath('Button', fixture.name, design));
      });
    }
  }
}
