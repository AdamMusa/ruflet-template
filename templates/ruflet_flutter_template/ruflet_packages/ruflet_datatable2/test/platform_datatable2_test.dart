import 'package:data_table_2/data_table_2.dart';
import 'package:ruflet/ruflet.dart';
import 'package:ruflet_datatable2/src/datatable2.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart' as material;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class RecordingBackend extends RufletBackend {
  final events = <(int, String, dynamic)>[];
  RecordingBackend(TargetPlatform target)
      : super(
            pageUri: Uri.parse('ruflet://test'),
            assetsDir: '',
            extensions: [],
            multiView: false) {
    platform = target;
  }

  @override
  void triggerControlEventById(int controlId, String eventName,
      [dynamic eventData]) {
    events.add((controlId, eventName, eventData));
  }
}

Control fixture(RecordingBackend backend,
        {bool selection = true, int count = 8}) =>
    Control.fromMap({
      '_c': 'DataTable2',
      '_i': 1,
      'min_width': 700.0,
      'fixed_top_rows': 1,
      'fixed_left_columns': 1,
      'show_checkbox_column': selection,
      'sort_column_index': 0,
      'sort_ascending': true,
      'horizontal_margin': 12.0,
      'column_spacing': 24.0,
      'columns': [
        {
          '_c': 'DataColumn2',
          '_i': 2,
          'label': 'Name',
          'on_sort': true,
          'fixed_width': 180.0
        },
        {'_c': 'DataColumn2', '_i': 3, 'label': 'Value'},
      ],
      'rows': [
        for (var i = 0; i < count; i++)
          {
            '_c': 'DataRow2',
            '_i': 100 + i,
            'selected': false,
            'on_select_change': selection,
            'on_tap': true,
            'on_double_tap': true,
            'on_long_press': true,
            'on_secondary_tap': true,
            'cells': [
              {
                '_c': 'DataCell',
                '_i': 200 + i * 2,
                'on_tap': true,
                'content': {
                  '_c': 'Text',
                  '_i': 300 + i * 2,
                  'value': 'Row $i',
                }
              },
              {
                '_c': 'DataCell',
                '_i': 201 + i * 2,
                'content': {
                  '_c': 'Text',
                  '_i': 301 + i * 2,
                  'value': 'Value $i',
                }
              },
            ],
          }
      ],
    }, backend);

Widget host(RecordingBackend backend, Control control) {
  final child = Center(
      child: SizedBox(
          width: 480, height: 260, child: DataTable2Control(control: control)));
  return ChangeNotifierProvider<RufletBackend>.value(
      value: backend,
      child: backend.platform == TargetPlatform.iOS
          ? CupertinoApp(home: CupertinoPageScaffold(child: child))
          : material.MaterialApp(home: material.Scaffold(body: child)));
}

void main() {
  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    testWidgets(
        '$platform wire entrypoint preserves sort, selection and cell events',
        (tester) async {
      final backend = RecordingBackend(platform);
      final control = fixture(backend, count: 2);
      await tester.pumpWidget(host(backend, control));
      await tester.pump();
      expect(tester.takeException(), isNull);
      if (platform == TargetPlatform.iOS) {
        expect(find.byType(DataTable2), findsNothing);
        expect(find.byType(material.Material), findsNothing);
        expect(find.byType(material.Theme), findsNothing);
        expect(find.byType(material.Checkbox), findsNothing);
        expect(find.byType(CupertinoCheckbox), findsNWidgets(3));
      } else {
        expect(find.byType(DataTable2), findsOneWidget);
        expect(find.byType(material.Checkbox), findsNWidgets(3));
      }
      await tester.tap(find.text('Name'));
      await tester.pumpAndSettle();
      expect(backend.events.single.$1, 2);
      expect(backend.events.single.$2, 'sort');
      expect(backend.events.single.$3, {'ci': 0, 'asc': false});
      final checkbox = platform == TargetPlatform.iOS
          ? find.byType(CupertinoCheckbox)
          : find.byType(material.Checkbox);
      await tester.tap(checkbox.at(1));
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      expect(backend.events, contains((100, 'select_change', true)));
      await tester.tap(find.text('Row 0'));
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      expect(backend.events, contains((200, 'tap', null)));
      expect(backend.events, contains((100, 'tap', null)));
      await tester.longPress(find.text('Row 0'));
      await tester.pumpAndSettle();
      expect(backend.events, contains((100, 'long_press', null)));
      await tester.tap(find.text('Row 0'), buttons: kSecondaryMouseButton);
      await tester.pump(const Duration(milliseconds: 350));
      expect(backend.events, contains((100, 'secondary_tap', null)));
      await tester.tap(checkbox.first);
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      expect(backend.events, contains((101, 'select_change', true)));
      await tester.pumpWidget(const SizedBox());
      backend.dispose();
    });
  }

  testWidgets(
      'Cupertino fixed heading and first column stay put while body scrolls',
      (tester) async {
    final backend = RecordingBackend(TargetPlatform.iOS);
    final control = fixture(backend, selection: false);
    await tester.pumpWidget(host(backend, control));
    await tester.pump();
    final heading = tester.getTopLeft(find.text('Name'));
    final firstColumnX = tester.getTopLeft(find.text('Row 0')).dx;
    final valueX = tester.getTopLeft(find.text('Value 0')).dx;
    await tester.drag(find.text('Value 0'), const Offset(-180, 0));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.text('Row 0')).dx, firstColumnX);
    expect(tester.getTopLeft(find.text('Value 0')).dx, lessThan(valueX));
    await tester.dragFrom(
        tester.getTopLeft(find.byType(DataTable2Control)) +
            const Offset(430, 180),
        const Offset(0, -150));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.text('Name')), heading);
    expect(tester.getTopLeft(find.text('Row 1')).dy,
        closeTo(tester.getTopLeft(find.text('Value 1')).dy, .1));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    backend.dispose();
  });

  testWidgets('Cupertino empty table displays the wire empty control',
      (tester) async {
    final backend = RecordingBackend(TargetPlatform.iOS);
    final control = fixture(backend, count: 0);
    control.properties['empty'] = Control.fromMap(
        {'_c': 'Text', '_i': 900, 'value': 'No records'}, backend);
    await tester.pumpWidget(host(backend, control));
    expect(find.text('No records'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    backend.dispose();
  });

  testWidgets(
      'Cupertino custom row height, state color and keyboard sorting work',
      (tester) async {
    final backend = RecordingBackend(TargetPlatform.iOS);
    final control = fixture(backend, selection: false, count: 2);
    control.properties['data_row_color'] = {
      'hovered': '#ff0000',
      'default': '#00ff00'
    };
    control.children('rows').first.properties['specific_row_height'] = 72.0;
    await tester.pumpWidget(host(backend, control));
    await tester.pump();
    final row = find.byKey(const ValueKey('table-pane-scroll-100'));
    expect(tester.getSize(row).height, 72);
    BoxDecoration decoration() =>
        tester.widget<Container>(row).decoration! as BoxDecoration;
    expect(decoration().color, const Color(0xff00ff00));
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester
        .getRect(row)
        .intersect(tester.getRect(find.byType(DataTable2Control)))
        .center);
    await tester.pump();
    expect(decoration().color, const Color(0xffff0000));
    Focus.of(tester.element(find.text('Name'))).requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(backend.events.last.$2, 'sort');
    expect(backend.events.last.$3, {'ci': 0, 'asc': false});
    await mouse.removePointer();
    await tester.pumpWidget(const SizedBox());
    backend.dispose();
  });
}
