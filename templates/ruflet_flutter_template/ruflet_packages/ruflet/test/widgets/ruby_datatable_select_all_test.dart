import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' as material;
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:ruflet/ruflet.dart';

class _RecordingBackend extends RufletBackend {
  final events = <(int, String, dynamic)>[];

  _RecordingBackend(TargetPlatform platform)
    : super(
        pageUri: Uri.parse('inprocess://datatable-select-all-test'),
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

Map<String, dynamic> _row(int id, String name, bool selected) => {
  '_c': 'DataRow',
  '_i': id,
  'selected': selected,
  'on_select_change': true,
  'cells': [
    {
      '_c': 'DataCell',
      '_i': id + 1,
      'content': {'_c': 'Text', '_i': id + 2, 'value': name},
    },
  ],
};

Future<_RecordingBackend> _pumpTable(
  WidgetTester tester,
  TargetPlatform platform, {
  List<bool> selected = const [false, false],
  bool onSelectAll = true,
  bool showCheckboxColumn = true,
}) async {
  final backend = _RecordingBackend(platform);
  final control = Control.fromMap({
    '_c': 'DataTable',
    '_i': 1,
    'show_checkbox_column': showCheckboxColumn,
    if (onSelectAll) 'on_select_all': true,
    'columns': [
      {
        '_c': 'DataColumn',
        '_i': 2,
        'label': {'_c': 'Text', '_i': 3, 'value': 'Name'},
      },
    ],
    'rows': [_row(10, 'Ada', selected[0]), _row(20, 'Linus', selected[1])],
  }, backend);
  final body = Align(
    alignment: Alignment.topLeft,
    child: ControlWidget(control: control),
  );
  await tester.pumpWidget(
    ChangeNotifierProvider<RufletBackend>.value(
      value: backend,
      child: platform == TargetPlatform.iOS
          ? CupertinoApp(home: body)
          : material.MaterialApp(home: material.Scaffold(body: body)),
    ),
  );
  expect(tester.takeException(), isNull);
  return backend;
}

Finder _checkboxes(TargetPlatform platform) => platform == TargetPlatform.iOS
    ? find.byType(CupertinoCheckbox)
    : find.byType(material.Checkbox);

void main() {
  // Header checkbox state and the value on_select_all receives, as in
  // Flutter's DataTable: none -> true, some -> true, all -> false.
  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    for (final (selected, expected) in [
      ([false, false], true),
      ([true, false], true),
      ([true, true], false),
    ]) {
      testWidgets('$platform DataTable fires Ruby on_select_all ($selected)', (
        tester,
      ) async {
        final backend = await _pumpTable(tester, platform, selected: selected);
        expect(_checkboxes(platform), findsNWidgets(3));
        await tester.tap(_checkboxes(platform).first);
        await tester.pump();
        expect(backend.events, [(1, 'select_all', expected)]);
      });
    }
  }

  testWidgets('Cupertino DataTable header shows a mixed state', (tester) async {
    await _pumpTable(tester, TargetPlatform.iOS, selected: [true, false]);
    final boxes = tester
        .widgetList<CupertinoCheckbox>(find.byType(CupertinoCheckbox))
        .toList();
    expect(boxes.map((b) => b.value), [null, true, false]);
    expect(boxes.first.tristate, isTrue);
  });

  testWidgets('Cupertino DataTable row checkbox fires on_select_change', (
    tester,
  ) async {
    final backend = await _pumpTable(
      tester,
      TargetPlatform.iOS,
      selected: [true, false],
    );
    await tester.tap(find.byType(CupertinoCheckbox).at(1));
    await tester.tap(find.byType(CupertinoCheckbox).at(2));
    await tester.pump();
    expect(backend.events, [
      (10, 'select_change', false),
      (20, 'select_change', true),
    ]);
  });

  testWidgets('Cupertino DataTable header selects rows without on_select_all', (
    tester,
  ) async {
    final backend = await _pumpTable(
      tester,
      TargetPlatform.iOS,
      selected: [true, false],
      onSelectAll: false,
    );
    await tester.tap(find.byType(CupertinoCheckbox).first);
    await tester.pump();
    expect(backend.events, [(20, 'select_change', true)]);
  });

  testWidgets('Cupertino DataTable hides the checkbox column by default', (
    tester,
  ) async {
    await _pumpTable(tester, TargetPlatform.iOS, showCheckboxColumn: false);
    expect(find.byType(CupertinoCheckbox), findsNothing);
  });
}
