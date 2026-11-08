// Behaviour snapshots of the Checkbox control on iOS and Android: geometry,
// semantics, what it sends to Ruby during scripted interactions, and invoke
// outcomes. Rewrite with `flutter test --update-goldens` only for a change
// listed in the PR's "Parity changes" table.
import 'package:flutter_test/flutter_test.dart';

import '../support/control_harness.dart';
import '../support/control_snapshot.dart';

const _events = {'on_change': true, 'on_focus': true, 'on_blur': true};

Map<String, dynamic> _column(List<Map<String, dynamic>> controls,
        [Map<String, dynamic> props = const {}]) =>
    {'_c': 'Column', '_i': 1200, 'controls': controls, ...props};

Map<String, dynamic> _checkbox(Map<String, dynamic> props) =>
    {'_c': 'Checkbox', '_i': 1201, ...props};

final _fixtures = [
  SnapshotFixture(
    'defaults',
    _column([
      _checkbox({'label': 'Accept', ..._events}),
    ]),
    target: 1201,
    steps: [
      SnapshotStep.semanticsTap(),
      SnapshotStep.tapText('Accept'),
      SnapshotStep.tab(),
      SnapshotStep.invoke('focus'),
    ],
  ),
  SnapshotFixture(
    'unlabeled',
    _column([
      _checkbox({'value': true, ..._events}),
    ]),
    target: 1201,
    steps: [SnapshotStep.semanticsTap()],
  ),
  SnapshotFixture(
    'tristate',
    _column([
      _checkbox({'label': 'Tri', 'tristate': true, ..._events}),
    ]),
    target: 1201,
    steps: [
      SnapshotStep.tapText('Tri'),
      SnapshotStep.tapText('Tri'),
      SnapshotStep.tapText('Tri'),
      SnapshotStep.semanticsTap(),
    ],
  ),
  SnapshotFixture(
    'maximal',
    _column([
      _checkbox({
        ..._events,
        'value': true,
        'tristate': false,
        'label': 'Maximal',
        'label_position': 'left',
        'label_style': {'size': 18.0, 'color': '#ff0000'},
        'spacing': 6.0,
        'autofocus': false,
        'active_color': '#112233',
        'check_color': '#223344',
        'focus_color': '#334455',
        'hover_color': '#445566',
        'fill_color': {'selected': '#556677', 'default': '#667788'},
        'overlay_color': {'default': '#778899'},
        'border_side': {
          'default': {'width': 2.0, 'color': '#8899aa'}
        },
        'shape': {'_type': 'roundedrectangle', 'radius': 3.0},
        'splash_radius': 12.0,
        'mouse_cursor': 'click',
        'semantics_label': 'Agree',
        'error': true,
        'visual_density': 'compact',
      }),
    ]),
    target: 1201,
    steps: [SnapshotStep.semanticsTap(), SnapshotStep.tapText('Maximal')],
  ),
  SnapshotFixture(
    'sized',
    _column([
      _checkbox({'label': 'Big', 'width': 160.0, 'height': 60.0, ..._events}),
    ]),
    target: 1201,
    steps: [SnapshotStep.semanticsTap()],
  ),
  SnapshotFixture(
    'disabled',
    _column([
      _checkbox({'label': 'Off', 'disabled': true, ..._events}),
    ]),
    target: 1201,
    steps: [SnapshotStep.semanticsTap(), SnapshotStep.tapText('Off')],
  ),
  SnapshotFixture(
    'label_control',
    _column([
      _checkbox({
        'label': {'_c': 'Text', '_i': 1202, 'value': 'Custom'},
        ..._events,
      }),
    ]),
    target: 1201,
    steps: [SnapshotStep.tapText('Custom')],
  ),
  SnapshotFixture(
    'rtl',
    _column([
      _checkbox({'label': 'RTL', 'rtl': true, ..._events}),
    ]),
    target: 1201,
    steps: [SnapshotStep.tapText('RTL')],
  ),
  SnapshotFixture(
    'nested_theme',
    _column([
      _checkbox({
        'label': 'Themed',
        'label_style': {'color': 'primary'},
        ..._events,
      }),
    ], {
      'theme': {'color_scheme_seed': '#00aa00'},
    }),
    target: 1201,
    steps: [SnapshotStep.semanticsTap()],
  ),
  SnapshotFixture(
    'list_tile',
    {
      '_c': 'ListTile',
      '_i': 1200,
      'toggle_inputs': true,
      'title': {'_c': 'Text', '_i': 1203, 'value': 'Tile'},
      'leading': _checkbox(_events),
    },
    target: 1201,
    steps: [SnapshotStep.tapText('Tile')],
  ),
  SnapshotFixture(
    'list_tile_disabled',
    {
      '_c': 'ListTile',
      '_i': 1200,
      'toggle_inputs': true,
      'title': {'_c': 'Text', '_i': 1203, 'value': 'Tile'},
      'leading': _checkbox({'disabled': true, ..._events}),
    },
    target: 1201,
    steps: [SnapshotStep.tapText('Tile')],
  ),
];

void main() {
  for (final fixture in _fixtures) {
    for (final design in HarnessDesign.values) {
      testWidgets('Checkbox ${fixture.name} on ${design.name}', (tester) async {
        expectSnapshot(await captureSnapshot(tester, design, fixture),
            snapshotPath('Checkbox', fixture.name, design));
      });
    }
  }
}
