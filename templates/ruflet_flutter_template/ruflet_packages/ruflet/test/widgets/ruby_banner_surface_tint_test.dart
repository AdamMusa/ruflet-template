import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:ruflet/ruflet.dart';

const _tint = Color(0xff00ff00);

Future<void> _pump(WidgetTester tester, Map<String, dynamic> wire) async {
  final backend = RufletBackend(
    pageUri: Uri.parse('inprocess://surface-tint-test'),
    assetsDir: '',
    extensions: [],
    multiView: false,
  )..platform = TargetPlatform.android;
  final control = Control.fromMap(wire, backend);
  await tester.pumpWidget(
    ChangeNotifierProvider.value(
      value: backend,
      child: MaterialApp(
        home: Scaffold(body: ControlWidget(control: control)),
      ),
    ),
  );
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
}

// Surface tint is a Material 3 elevation overlay; the Cupertino renderers
// have no equivalent, so only the Material design reads the key.
void main() {
  testWidgets('Material Banner honors Ruby surface_tint_color', (tester) async {
    await _pump(tester, {
      '_c': 'Banner',
      '_i': 1,
      'open': true,
      'surface_tint_color': '#00ff00',
      'content': {'_c': 'Text', '_i': 2, 'value': 'Offline'},
      'actions': [
        {'_c': 'Button', '_i': 3, 'content': 'Retry'},
      ],
    });
    expect(find.text('Offline'), findsOneWidget);
    expect(
      tester
          .widget<MaterialBanner>(find.byType(MaterialBanner))
          .surfaceTintColor,
      _tint,
    );
  });
}
