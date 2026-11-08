// Behaviour snapshots of the Switch control on iOS and Android: geometry,
// semantics, what it sends to Ruby during scripted interactions, and invoke
// outcomes. Rewrite with `flutter test --update-goldens` only for a change
// listed in the PR's "Parity changes" table.
import 'package:flutter_test/flutter_test.dart';

import '../support/control_harness.dart';
import '../support/control_snapshot.dart';

const _png =
    'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+a6i8AAAAASUVORK5CYII=';

const _events = {'on_change': true, 'on_focus': true, 'on_blur': true};

Map<String, dynamic> _column(List<Map<String, dynamic>> controls,
        [Map<String, dynamic> props = const {}]) =>
    {'_c': 'Column', '_i': 1000, 'controls': controls, ...props};

Map<String, dynamic> _switch(Map<String, dynamic> props) =>
    {'_c': 'Switch', '_i': 1001, ...props};

final _fixtures = [
  SnapshotFixture(
    'defaults',
    _column([
      _switch({'label': 'Wi-Fi', ..._events}),
    ]),
    target: 1001,
    steps: [
      SnapshotStep.semanticsTap(),
      SnapshotStep.tapText('Wi-Fi'),
      SnapshotStep.tab(),
      SnapshotStep.invoke('focus'),
    ],
  ),
  SnapshotFixture(
    'unlabeled',
    _column([
      _switch({'value': true, ..._events}),
    ]),
    target: 1001,
    steps: [SnapshotStep.semanticsTap()],
  ),
  SnapshotFixture(
    'maximal',
    _column([
      _switch({
        ..._events,
        'on_image_error': true,
        'value': true,
        'label': 'Maximal',
        'label_position': 'left',
        'label_text_style': {'size': 18.0, 'color': '#ff0000'},
        'autofocus': false,
        'active_color': '#112233',
        'active_track_color': '#223344',
        'inactive_thumb_color': '#334455',
        'inactive_track_color': '#445566',
        'thumb_color': {'selected': '#556677', 'default': '#667788'},
        'thumb_icon': {'default': 0x10000},
        'track_color': {'default': '#778899'},
        'track_outline_color': {'default': '#8899aa'},
        'track_outline_width': {'default': 2.0},
        'focus_color': '#99aabb',
        'hover_color': '#aabbcc',
        'overlay_color': {'default': '#bbccdd'},
        'splash_radius': 12.0,
        'padding': 4.0,
        'mouse_cursor': 'click',
        'on_label_color': '#ccddee',
        'off_label_color': '#ddeeff',
        'active_thumb_image_src': _png,
        'inactive_thumb_image': _png,
      }),
    ]),
    target: 1001,
    steps: [SnapshotStep.semanticsTap(), SnapshotStep.tapText('Maximal')],
  ),
  SnapshotFixture(
    'sized',
    _column([
      _switch({'label': 'Big', 'width': 160.0, 'height': 60.0, ..._events}),
    ]),
    target: 1001,
    steps: [SnapshotStep.tapAt(const Offset(0.5, 0.5))],
  ),
  SnapshotFixture(
    'disabled',
    _column([
      _switch({'label': 'Off', 'disabled': true, ..._events}),
    ]),
    target: 1001,
    steps: [SnapshotStep.semanticsTap(), SnapshotStep.tapText('Off')],
  ),
  SnapshotFixture(
    'label_control',
    _column([
      _switch({
        'label': {'_c': 'Text', '_i': 1002, 'value': 'Custom'},
        ..._events,
      }),
    ]),
    target: 1001,
    steps: [SnapshotStep.tapText('Custom')],
  ),
  SnapshotFixture(
    'rtl',
    _column([
      _switch({'label': 'RTL', 'rtl': true, ..._events}),
    ]),
    target: 1001,
    steps: [SnapshotStep.tapText('RTL')],
  ),
  SnapshotFixture(
    'nested_theme',
    _column([
      _switch({
        'label': 'Themed',
        'label_text_style': {'color': 'primary'},
        ..._events,
      }),
    ], {
      'theme': {'color_scheme_seed': '#00aa00'},
    }),
    target: 1001,
    steps: [SnapshotStep.semanticsTap()],
  ),
  SnapshotFixture(
    'list_tile',
    {
      '_c': 'ListTile',
      '_i': 1000,
      'toggle_inputs': true,
      'title': {'_c': 'Text', '_i': 1003, 'value': 'Tile'},
      'trailing': _switch(_events),
    },
    target: 1001,
    steps: [SnapshotStep.tapText('Tile')],
  ),
  SnapshotFixture(
    'list_tile_disabled',
    {
      '_c': 'ListTile',
      '_i': 1000,
      'toggle_inputs': true,
      'title': {'_c': 'Text', '_i': 1003, 'value': 'Tile'},
      'trailing': _switch({'disabled': true, ..._events}),
    },
    target: 1001,
    steps: [SnapshotStep.tapText('Tile')],
  ),
];

void main() {
  for (final fixture in _fixtures) {
    for (final design in HarnessDesign.values) {
      testWidgets('Switch ${fixture.name} on ${design.name}', (tester) async {
        expectSnapshot(await captureSnapshot(tester, design, fixture),
            snapshotPath('Switch', fixture.name, design));
      });
    }
  }
}
