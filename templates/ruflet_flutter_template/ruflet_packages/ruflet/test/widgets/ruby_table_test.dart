import 'package:ruflet/ruflet.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' as material;
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

RufletBackend _backend(TargetPlatform platform) => RufletBackend(
      pageUri: Uri.parse('inprocess://table-test'),
      assetsDir: '',
      extensions: [],
      multiView: false,
    )..platform = platform;

Widget _host(RufletBackend backend, Widget child) {
  final body = Align(alignment: Alignment.topLeft, child: child);
  return ChangeNotifierProvider<RufletBackend>.value(
    value: backend,
    child: backend.platform == TargetPlatform.iOS
        ? CupertinoApp(home: CupertinoPageScaffold(child: body))
        : material.MaterialApp(home: material.Scaffold(body: body)),
  );
}

int _nextId = 100;
Map<String, dynamic> _text(String value,
        [Map<String, dynamic> extra = const {}]) =>
    {'_c': 'Text', '_i': ++_nextId, 'value': value, ...extra};
Map<String, dynamic> _row(List<Map<String, dynamic>> cells,
        [Map<String, dynamic> extra = const {}]) =>
    {'_c': 'TableRow', '_i': ++_nextId, 'controls': cells, ...extra};

Future<Control> _pump(WidgetTester tester, RufletBackend backend,
    Map<String, dynamic> props) async {
  final control = Control.fromMap({
    '_c': 'Table',
    '_i': 1,
    'width': 400,
    'rows': [
      _row([_text('A'), _text('B'), _text('C')]),
      _row([_text('D'), _text('E'), _text('F')]),
    ],
    ...props,
  }, backend);
  await tester.pumpWidget(_host(backend, ControlWidget(control: control)));
  expect(tester.takeException(), isNull);
  return control;
}

double _width(WidgetTester tester, String text) =>
    tester.getSize(find.text(text)).width;

void main() {
  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    final name = platform.name;

    testWidgets('$name: default columns share the width equally',
        (tester) async {
      final backend = _backend(platform);
      await _pump(tester, backend, {});
      expect(find.byType(ErrorControl), findsNothing);
      final table = tester.widget<Table>(find.byType(Table));
      expect(table.children, hasLength(2));
      expect(table.border, isNull);
      expect(table.defaultVerticalAlignment, TableCellVerticalAlignment.top);
      expect(tester.getSize(find.byType(Table)).width, 400);
      for (final cell in ['A', 'B', 'C', 'D', 'E', 'F']) {
        expect(_width(tester, cell), closeTo(400 / 3, 0.01), reason: cell);
      }
      // Row-major geometry: B is right of A, D is below A.
      expect(tester.getTopLeft(find.text('B')).dx,
          closeTo(tester.getTopLeft(find.text('A')).dx + 400 / 3, 0.01));
      expect(tester.getTopLeft(find.text('D')).dy,
          greaterThanOrEqualTo(tester.getBottomLeft(find.text('A')).dy));
    });

    testWidgets('$name: fixed column is exact and flex columns split the rest',
        (tester) async {
      final backend = _backend(platform);
      await _pump(tester, backend, {
        'column_widths': {
          '0': {'type': 'fixed', 'value': 80},
          '2': {'type': 'flex', 'value': 2},
        },
      });
      expect(_width(tester, 'A'), 80);
      expect(_width(tester, 'B'), closeTo(320 / 3, 0.01));
      expect(_width(tester, 'C'), closeTo(640 / 3, 0.01));
      expect(_width(tester, 'D'), 80);
    });

    testWidgets('$name: fraction, bare-number and intrinsic widths',
        (tester) async {
      final backend = _backend(platform);
      await _pump(tester, backend, {
        'column_widths': {
          0: {'type': 'fraction', 'value': 0.25},
          '1': 50,
        },
      });
      final table = tester.widget<Table>(find.byType(Table));
      expect(table.columnWidths![0], isA<FractionColumnWidth>());
      expect(table.columnWidths![1], isA<FixedColumnWidth>());
      expect(table.defaultColumnWidth, isA<FlexColumnWidth>());
      expect(_width(tester, 'A'), 100);
      expect(_width(tester, 'B'), 50);
      expect(_width(tester, 'C'), 250);

      await _pump(tester, backend, {
        'column_widths': {
          '0': {'type': 'intrinsic'},
        },
      });
      final intrinsic = tester.widget<Table>(find.byType(Table));
      expect(intrinsic.columnWidths![0], isA<IntrinsicColumnWidth>());
      expect(_width(tester, 'A'), lessThan(400 / 3));
    });

    testWidgets('$name: default_column_width applies to unlisted columns',
        (tester) async {
      final backend = _backend(platform);
      await _pump(tester, backend, {
        'column_widths': {
          '0': {'type': 'flex', 'value': 1},
        },
        'default_column_width': {'type': 'fixed', 'value': 120},
      });
      final table = tester.widget<Table>(find.byType(Table));
      expect(table.defaultColumnWidth, isA<FixedColumnWidth>());
      expect(_width(tester, 'A'), 160);
      expect(_width(tester, 'B'), 120);
      expect(_width(tester, 'C'), 120);
    });

    testWidgets('$name: short rows are padded and hidden rows skipped',
        (tester) async {
      final backend = _backend(platform);
      await _pump(tester, backend, {
        'rows': [
          _row([_text('A'), _text('B')]),
          _row([_text('C')]),
          _row([_text('Hidden')], {'visible': false}),
        ],
      });
      expect(find.byType(ErrorControl), findsNothing);
      final table = tester.widget<Table>(find.byType(Table));
      expect(table.children, hasLength(2));
      expect(table.children.map((r) => r.children.length), [2, 2]);
      expect(find.text('Hidden'), findsNothing);
      expect(_width(tester, 'C'), 200);
    });

    testWidgets('$name: a hidden cell keeps its column', (tester) async {
      final backend = _backend(platform);
      await _pump(tester, backend, {
        'rows': [
          _row([
            _text('A'),
            _text('B', {'visible': false}),
            _text('C')
          ]),
        ],
      });
      expect(find.text('B'), findsNothing);
      expect(tester.getTopLeft(find.text('C')).dx,
          closeTo(tester.getTopLeft(find.text('A')).dx + 800 / 3, 0.01));
    });

    testWidgets('$name: row bgcolor paints a row decoration', (tester) async {
      final backend = _backend(platform);
      await _pump(tester, backend, {
        'rows': [
          _row([_text('A')], {'bgcolor': '#ff0000'}),
          _row([_text('B')]),
        ],
      });
      final table = tester.widget<Table>(find.byType(Table));
      expect((table.children[0].decoration as BoxDecoration).color,
          const Color(0xffff0000));
      expect(table.children[1].decoration, isNull);
    });

    testWidgets('$name: borders are drawn only when border_color is given',
        (tester) async {
      final backend = _backend(platform);
      await _pump(tester, backend, {
        'border_color': '#00ff00',
        'border_width': 2,
        'border_radius': 6,
      });
      final table = tester.widget<Table>(find.byType(Table));
      const side = BorderSide(color: Color(0xff00ff00), width: 2);
      expect(table.border!.top, side);
      expect(table.border!.left, side);
      expect(table.border!.horizontalInside, side);
      expect(table.border!.verticalInside, side);
      expect(table.border!.borderRadius, BorderRadius.circular(6));

      await _pump(
          tester, backend, {'border_color': '#00ff00', 'inner_borders': false});
      final outer = tester.widget<Table>(find.byType(Table)).border!;
      expect(outer.top, const BorderSide(color: Color(0xff00ff00)));
      expect(outer.horizontalInside, BorderSide.none);
      expect(outer.verticalInside, BorderSide.none);

      await _pump(tester, backend, {'border_width': 3, 'inner_borders': true});
      expect(tester.widget<Table>(find.byType(Table)).border, isNull);
    });

    testWidgets('$name: cell_padding insets every cell', (tester) async {
      final backend = _backend(platform);
      await _pump(tester, backend, {
        'cell_padding': 8,
        'column_widths': {
          '0': {'type': 'fixed', 'value': 100},
        },
      });
      expect(_width(tester, 'A'), 84);
      final table = tester.getTopLeft(find.byType(Table));
      expect(tester.getTopLeft(find.text('A')) - table, const Offset(8, 8));
    });

    for (final alignment in [
      'middle',
      'bottom',
      'baseline',
      'fill',
      'intrinsic_height'
    ]) {
      testWidgets('$name: default_vertical_alignment $alignment',
          (tester) async {
        final backend = _backend(platform);
        await _pump(tester, backend, {'default_vertical_alignment': alignment});
        final table = tester.widget<Table>(find.byType(Table));
        expect(table.defaultVerticalAlignment.name.toLowerCase(),
            alignment.replaceAll('_', ''));
        if (alignment == 'baseline') {
          expect(table.textBaseline, TextBaseline.alphabetic);
        }
      });
    }

    testWidgets('$name: rows may come from block children (controls)',
        (tester) async {
      final backend = _backend(platform);
      final control = Control.fromMap({
        '_c': 'Table',
        '_i': 1,
        'controls': [
          _row([_text('X'), _text('Y')])
        ],
      }, backend);
      await tester.pumpWidget(_host(backend,
          SizedBox(width: 200, child: ControlWidget(control: control))));
      expect(tester.takeException(), isNull);
      expect(_width(tester, 'X'), 100);
    });

    testWidgets('$name: empty tables render, non-row children error',
        (tester) async {
      final backend = _backend(platform);
      await _pump(tester, backend, {'rows': <dynamic>[]});
      expect(find.byType(ErrorControl), findsNothing);
      await _pump(tester, backend, {
        'rows': [_row(<Map<String, dynamic>>[])]
      });
      expect(find.byType(ErrorControl), findsNothing);

      await _pump(tester, backend, {
        'rows': [_text('Not a row')]
      });
      expect(find.byType(ErrorControl), findsOneWidget);
      expect(find.textContaining('table_row'), findsOneWidget);
    });
  }
}
