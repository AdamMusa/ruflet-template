import 'package:ruflet/ruflet.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' as material;
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class _Backend extends RufletBackend {
  _Backend(TargetPlatform target)
      : super(
            pageUri: Uri.parse('inprocess://scroll-methods-test'),
            assetsDir: '',
            extensions: [],
            multiView: false) {
    platform = target;
  }

  @override
  void triggerControlEvent(Control control, String name, [dynamic data]) {}

  @override
  void updateControl(int id, Map<String, dynamic> props,
          {bool dart = true, bool python = true, bool notify = false}) =>
      super.updateControl(id, props, dart: dart, python: false, notify: notify);
}

Widget _host(RufletBackend backend, Widget child) {
  final body = Align(
      alignment: Alignment.topLeft,
      child: SizedBox(width: 300, height: 200, child: child));
  return ChangeNotifierProvider<RufletBackend>.value(
    value: backend,
    child: backend.platform == TargetPlatform.iOS
        ? CupertinoApp(home: body)
        : material.MaterialApp(home: body),
  );
}

List<Map<String, dynamic>> _items(int count, {double height = 50}) => [
      for (var i = 0; i < count; i++)
        {
          '_c': 'Container',
          '_i': 1000 + i,
          'height': height,
          'width': height,
          'content': {'_c': 'Text', '_i': 2000 + i, 'value': 'Item $i'},
        }
    ];

Map<String, dynamic> _fixture(String type) => switch (type) {
      'ListView' => {'_c': 'ListView', '_i': 1, 'controls': _items(30)},
      'GridView' => {
          '_c': 'GridView',
          '_i': 1,
          'runs_count': 3,
          'controls': _items(60)
        },
      'Column' => {
          '_c': 'Column',
          '_i': 1,
          'scroll': 'auto',
          'controls': _items(30)
        },
      'Row' => {'_c': 'Row', '_i': 1, 'scroll': 'auto', 'controls': _items(30)},
      'ReorderableListView' => {
          '_c': 'ReorderableListView',
          '_i': 1,
          'expand': true,
          'controls': _items(30)
        },
      _ => throw ArgumentError(type),
    };

ScrollPosition _position(WidgetTester tester) =>
    tester.state<ScrollableState>(find.byType(Scrollable).first).position;

/// Invokes a Ruby control method the way the backend does and pumps frames
/// until it completes, failing (instead of hanging) when no renderer listener
/// answers within the invoke timeout.
Future<dynamic> _invoke(WidgetTester tester, Control control, String name,
    Map<String, dynamic> args,
    {void Function()? onFrame}) async {
  var done = false;
  Object? error;
  dynamic result;
  control.invokeMethod(name, args, const Duration(seconds: 1)).then((value) {
    result = value;
    done = true;
  }, onError: (Object e) {
    error = e;
    done = true;
  });
  for (var i = 0; i < 30 && !done; i++) {
    await tester.pump(const Duration(milliseconds: 50));
    onFrame?.call();
  }
  await tester.pump();
  expect(error, isNull, reason: '$name must have a renderer listener');
  expect(done, isTrue, reason: '$name did not complete');
  return result;
}

void main() {
  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    for (final type in [
      'ListView',
      'GridView',
      'Column',
      'Row',
      'ReorderableListView'
    ]) {
      testWidgets('${platform.name}: $type answers the Ruby scroll_to method',
          (tester) async {
        final backend = _Backend(platform);
        final control = Control.fromMap(_fixture(type), backend);
        await tester
            .pumpWidget(_host(backend, ControlWidget(control: control)));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final position = _position(tester);
        expect(position.pixels, 0);
        expect(position.maxScrollExtent, greaterThan(200));

        await _invoke(tester, control, 'scroll_to', {'offset': 120});
        expect(position.pixels, 120);

        await _invoke(tester, control, 'scroll_to', {'delta': 30});
        expect(position.pixels, 150);

        await _invoke(tester, control, 'scroll_to', {'offset': -1});
        expect(position.pixels, position.maxScrollExtent);

        final pixels = <double>[];
        await _invoke(tester, control, 'scroll_to',
            {'offset': 0, 'duration': 300, 'curve': 'easeOut'},
            onFrame: () => pixels.add(position.pixels));
        expect(pixels.any((p) => p > 0 && p < position.maxScrollExtent), isTrue,
            reason: 'duration animates instead of jumping: $pixels');
        expect(position.pixels, 0);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
