import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' as material;
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:ruflet/ruflet.dart';
import 'package:ruflet/src/controls/container.dart';

Map<String, dynamic> _item(int id, String text) => {
      '_c': 'Container',
      '_i': id,
      'height': 30,
      'content': {'_c': 'Text', '_i': id + 1, 'value': text},
    };

Future<void> _pumpList(
  WidgetTester tester,
  TargetPlatform platform,
  Map<String, dynamic> props,
) async {
  final backend = RufletBackend(
    pageUri: Uri.parse('inprocess://reorderable-list-view-keys-test'),
    assetsDir: '',
    extensions: [],
    multiView: false,
  )..platform = platform;
  final control = Control.fromMap({
    '_c': 'ReorderableListView',
    '_i': 1,
    'height': 400,
    'show_default_drag_handles': false,
    ...props,
    'controls': [_item(10, 'One'), _item(20, 'Two'), _item(30, 'Three')],
  }, backend);
  final body = Align(
    alignment: Alignment.topLeft,
    child: SizedBox(width: 300, child: ControlWidget(control: control)),
  );
  await tester.pumpWidget(
    ChangeNotifierProvider.value(
      value: backend,
      child: platform == TargetPlatform.iOS
          ? CupertinoApp(home: body)
          : material.MaterialApp(home: material.Scaffold(body: body)),
    ),
  );
  expect(tester.takeException(), isNull);
}

Rect _rect(WidgetTester tester, String text) => tester.getRect(
      find
          .ancestor(
              of: find.text(text), matching: find.byType(ContainerControl))
          .first,
    );

void main() {
  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    testWidgets('$platform ReorderableListView honors Ruby spacing', (
      tester,
    ) async {
      await _pumpList(tester, platform, {'spacing': 12});
      expect(_rect(tester, 'Two').top - _rect(tester, 'One').bottom, 12);
      expect(_rect(tester, 'Three').top - _rect(tester, 'Two').bottom, 12);
    });

    testWidgets('$platform ReorderableListView honors Ruby divider_thickness', (
      tester,
    ) async {
      await _pumpList(tester, platform, {
        'spacing': 12,
        'divider_thickness': 2,
      });
      final lines = find.byWidgetPredicate(
        (widget) =>
            widget is SizedBox &&
            widget.height == 2 &&
            widget.child is ColoredBox,
      );
      expect(lines, findsNWidgets(2), reason: 'one divider between each pair');
      final line = tester.getRect(lines.first);
      expect(line.top, _rect(tester, 'One').bottom + 5);
      expect(line.width, 300);
    });

    testWidgets('$platform ReorderableListView honors Ruby prototype_item', (
      tester,
    ) async {
      await _pumpList(tester, platform, {
        'prototype_item': {
          '_c': 'Container',
          '_i': 90,
          'height': 50,
          'content': {'_c': 'Text', '_i': 91, 'value': 'Prototype'},
        },
      });
      // Every item takes the prototype's extent, not its own 30.
      expect(_rect(tester, 'Two').top - _rect(tester, 'One').top, 50);
    });
  }
}
