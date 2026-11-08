import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' as material;
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:ruflet/ruflet.dart';

RufletBackend _backend(TargetPlatform platform) => RufletBackend(
      pageUri: Uri.parse('inprocess://dismissible-keys-test'),
      assetsDir: '',
      extensions: [],
      multiView: false,
    )..platform = platform;

Widget _host(RufletBackend backend, Widget child) {
  final body = Align(alignment: Alignment.topLeft, child: child);
  return ChangeNotifierProvider.value(
    value: backend,
    child: backend.platform == TargetPlatform.iOS
        ? CupertinoApp(home: body)
        : material.MaterialApp(home: material.Scaffold(body: body)),
  );
}

Future<Dismissible> _pumpDismissible(WidgetTester tester,
    TargetPlatform platform, Map<String, dynamic> props) async {
  final backend = _backend(platform);
  final control = Control.fromMap({
    '_c': 'Dismissible',
    '_i': 1,
    ...props,
    'content': {'_c': 'Text', '_i': 2, 'value': 'Swipe me'},
  }, backend);
  await tester.pumpWidget(_host(backend, ControlWidget(control: control)));
  expect(tester.takeException(), isNull);
  return tester.widget<Dismissible>(find.byType(Dismissible));
}

void main() {
  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    testWidgets('$platform Dismissible honors Ruby movement/resize durations',
        (tester) async {
      final dismissible = await _pumpDismissible(tester, platform, {
        'movement_duration': 1234,
        'resize_duration': 4321,
      });
      expect(dismissible.movementDuration, const Duration(milliseconds: 1234));
      expect(dismissible.resizeDuration, const Duration(milliseconds: 4321));
    });

    testWidgets('$platform Dismissible keeps default durations',
        (tester) async {
      final dismissible = await _pumpDismissible(tester, platform, {});
      expect(dismissible.movementDuration, const Duration(milliseconds: 200));
      expect(dismissible.resizeDuration, const Duration(milliseconds: 300));
    });
  }
}
