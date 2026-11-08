import 'package:flutter/cupertino.dart' show CupertinoActivityIndicator;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:ruflet/ruflet.dart';

import '../support/control_harness.dart';

Future<CircularProgressIndicator> _pumpRing(
  WidgetTester tester,
  Map<String, dynamic> props,
) async {
  final backend = RufletBackend(
    pageUri: Uri.parse('inprocess://progress-ring-keys-test'),
    assetsDir: '',
    extensions: [],
    multiView: false,
  )..platform = TargetPlatform.android;
  final control = Control.fromMap({
    '_c': 'ProgressRing',
    '_i': 1,
    ...props,
  }, backend);
  await tester.pumpWidget(
    ChangeNotifierProvider.value(
      value: backend,
      child: MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: ControlWidget(control: control),
          ),
        ),
      ),
    ),
  );
  expect(tester.takeException(), isNull);
  return tester.widget<CircularProgressIndicator>(
    find.byType(CircularProgressIndicator),
  );
}

void main() {
  // The Cupertino renderer is CupertinoActivityIndicator, which has no
  // year2023 style, so only the Material ring reads Ruby's year_2023.
  for (final year2023 in [false, true]) {
    testWidgets('Material ProgressRing honors Ruby year_2023: $year2023', (
      tester,
    ) async {
      final ring = await _pumpRing(tester, {'year_2023': year2023});
      // ignore: deprecated_member_use
      expect(ring.year2023, year2023);
    });
  }

  testWidgets('Material ProgressRing leaves year2023 to the theme by default', (
    tester,
  ) async {
    final ring = await _pumpRing(tester, {});
    // ignore: deprecated_member_use
    expect(ring.year2023, isNull);
  });

  // ProgressRingCore resolves one fraction for both designs.
  Map<String, dynamic> ring(Map<String, dynamic> props) => {
        '_c': 'Column',
        '_i': 2100,
        'controls': [
          {'_c': 'ProgressRing', '_i': 2101, ...props}
        ],
      };

  testWidgets('Material ProgressRing honors the iOS progress key',
      (tester) async {
    await mountWire(tester, HarnessDesign.android, ring({'progress': 0.3}));
    expect(
        tester
            .widget<CircularProgressIndicator>(
                find.byType(CircularProgressIndicator))
            .value,
        0.3);
  });

  testWidgets('iOS ProgressRing clamps an out-of-range value', (tester) async {
    await mountWire(tester, HarnessDesign.ios, ring({'value': 1.5}));
    expect(tester.takeException(), isNull);
    expect(
        tester
            .widget<CupertinoActivityIndicator>(
                find.byType(CupertinoActivityIndicator))
            .progress,
        1.0);
  });

  testWidgets('iOS ProgressRing announces its label and percentage',
      (tester) async {
    final semantics = tester.ensureSemantics();
    await mountWire(tester, HarnessDesign.ios,
        ring({'value': 0.25, 'semantics_label': 'Loading'}));
    expect(tester.getSemantics(find.byType(CupertinoActivityIndicator)),
        matchesSemantics(label: 'Loading', value: '25'));
    semantics.dispose();
  });
}
