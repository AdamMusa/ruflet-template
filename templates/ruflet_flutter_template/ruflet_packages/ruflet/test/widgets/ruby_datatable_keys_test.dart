import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' as material;
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:ruflet/ruflet.dart';

RufletBackend _backend(TargetPlatform platform) => RufletBackend(
  pageUri: Uri.parse('inprocess://datatable-keys-test'),
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

Map<String, dynamic> _cell(int id, String text) => {
  '_c': 'DataCell',
  '_i': id,
  'content': {'_c': 'Text', '_i': id + 100, 'value': text},
};

Future<TableBorder?> _pumpTable(
  WidgetTester tester,
  TargetPlatform platform,
  Map<String, dynamic> props,
) async {
  final backend = _backend(platform);
  final control = Control.fromMap({
    '_c': 'DataTable',
    '_i': 1,
    ...props,
    'columns': [
      {
        '_c': 'DataColumn',
        '_i': 2,
        'label': {'_c': 'Text', '_i': 3, 'value': 'Name'},
      },
      {
        '_c': 'DataColumn',
        '_i': 4,
        'label': {'_c': 'Text', '_i': 5, 'value': 'Role'},
      },
    ],
    'rows': [
      {
        '_c': 'DataRow',
        '_i': 10,
        'cells': [_cell(11, 'Ada'), _cell(12, 'Engineer')],
      },
      {
        '_c': 'DataRow',
        '_i': 20,
        'cells': [_cell(21, 'Linus'), _cell(22, 'Maintainer')],
      },
    ],
  }, backend);
  await tester.pumpWidget(_host(backend, ControlWidget(control: control)));
  expect(tester.takeException(), isNull);
  return tester.widget<Table>(find.byType(Table)).border;
}

// Same shape Ruby sends: data_table(horizontal_lines: { color:, width: }).
const _rubyHorizontal = {'color': '#666666', 'width': 2};
const _rubyVertical = {'color': '#777777', 'width': 1};
const _horizontal = BorderSide(color: Color(0xff666666), width: 2);

void main() {
  testWidgets('Material DataTable honors Ruby horizontal_lines', (
    tester,
  ) async {
    final border = await _pumpTable(tester, TargetPlatform.android, {
      'horizontal_lines': _rubyHorizontal,
    });
    expect(border?.horizontalInside, _horizontal);
    expect(border?.verticalInside, BorderSide.none);
    final table = tester.widget<material.DataTable>(
      find.byType(material.DataTable),
    );
    expect(table.border?.horizontalInside, _horizontal);
  });

  testWidgets(
    'Material DataTable combines Ruby horizontal and vertical lines',
    (tester) async {
      final border = await _pumpTable(tester, TargetPlatform.android, {
        'horizontal_lines': _rubyHorizontal,
        'vertical_lines': _rubyVertical,
      });
      expect(border?.horizontalInside, _horizontal);
      expect(
        border?.verticalInside,
        const BorderSide(color: Color(0xff777777), width: 1),
      );
    },
  );

  testWidgets('Cupertino DataTable honors Ruby horizontal_lines', (
    tester,
  ) async {
    final border = await _pumpTable(tester, TargetPlatform.iOS, {
      'horizontal_lines': _rubyHorizontal,
    });
    expect(border?.horizontalInside, _horizontal);
  });

  testWidgets('Cupertino DataTable keeps its native separator by default', (
    tester,
  ) async {
    final border = await _pumpTable(tester, TargetPlatform.iOS, {});
    expect(border?.horizontalInside.width, 0.5);
    expect(
      border?.horizontalInside.color,
      CupertinoColors.separator.resolveFrom(tester.element(find.byType(Table))),
    );
  });
}
