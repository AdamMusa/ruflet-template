import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../support/control_harness.dart';
import '../support/control_snapshot.dart';
import '../support/core_probe.dart';

SnapshotFixture _fixture() => SnapshotFixture(
      'probe',
      {
        '_c': 'Column',
        '_i': 800,
        'controls': [
          {
            '_c': 'CoreProbe',
            '_i': 801,
            'value': true,
            'caption': 'Probe',
            'on_click': true,
            'on_focus': true,
          },
        ],
      },
      target: 801,
      steps: [
        SnapshotStep.tapAt(const Offset(0.5, 0.5)),
        SnapshotStep.invoke('echo', args: {'value': 3}),
        SnapshotStep.invoke('focus'),
        SnapshotStep.invoke('missing'),
      ],
      extensions: [ProbeExtension()],
    );

void main() {
  testWidgets('a snapshot records geometry, semantics, messages and invokes',
      (tester) async {
    final snapshot =
        await captureSnapshot(tester, HarnessDesign.ios, _fixture());
    expect(snapshot['fixture'], 'probe');
    expect(snapshot['design'], 'ios');

    final geometry = snapshot['geometry'] as Map;
    expect(geometry['size'], isA<Map>());
    expect(geometry['elements'], [
      {
        'key': 'probe_decoration',
        'rect': {'l': 0.0, 't': 0.0, 'w': isPositive, 'h': isPositive},
      },
      {
        'key': 'probe_cupertino',
        'rect': {'l': 0.0, 't': 0.0, 'w': isPositive, 'h': isPositive},
      },
      {
        'text': 'true:null:Probe',
        // After the probe's 24 px native toggle.
        'rect': {
          'l': 24.0,
          't': isNonNegative,
          'w': isPositive,
          'h': isPositive
        },
      }
    ]);
    final semantics = (snapshot['semantics'] as List).first as Map;
    expect(semantics['label'], 'true:null:Probe');
    expect(semantics['actions'], contains('tap'));
    expect(semantics['rect'], {'l': 0.0, 't': 0.0, 'w': isPositive, 'h': 24.0});

    final steps = (snapshot['steps'] as List).cast<Map>();
    expect(steps.map((s) => s['step']), [
      'tap at 0.5,0.5',
      'invoke echo',
      'invoke focus',
      'invoke missing',
    ]);
    expect(steps[0]['sent'], [
      {'id': 801, 'event': 'click', 'data': null}
    ]);
    expect(steps[1]['outcome'], {'result': 3});
    expect(steps[2]['sent'], [
      {'id': 801, 'event': 'focus', 'data': null}
    ]);
    expect(steps[3]['outcome'], {
      'error': 'UnsupportedError',
      'message': 'CoreProbe(801).missing is not supported on iOS: no handler '
          'for "missing" is registered for this control',
    });
    expect(jsonDecode(jsonEncode(snapshot)), snapshot,
        reason: 'snapshots are plain JSON');
  });

  testWidgets('snapshots are stable across runs and designs differ',
      (tester) async {
    final first =
        await captureSnapshot(tester, HarnessDesign.android, _fixture());
    final second =
        await captureSnapshot(tester, HarnessDesign.android, _fixture());
    final ios = await captureSnapshot(tester, HarnessDesign.ios, _fixture());
    expect(second, first);
    expect(ios, isNot(first));
  });

  testWidgets('a step that cannot interact is noted, not failed',
      (tester) async {
    final base = _fixture();
    final snapshot = await captureSnapshot(
        tester,
        HarnessDesign.android,
        SnapshotFixture('probe', base.wire,
            target: base.target,
            steps: [SnapshotStep.tapText('absent')],
            extensions: base.extensions));
    expect((snapshot['steps'] as List).single,
        containsPair('note', 'text not rendered'));
  });

  test('expectSnapshot compares with the checked-in file', () {
    final dir = Directory.systemTemp.createTempSync('ruflet_snapshot');
    addTearDown(() => dir.deleteSync(recursive: true));
    final path = '${dir.path}/Probe/probe.ios.json';
    final snapshot = {'fixture': 'probe', 'steps': <Object>[]};

    expect(() => expectSnapshot(snapshot, path), throwsA(isA<TestFailure>()),
        reason: 'a missing snapshot fails');
    File(path)
      ..createSync(recursive: true)
      ..writeAsStringSync(
          '${const JsonEncoder.withIndent('  ').convert(snapshot)}\n');
    expectSnapshot(snapshot, path);
    expect(() => expectSnapshot({...snapshot, 'fixture': 'other'}, path),
        throwsA(isA<TestFailure>()));
    expect(snapshotPath('Switch', 'defaults', HarnessDesign.android),
        'test/snapshots/Switch/defaults.android.json');
  });
}
