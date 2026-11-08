// Behaviour snapshots of ListTile (the `list_tile` and `cupertino_list_tile`
// DSL names) on iOS and Android: geometry, semantics, what it sends to Ruby
// during scripted taps, long presses and semantics taps (including the
// toggles an enclosing `toggle_inputs` tile drives), and invoke outcomes.
// Rewrite with `flutter test --update-goldens` only for a change listed in
// the PR's "Parity changes" table.
import 'package:flutter_test/flutter_test.dart';

import '../support/control_harness.dart';
import '../support/control_snapshot.dart';

const _target = 2201;

// Material icon set indexes: 0x10000 | index.
const _icon = 0x10000;
const _otherIcon = 0x10001;

const _events = {'on_click': true, 'on_long_press': true};

Map<String, dynamic> _column(Map<String, dynamic> props) => {
      '_c': 'Column',
      '_i': 2200,
      'controls': [
        {'_c': 'ListTile', '_i': _target, ...props}
      ],
    };

SnapshotStep _longPress(String text) =>
    SnapshotStep('long press "$text"', (c) async {
      final target = find.text(text);
      if (target.evaluate().isEmpty) {
        c.note = 'text not rendered';
        return;
      }
      await c.tester.longPress(target.first, warnIfMissed: false);
      await c.tester.pumpAndSettle();
    });

final _fixtures = [
  SnapshotFixture(
    'defaults',
    _column({'title': 'Tile', ..._events}),
    target: _target,
    steps: [
      SnapshotStep.tapText('Tile'),
      _longPress('Tile'),
      SnapshotStep.semanticsTap(),
      SnapshotStep.tab(),
      SnapshotStep.invoke('focus'),
      SnapshotStep.unfocus(),
    ],
  ),
  SnapshotFixture(
    'full',
    _column({
      'title': 'Tile',
      'subtitle': 'Details',
      'leading': _icon,
      'trailing': _otherIcon,
      'additional_info': 'Info',
      'chevron': true,
      'bgcolor': '#eeeeee',
      ..._events,
    }),
    target: _target,
    steps: [SnapshotStep.tapText('Tile'), _longPress('Details')],
  ),
  SnapshotFixture(
    'chevron',
    _column({'title': 'Tile', 'chevron': true}),
    target: _target,
  ),
  SnapshotFixture(
    'child_controls',
    _column({
      'title': {'_c': 'Text', '_i': 2202, 'value': 'Child title'},
      'subtitle': {'_c': 'Text', '_i': 2203, 'value': 'Child subtitle'},
      'leading': {'_c': 'Icon', '_i': 2204, 'icon': _icon},
      'trailing': {'_c': 'Text', '_i': 2205, 'value': 'Child trailing'},
      ..._events,
    }),
    target: _target,
    steps: [SnapshotStep.tapText('Child title')],
  ),
  SnapshotFixture(
    'no_title',
    _column({'leading': _icon, 'subtitle': 'Only a subtitle', ..._events}),
    target: _target,
    steps: [SnapshotStep.tapText('Only a subtitle')],
  ),
  SnapshotFixture(
    'disabled',
    _column({'title': 'Tile', 'disabled': true, ..._events}),
    target: _target,
    steps: [SnapshotStep.tapText('Tile'), _longPress('Tile')],
  ),
  SnapshotFixture(
    'toggle_inputs',
    _column({
      'title': 'Wi-Fi',
      'toggle_inputs': true,
      'trailing': {
        '_c': 'Switch',
        '_i': 2206,
        'value': false,
        'on_change': true,
      },
      ..._events,
    }),
    target: _target,
    steps: [SnapshotStep.tapText('Wi-Fi'), SnapshotStep.tapText('Wi-Fi')],
  ),
  SnapshotFixture(
    'toggle_inputs_only',
    _column({
      'title': 'Agree',
      'toggle_inputs': true,
      'leading': {
        '_c': 'Checkbox',
        '_i': 2207,
        'value': false,
        'on_change': true,
      },
    }),
    target: _target,
    steps: [SnapshotStep.tapText('Agree')],
  ),
  SnapshotFixture(
    'padding',
    _column({'title': 'Padded', 'padding': 30.0}),
    target: _target,
  ),
  SnapshotFixture(
    'content_padding',
    _column({'title': 'Padded', 'content_padding': 30.0}),
    target: _target,
  ),
  SnapshotFixture(
    'selected',
    _column({
      'title': 'Selected',
      'leading': _icon,
      'selected': true,
      'selected_color': '#aa0000',
      'selected_tile_color': '#00aa00',
      ..._events,
    }),
    target: _target,
  ),
  SnapshotFixture(
    'material_keys',
    _column({
      'title': 'Material',
      'subtitle': 'Keys',
      'leading': _icon,
      'trailing': _otherIcon,
      'dense': true,
      'is_three_line': true,
      'horizontal_spacing': 8.0,
      'min_leading_width': 24.0,
      'min_vertical_padding': 2.0,
      'min_height': 64.0,
      'icon_color': '#123456',
      'text_color': '#654321',
      'hover_color': '#111111',
      'focus_color': '#222222',
      'splash_color': '#333333',
      'enable_feedback': false,
      'autofocus': false,
      'mouse_cursor': 'click',
      'visual_density': 'compact',
      'shape': {'_type': 'roundedrectangle', 'radius': 8.0},
      'title_text_style': {'size': 20.0},
      'subtitle_text_style': {'size': 10.0},
      'leading_and_trailing_text_style': {'size': 12.0},
      'title_alignment': 'top',
      'style': 'drawer',
      ..._events,
    }),
    target: _target,
  ),
  SnapshotFixture(
    'cupertino_keys',
    _column({
      'title': 'Cupertino',
      'subtitle': 'Keys',
      'leading': _icon,
      'notched': true,
      'leading_size': 40.0,
      'leading_to_title': 8.0,
      'bgcolor_activated': '#cccccc',
      ..._events,
    }),
    target: _target,
    steps: [SnapshotStep.tapText('Cupertino')],
  ),
  SnapshotFixture(
    'layout',
    _column({
      'title': 'Layout',
      'width': 300.0,
      'margin': 10.0,
      'opacity': 0.5,
    }),
    target: _target,
  ),
];

void main() {
  for (final fixture in _fixtures) {
    for (final design in HarnessDesign.values) {
      testWidgets('${fixture.name} on ${design.name}', (tester) async {
        expectSnapshot(await captureSnapshot(tester, design, fixture),
            snapshotPath('ListTile', fixture.name, design));
      });
    }
  }
}
