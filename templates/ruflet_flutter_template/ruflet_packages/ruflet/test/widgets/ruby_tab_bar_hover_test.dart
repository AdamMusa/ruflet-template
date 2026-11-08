import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart' as material;
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:ruflet/ruflet.dart';

class _RecordingBackend extends RufletBackend {
  final events = <(int, String, dynamic)>[];

  _RecordingBackend(TargetPlatform platform)
    : super(
        pageUri: Uri.parse('inprocess://tab-bar-hover-test'),
        assetsDir: '',
        extensions: [],
        multiView: false,
      ) {
    this.platform = platform;
  }

  @override
  void triggerControlEventById(
    int controlId,
    String eventName, [
    dynamic eventData,
  ]) => events.add((controlId, eventName, eventData));
}

Future<_RecordingBackend> _pump(
  WidgetTester tester,
  TargetPlatform platform,
  Map<String, dynamic> wire,
) async {
  final backend = _RecordingBackend(platform);
  final control = Control.fromMap(wire, backend);
  final body = Align(
    alignment: Alignment.topLeft,
    child: SizedBox(width: 400, child: ControlWidget(control: control)),
  );
  await tester.pumpWidget(
    ChangeNotifierProvider<RufletBackend>.value(
      value: backend,
      child: platform == TargetPlatform.iOS
          ? CupertinoApp(home: body)
          : material.MaterialApp(home: material.Scaffold(body: body)),
    ),
  );
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
  return backend;
}

// A mouse/trackpad pointer: macOS, or iPadOS with a pointer attached.
Future<TestGesture> _mouse(WidgetTester tester) async {
  final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
  await gesture.addPointer(location: const Offset(399, 599));
  addTearDown(gesture.removePointer);
  return gesture;
}

void main() {
  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    testWidgets('$platform TabBar fires Ruby on_hover per tab', (tester) async {
      final backend = await _pump(tester, platform, {
        '_c': 'Tabs',
        '_i': 1,
        'length': 2,
        'content': {
          '_c': 'Column',
          '_i': 2,
          'controls': [
            {
              '_c': 'TabBar',
              '_i': 3,
              'on_hover': true,
              'tabs': [
                {'_c': 'Tab', '_i': 4, 'label': 'One'},
                {'_c': 'Tab', '_i': 5, 'label': 'Two'},
              ],
            },
          ],
        },
      });
      final mouse = await _mouse(tester);
      await mouse.moveTo(tester.getCenter(find.text('Two')));
      await tester.pumpAndSettle();
      await mouse.moveTo(const Offset(399, 599));
      await tester.pumpAndSettle();

      final hovers = [
        for (final (id, name, data) in backend.events)
          if (id == 3 && name == 'hover') data,
      ];
      expect(hovers, [
        {'hovering': true, 'index': 1},
        {'hovering': false, 'index': 1},
      ]);
    });
  }
}
