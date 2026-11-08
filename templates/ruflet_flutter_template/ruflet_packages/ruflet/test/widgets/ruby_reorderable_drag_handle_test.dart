import 'package:ruflet/ruflet.dart';
import 'package:ruflet/src/controls/cupertino_reorderable_list_view.dart';
import 'package:ruflet/src/controls/material_reorderable_list_view.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' as material;
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class _Backend extends RufletBackend {
  final events = <(String, dynamic)>[];

  _Backend(TargetPlatform target)
      : super(
            pageUri: Uri.parse('inprocess://drag-handle-test'),
            assetsDir: '',
            extensions: [],
            multiView: false) {
    platform = target;
  }

  @override
  void updateControl(int id, Map<String, dynamic> props,
          {bool dart = true, bool python = true, bool notify = false}) =>
      super.updateControl(id, props, dart: dart, python: false, notify: notify);

  @override
  void triggerControlEvent(Control control, String name, [dynamic data]) {
    events.add((name, data));
  }
}

Map<String, dynamic> _row(int id, String label, Map<String, dynamic> handle) => {
      '_c': 'Container',
      '_i': id,
      'height': 60,
      'alignment': {'x': -1, 'y': -1},
      'content': {
        '_c': 'ReorderableDragHandle',
        '_i': id + 1,
        ...handle,
        'content': {'_c': 'Text', '_i': id + 2, 'value': label},
      },
    };

Future<_Backend> _pumpList(WidgetTester tester, TargetPlatform platform,
    Map<String, dynamic> handle) async {
  final backend = _Backend(platform);
  final control = Control.fromMap({
    '_c': 'ReorderableListView',
    '_i': 1,
    'show_default_drag_handles': false,
    'on_reorder': true,
    'controls': [
      _row(10, 'A', handle),
      _row(20, 'B', handle),
      _row(30, 'C', handle),
    ],
  }, backend);
  final body = Align(
      alignment: Alignment.topLeft,
      child: SizedBox(
          width: 300, height: 400, child: ControlWidget(control: control)));
  await tester.pumpWidget(ChangeNotifierProvider<RufletBackend>.value(
    value: backend,
    child: platform == TargetPlatform.android
        ? material.MaterialApp(home: material.Scaffold(body: body))
        : CupertinoApp(home: body),
  ));
  await tester.pump();
  return backend;
}

Finder _listenerOf(String label) => find.ancestor(
    of: find.text(label), matching: find.byType(ReorderableDragStartListener));

Future<void> _dragDown(WidgetTester tester, Offset start, double dy) async {
  final gesture = await tester.startGesture(start);
  await tester.pump(const Duration(milliseconds: 50));
  for (var i = 0; i < 8; i++) {
    await gesture.moveBy(Offset(0, dy / 8));
    await tester.pump(const Duration(milliseconds: 50));
  }
  await gesture.up();
  await tester.pumpAndSettle();
}

void main() {
  for (final platform in [
    TargetPlatform.iOS,
    TargetPlatform.macOS,
    TargetPlatform.android,
  ]) {
    final listType = platform == TargetPlatform.android
        ? MaterialReorderableListViewControl
        : CupertinoReorderableListViewControl;

    testWidgets('$platform ReorderableDragHandle applies Ruby layout keywords',
        (tester) async {
      await _pumpList(tester, platform, {
        'width': 40,
        'height': 30,
        'margin': {'left': 8, 'top': 10, 'right': 0, 'bottom': 0},
        'opacity': 0.5,
      });
      expect(find.byType(listType), findsOneWidget);

      final row = tester.getTopLeft(find
          .ancestor(of: find.text('A'), matching: find.byType(Container))
          .last);
      final handle = tester.getRect(_listenerOf('A'));
      expect(handle.size, const Size(40, 30));
      expect(handle.topLeft - row, const Offset(8, 10));

      final opacity = tester.widget<Opacity>(find
          .ancestor(of: _listenerOf('A'), matching: find.byType(Opacity))
          .first);
      expect(opacity.opacity, 0.5);
      expect(tester.takeException(), isNull);
    });

    testWidgets('$platform ReorderableDragHandle without layout keywords keeps its content size',
        (tester) async {
      await _pumpList(tester, platform, {});
      expect(tester.getSize(_listenerOf('A')), tester.getSize(find.text('A')));
      expect(tester.takeException(), isNull);
    });

    testWidgets('$platform sized ReorderableDragHandle still reorders items',
        (tester) async {
      final backend = await _pumpList(tester, platform, {
        'width': 40,
        'height': 30,
        'margin': {'left': 8, 'top': 10, 'right': 0, 'bottom': 0},
        'tooltip': 'Drag to reorder',
      });

      await _dragDown(tester, tester.getCenter(_listenerOf('A')), 75);

      final reorder = backend.events.where((e) => e.$1 == 'reorder').toList();
      expect(reorder, hasLength(1));
      expect(reorder.single.$2, {'old_index': 0, 'new_index': 1});
      expect(tester.getTopLeft(find.text('B')).dy,
          lessThan(tester.getTopLeft(find.text('A')).dy));
      expect(tester.takeException(), isNull);
    });

    testWidgets('$platform disabled ReorderableDragHandle does not start a drag',
        (tester) async {
      final backend = await _pumpList(tester, platform, {
        'width': 40,
        'height': 30,
        'disabled': true,
      });

      await _dragDown(tester, tester.getCenter(_listenerOf('A')), 75);

      expect(backend.events.where((e) => e.$1 == 'reorder'), isEmpty);
      expect(tester.getTopLeft(find.text('A')).dy,
          lessThan(tester.getTopLeft(find.text('B')).dy));
    });
  }
}
