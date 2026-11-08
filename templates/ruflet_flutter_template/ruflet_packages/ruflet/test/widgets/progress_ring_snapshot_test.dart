// Behaviour snapshots of ProgressRing (the `progress_ring` and
// `cupertino_activity_indicator` DSL names) on iOS and Android: geometry,
// semantics (the accessibility label and value), the native indicator's
// state, what it sends to Ruby during scripted taps and invoke outcomes. Rewrite with
// `flutter test --update-goldens` only for a change listed in the PR's
// "Parity changes" table.
import 'package:flutter/cupertino.dart' show CupertinoActivityIndicator;
import 'package:flutter/material.dart' show CircularProgressIndicator;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ruflet/ruflet.dart';

import '../support/control_harness.dart';
import '../support/control_snapshot.dart';

const _target = 2001;

Map<String, dynamic> _column(Map<String, dynamic> props) => {
      '_c': 'Column',
      '_i': 2000,
      'controls': [
        {'_c': 'ProgressRing', '_i': _target, ...props}
      ],
    };

/// Fixtures whose indicator is determinate on both designs, so the harness
/// can settle them and run steps.
final _settled = [
  SnapshotFixture(
    'determinate',
    _column({'value': 0.5}),
    target: _target,
    steps: [
      SnapshotStep.tapAt(const Offset(0.5, 0.5)),
      SnapshotStep.invoke('focus'),
      SnapshotStep.unfocus(),
    ],
  ),
  SnapshotFixture(
    'labelled',
    _column({
      'value': 0.25,
      'semantics_label': 'Loading',
      'semantics_value': 42,
    }),
    target: _target,
  ),
  SnapshotFixture(
    'value_and_progress',
    _column({'value': 0.2, 'progress': 0.8}),
    target: _target,
  ),
  SnapshotFixture(
    'maximal',
    _column({
      'value': 0.5,
      'color': '#336699',
      'bgcolor': '#eeeeee',
      'stroke_width': 6.0,
      'stroke_cap': 'square',
      'stroke_align': 0.0,
      'track_gap': 4.0,
      'size_constraints': {'min_width': 48.0, 'min_height': 48.0},
      'padding': 2.0,
      'year_2023': false,
      'radius': 16.0,
      'semantics_label': 'Uploading',
    }),
    target: _target,
  ),
  SnapshotFixture(
    'layout',
    _column({
      'value': 0.5,
      'width': 60.0,
      'height': 60.0,
      'margin': 4.0,
      'opacity': 0.5,
    }),
    target: _target,
  ),
];

/// Fixtures with an indicator that animates on at least one design: the
/// harness cannot settle them, so they are pumped for a fixed time and record
/// whether a frame is still scheduled (the indicator spins).
final _ticking = {
  'indeterminate': _column({}),
  'progress_only': _column({'progress': 0.3}),
  'paused': _column({'animating': false}),
  'radius': _column({'radius': 20.0}),
};

Map<String, Object?> _nativeState(WidgetTester tester, Finder control) {
  final material = find.descendant(
      of: control, matching: find.byType(CircularProgressIndicator));
  if (material.evaluate().isNotEmpty) {
    final ring = tester.widget<CircularProgressIndicator>(material);
    return {
      'type': 'CircularProgressIndicator',
      'value': ring.value,
    };
  }
  final cupertino = find.descendant(
      of: control, matching: find.byType(CupertinoActivityIndicator));
  if (cupertino.evaluate().isNotEmpty) {
    final indicator = tester.widget<CupertinoActivityIndicator>(cupertino);
    return {
      'type': 'CupertinoActivityIndicator',
      'animating': indicator.animating,
      'progress': indicator.progress,
      'radius': indicator.radius,
    };
  }
  return {'type': null};
}

Future<Map<String, Object?>> _captureTicking(WidgetTester tester,
    HarnessDesign design, String name, Map<String, dynamic> wire) async {
  final semantics = tester.ensureSemantics();
  try {
    await tester.binding.setSurfaceSize(const Size(800, 600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final backend = HarnessBackend(design);
    final root = Control.fromMap(copyWire(wire), backend);
    await tester.pumpWidget(const SizedBox());
    await tester
        .pumpWidget(harnessApp(backend, design, ControlWidget(control: root)));
    await tester.pump(const Duration(milliseconds: 100));
    final control = find.byWidgetPredicate(
        (widget) => widget is ControlWidget && widget.control.id == _target);
    expect(control, findsOneWidget);
    final box = tester.renderObject<RenderBox>(control);
    final size = rectJson(Offset.zero & box.size);
    final snapshot = <String, Object?>{
      'fixture': name,
      'design': design.name,
      'size': {'w': size['w'], 'h': size['h']},
      'ticking': tester.binding.hasScheduledFrame,
      'native': _nativeState(tester, control),
      'semantics': semanticsWithin(tester, control),
    };
    expect(tester.takeException(), isNull);
    // Stop the indicator before the test ends.
    await tester.pumpWidget(const SizedBox());
    return snapshot;
  } finally {
    semantics.dispose();
  }
}

void main() {
  for (final fixture in _settled) {
    for (final design in HarnessDesign.values) {
      testWidgets('${fixture.name} on ${design.name}', (tester) async {
        final snapshot = await captureSnapshot(tester, design, fixture);
        final control = find.byWidgetPredicate((widget) =>
            widget is ControlWidget && widget.control.id == _target);
        snapshot['native'] = _nativeState(tester, control);
        expectSnapshot(
            snapshot, snapshotPath('ProgressRing', fixture.name, design));
      });
    }
  }
  for (final MapEntry(key: name, value: wire) in _ticking.entries) {
    for (final design in HarnessDesign.values) {
      testWidgets('$name on ${design.name}', (tester) async {
        expectSnapshot(await _captureTicking(tester, design, name, wire),
            snapshotPath('ProgressRing', name, design));
      });
    }
  }
}
