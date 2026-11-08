// Behaviour snapshots of the Radio control on iOS and Android: geometry,
// semantics, what it and its RadioGroup send to Ruby during scripted
// interactions, and invoke outcomes. Rewrite with
// `flutter test --update-goldens` only for a change listed in the PR's
// "Parity changes" table.
import 'package:flutter_test/flutter_test.dart';

import '../support/control_harness.dart';
import '../support/control_snapshot.dart';

const _events = {'on_focus': true, 'on_blur': true};

/// A RadioGroup (id 1400, value "a") around [content].
Map<String, dynamic> _group(Map<String, dynamic> content,
        [Map<String, dynamic> props = const {}]) =>
    {
      '_c': 'RadioGroup',
      '_i': 1400,
      'value': 'a',
      'on_change': true,
      'content': content,
      ...props,
    };

/// Radio "a" (id 1401, "Apple") above the radio under test (id 1402).
Map<String, dynamic> _pair(Map<String, dynamic> props,
        [Map<String, dynamic> column = const {}]) =>
    _group({
      '_c': 'Column',
      '_i': 1410,
      'controls': [
        {'_c': 'Radio', '_i': 1401, 'value': 'a', 'label': 'Apple', ..._events},
        {'_c': 'Radio', '_i': 1402, 'value': 'b', ..._events, ...props},
      ],
      ...column,
    });

Map<String, dynamic> _tile(Map<String, dynamic> props) => _group({
      '_c': 'ListTile',
      '_i': 1410,
      'toggle_inputs': true,
      'title': {'_c': 'Text', '_i': 1403, 'value': 'Tile'},
      'trailing': {
        '_c': 'Radio',
        '_i': 1402,
        'value': 'b',
        ..._events,
        ...props
      },
    });

final _fixtures = [
  SnapshotFixture(
    'defaults',
    _pair({'label': 'Banana'}),
    target: 1402,
    steps: [
      SnapshotStep.semanticsTap(),
      SnapshotStep.tapText('Apple'),
      SnapshotStep.tapText('Banana'),
      SnapshotStep.tab(),
      SnapshotStep.invoke('focus'),
    ],
  ),
  SnapshotFixture(
    'unlabeled',
    _pair({}),
    target: 1402,
    // Without a label Flutter merges the radio's semantics into the page
    // node, so drive it with a pointer tap.
    steps: [SnapshotStep.tapAt(const Offset(0.5, 0.5))],
  ),
  SnapshotFixture(
    'maximal',
    _pair({
      'label': 'Maximal',
      'label_position': 'left',
      'label_style': {'size': 18.0, 'color': '#ff0000'},
      'autofocus': false,
      'active_color': '#112233',
      'inactive_color': '#223344',
      'focus_color': '#334455',
      'hover_color': '#445566',
      'fill_color': {'selected': '#556677', 'default': '#667788'},
      'overlay_color': {'default': '#778899'},
      'splash_radius': 12.0,
      'mouse_cursor': 'click',
      'toggleable': true,
      'use_checkmark_style': true,
      'visual_density': 'compact',
    }),
    target: 1402,
    steps: [
      SnapshotStep.tapText('Maximal'),
      SnapshotStep.semanticsTap(),
    ],
  ),
  SnapshotFixture(
    'disabled',
    _pair({'label': 'Off', 'disabled': true}),
    target: 1402,
    steps: [SnapshotStep.semanticsTap(), SnapshotStep.tapText('Off')],
  ),
  SnapshotFixture(
    'label_control',
    _pair({
      'label': {'_c': 'Text', '_i': 1404, 'value': 'Custom'},
    }),
    target: 1402,
    steps: [SnapshotStep.tapText('Custom')],
  ),
  SnapshotFixture(
    'rtl',
    _pair({'label': 'RTL', 'rtl': true}),
    target: 1402,
    steps: [SnapshotStep.tapText('RTL')],
  ),
  SnapshotFixture(
    'nested_theme',
    _pair({
      'label': 'Themed',
      'label_style': {'color': 'primary'},
    }, {
      'theme': {'color_scheme_seed': '#00aa00'},
    }),
    target: 1402,
    steps: [SnapshotStep.semanticsTap()],
  ),
  SnapshotFixture(
    'list_tile',
    _tile({}),
    target: 1402,
    steps: [SnapshotStep.tapText('Tile')],
  ),
  SnapshotFixture(
    'list_tile_disabled',
    _tile({'disabled': true}),
    target: 1402,
    steps: [SnapshotStep.tapText('Tile')],
  ),
];

void main() {
  for (final fixture in _fixtures) {
    for (final design in HarnessDesign.values) {
      testWidgets('Radio ${fixture.name} on ${design.name}', (tester) async {
        expectSnapshot(await captureSnapshot(tester, design, fixture),
            snapshotPath('Radio', fixture.name, design));
      });
    }
  }
}
