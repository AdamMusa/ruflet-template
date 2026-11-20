// DataTable2 mounted from the maps Ruby sends (`Ruflet.data_table2`,
// `data_column2`, `data_row2`, `data_cell`) under both designs: geometry,
// colors and state on the rendered table, and every event reaching Ruby only
// when it subscribed.
//
// ruflet-coverage: DataTable2 DataColumn2 DataRow2
// (DataCell is exercised here too; packages/ruflet owns its declaration.)
import 'package:data_table_2/data_table_2.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart' as material;
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ruflet_datatable2/ruflet_datatable2.dart';

import 'support/harness.dart';

const designs = [TargetPlatform.iOS, TargetPlatform.android];

var _nextTextId = 5000;

Map<String, dynamic> textControl(String value) =>
    {'_c': 'Text', '_i': _nextTextId++, 'value': value};

Map<String, dynamic> column(int id, String label,
        [Map<String, dynamic> props = const {}]) =>
    {'_c': 'DataColumn2', '_i': id, 'label': textControl(label), ...props};

Map<String, dynamic> cell(int id, String value,
        [Map<String, dynamic> props = const {}]) =>
    {'_c': 'DataCell', '_i': id, 'content': textControl(value), ...props};

Map<String, dynamic> row(int id, List<Map<String, dynamic>> cells,
        [Map<String, dynamic> props = const {}]) =>
    {'_c': 'DataRow2', '_i': id, 'cells': cells, ...props};

Map<String, dynamic> table(
        {required List<Map<String, dynamic>> columns,
        required List<Map<String, dynamic>> rows,
        Map<String, dynamic> props = const {}}) =>
    {
      '_c': 'DataTable2',
      '_i': 1,
      'width': 600.0,
      'height': 400.0,
      'horizontal_margin': 12.0,
      'column_spacing': 20.0,
      'columns': columns,
      'rows': rows,
      ...props,
    };

Future<Mounted> mount(WidgetTester tester, TargetPlatform platform,
        Map<String, dynamic> wire) =>
    mountWire(tester, platform, wire, extensions: [Extension()]);

/// Lets a pending single tap resolve past the double-tap window.
Future<void> settleTap(WidgetTester tester) async {
  await tester.pump(kDoubleTapTimeout + const Duration(milliseconds: 50));
  await tester.pumpAndSettle();
}

/// The checkboxes the design renders, heading first.
Finder checkboxes(TargetPlatform platform) => platform == TargetPlatform.iOS
    ? find.byType(CupertinoCheckbox)
    : find.byType(material.Checkbox);

List<bool?> checkboxValues(WidgetTester tester, TargetPlatform platform) =>
    platform == TargetPlatform.iOS
        ? [
            for (final c
                in tester.widgetList<CupertinoCheckbox>(checkboxes(platform)))
              c.value
          ]
        : [
            for (final c
                in tester.widgetList<material.Checkbox>(checkboxes(platform)))
              c.value
          ];

/// The painted background of the table row that holds [text]: Material
/// paints it on the data_table_2 TableRow, Cupertino on the row pane.
Color? rowBackground(
    WidgetTester tester, TargetPlatform platform, String text, int? rowId) {
  if (platform == TargetPlatform.iOS) {
    final pane = find.ancestor(
        of: find.text(text),
        matching: find.byWidgetPredicate((w) =>
            w is Container &&
            w.key is ValueKey<String> &&
            (w.key as ValueKey<String>).value.startsWith('table-pane-')));
    return (tester.widget<Container>(pane.first).decoration as BoxDecoration?)
        ?.color;
  }
  final table = tester.widget<Table>(
      find.ancestor(of: find.text(text), matching: find.byType(Table)).first);
  final tableRow = rowId == null
      ? table.children.first
      : table.children.firstWhere((r) => r.key == ValueKey(rowId));
  return (tableRow.decoration as BoxDecoration?)?.color;
}

/// The opacity [text] is painted with: its color's alpha times every
/// Opacity above it.
double paintedAlpha(WidgetTester tester, String text) {
  final paragraph = tester.renderObject<RenderParagraph>(find.text(text));
  var alpha = paragraph.text.style?.color?.a ?? 1;
  for (final o in tester.widgetList<Opacity>(
      find.ancestor(of: find.text(text), matching: find.byType(Opacity)))) {
    alpha *= o.opacity;
  }
  return alpha;
}

void main() {
  for (final platform in designs) {
    group('$platform', () {
      testWidgets(
          'columns place labels, numeric cells, fixed widths and the sort arrow',
          (tester) async {
        await mount(
            tester,
            platform,
            table(props: {
              'sort_column_index': 3,
              'sort_ascending': true,
              'sort_arrow_icon_color': '#ff00ff',
            }, columns: [
              column(10, 'Name'),
              column(11, 'Note', {'fixed_width': 200.0}),
              column(12, 'Qty'),
              column(13, 'Price', {'numeric': true, 'on_sort': true}),
            ], rows: [
              row(20, [
                cell(30, 'Ada'),
                cell(31, 'first'),
                cell(32, 'two'),
                cell(33, '7'),
              ]),
            ]));
        expect(tester.takeException(), isNull);
        for (final label in ['Name', 'Note', 'Qty', 'Price', 'Ada', '7']) {
          expect(find.text(label), findsOneWidget, reason: label);
        }
        // horizontal_margin before the first column, column_spacing / 2
        // inside each later one.
        expect(tester.getTopLeft(find.text('Ada')).dx, closeTo(12, .5));
        expect(tester.getTopLeft(find.text('Name')).dx, closeTo(12, .5));
        final noteStart = tester.getTopLeft(find.text('first')).dx - 10;
        expect(tester.getTopLeft(find.text('Note')).dx - 10,
            closeTo(noteStart, .5));
        // fixed_width is the column's exact width.
        expect(tester.getTopLeft(find.text('two')).dx - 10 - noteStart,
            closeTo(200, .5));
        // A numeric column aligns its cells to the end margin.
        expect(tester.getTopRight(find.text('7')).dx, closeTo(600 - 12, .5));
        // The sorted column shows one arrow in sort_arrow_icon_color.
        final arrowIcon = platform == TargetPlatform.iOS
            ? CupertinoIcons.arrow_up
            : material.Icons.arrow_upward;
        final arrow = tester.widget<Icon>(find.byIcon(arrowIcon));
        expect(arrow.color, const Color(0xffff00ff));
        expect(tester.getCenter(find.byIcon(arrowIcon)).dx,
            greaterThan(tester.getTopRight(find.text('Qty')).dx));
        expect(tester.getCenter(find.byIcon(arrowIcon)).dy,
            closeTo(tester.getCenter(find.text('Price')).dy, 2));
      });

      testWidgets('the sort arrow animates for sort_arrow_animation_duration',
          (tester) async {
        // Regression: Material defaulted to 150 microseconds, not the 150
        // milliseconds data_table_2 and the Cupertino renderer use, so the
        // arrow flipped instantly when Ruby left the duration out.
        Duration arrowDuration() => platform == TargetPlatform.iOS
            ? tester
                .widget<AnimatedRotation>(find.byType(AnimatedRotation))
                .duration
            : tester
                .widget<material.AnimatedDefaultTextStyle>(find
                    .ancestor(
                        of: find.text('A'),
                        matching:
                            find.byType(material.AnimatedDefaultTextStyle))
                    .first)
                .duration;
        for (final (wire, expected) in [
          (<String, dynamic>{}, const Duration(milliseconds: 150)),
          (
            <String, dynamic>{'sort_arrow_animation_duration': 400},
            const Duration(milliseconds: 400)
          ),
        ]) {
          await mount(
              tester,
              platform,
              table(props: {
                'sort_column_index': 0,
                'sort_ascending': true,
                ...wire,
              }, columns: [
                column(10, 'A', {'on_sort': true}),
              ], rows: [
                row(20, [cell(30, 'a')]),
              ]));
          expect(arrowDuration(), expected, reason: '$wire');
        }
      });

      testWidgets('rows take heading, data and specific heights and colors',
          (tester) async {
        await mount(
            tester,
            platform,
            table(props: {
              'heading_row_height': 40.0,
              'data_row_height': 30.0,
              'heading_row_color': '#0000ff',
              'data_row_color': {'selected': '#ff0000', 'default': '#00ff00'},
            }, columns: [
              column(10, 'Name'),
              column(11, 'Note'),
            ], rows: [
              row(20, [cell(30, 'Ada'), cell(31, 'a')], {'selected': true}),
              row(21, [cell(32, 'Bob'), cell(33, 'b')],
                  {'specific_row_height': 50.0, 'color': '#ffff00'}),
              row(22, [cell(34, 'Cy'), cell(35, 'c')]),
            ]));
        expect(tester.takeException(), isNull);
        double centerY(String text) => tester.getCenter(find.text(text)).dy;
        expect(centerY('Name'), closeTo(20, .5),
            reason: 'heading_row_height 40');
        expect(centerY('Bob') - centerY('Ada'), closeTo(15 + 25, .5),
            reason: 'data_row_height 30, then specific_row_height 50');
        expect(centerY('Cy') - centerY('Bob'), closeTo(25 + 15, .5));
        expect(rowBackground(tester, platform, 'Name', null),
            const Color(0xff0000ff));
        expect(
            rowBackground(tester, platform, 'Ada', 20), const Color(0xffff0000),
            reason: 'selected row takes data_row_color[selected]');
        expect(
            rowBackground(tester, platform, 'Bob', 21), const Color(0xffffff00),
            reason: 'a row color overrides data_row_color');
        expect(
            rowBackground(tester, platform, 'Cy', 22), const Color(0xff00ff00));
      });

      testWidgets(
          'rows start right under the heading when they do not fill the '
          'table', (tester) async {
        // Regression: the Cupertino body centered short tables vertically,
        // leaving a gap between the heading and the first row.
        for (final fixedColumns in [0, 1]) {
          await mount(
              tester,
              platform,
              table(props: {
                'heading_row_height': 40.0,
                'data_row_height': 30.0,
                'fixed_left_columns': fixedColumns,
              }, columns: [
                column(10, 'Name'),
                column(11, 'Note'),
              ], rows: [
                row(20, [cell(30, 'Ada'), cell(31, 'a')]),
                row(21, [cell(32, 'Bob'), cell(33, 'b')],
                    {'specific_row_height': 50.0}),
                row(22, [cell(34, 'Cy'), cell(35, 'c')]),
              ]));
          expect(tester.getCenter(find.text('Ada')).dy, closeTo(40 + 15, .5));
          expect(tester.getCenter(find.text('Bob')).dy, closeTo(70 + 25, .5));
          expect(tester.getCenter(find.text('Cy')).dy, closeTo(120 + 15, .5));
          expect(tester.getCenter(find.text('c')).dy, closeTo(120 + 15, .5));
        }
      });

      testWidgets('cells render placeholder dimming and the edit icon',
          (tester) async {
        await mount(
            tester,
            platform,
            table(columns: [
              column(10, 'Name'),
              column(11, 'Status'),
            ], rows: [
              row(20, [
                cell(30, 'Ada'),
                cell(31, 'tbd', {'placeholder': true, 'show_edit_icon': true}),
              ]),
              row(21, [cell(32, 'Bob'), cell(33, 'done')]),
            ]));
        expect(tester.takeException(), isNull);
        expect(paintedAlpha(tester, 'tbd') / paintedAlpha(tester, 'done'),
            closeTo(.6, .01));
        final editIcon = platform == TargetPlatform.iOS
            ? CupertinoIcons.pencil
            : material.Icons.edit;
        expect(find.byIcon(editIcon), findsOneWidget);
        expect(tester.getCenter(find.byIcon(editIcon)).dy,
            closeTo(tester.getCenter(find.text('tbd')).dy, 1));
        expect(tester.getCenter(find.byIcon(editIcon)).dx,
            greaterThan(tester.getTopRight(find.text('tbd')).dx));
      });

      testWidgets('column size takes the names Ruby sends', (tester) async {
        // Regression: Ruby sends `size: :medium` as "medium"; only "m" was
        // read, so medium and large columns rendered as small ones.
        await mount(
            tester,
            platform,
            table(columns: [
              column(10, 'First'),
              column(11, 'Mid', {'size': 'medium'}),
              column(12, 'Sm', {'size': 'small'}),
              column(13, 'Lg', {'size': 'large'}),
              column(14, 'Last'),
            ], rows: [
              row(20, [
                for (var i = 0; i < 5; i++) cell(30 + i, 'c$i'),
              ]),
            ]));
        double left(String text) => tester.getTopLeft(find.text(text)).dx;
        final mid = left('Sm') - left('Mid');
        final small = left('Lg') - left('Sm');
        final large = left('Last') - left('Lg');
        expect(mid / small, closeTo(1 / .67, .01));
        expect(large / small, closeTo(1.2 / .67, .01));
        if (platform == TargetPlatform.android) {
          final columns =
              tester.widget<DataTable2>(find.byType(DataTable2)).columns;
          expect([
            for (final c in columns) (c as DataColumn2).size
          ], [
            ColumnSize.S,
            ColumnSize.M,
            ColumnSize.S,
            ColumnSize.L,
            ColumnSize.S,
          ]);
        }
      });

      testWidgets('a table without rows shows the empty control',
          (tester) async {
        await mount(
            tester,
            platform,
            table(
                props: {'empty': textControl('No records')},
                columns: [column(10, 'Name')],
                rows: []));
        expect(tester.takeException(), isNull);
        expect(find.text('Name'), findsOneWidget);
        expect(find.text('No records'), findsOneWidget);
        expect(tester.getTopLeft(find.text('No records')).dy,
            greaterThanOrEqualTo(tester.getBottomLeft(find.text('Name')).dy));
      });

      testWidgets(
          'the empty control gets the whole height under the heading, as '
          'data_table_2 gives it', (tester) async {
        // Regression: once Cupertino rows started right under the heading,
        // `empty` was sized to its content at the top of the body, so an
        // `empty` that centers itself was centered on Android only.
        // With `fixed_top_rows: 0` the heading scrolls with the body, and
        // `empty` gets only the height left under it.
        for (final props in [
          <String, dynamic>{},
          <String, dynamic>{'bottom_margin': 20.0},
          <String, dynamic>{'fixed_top_rows': 0},
          <String, dynamic>{'fixed_top_rows': 0, 'bottom_margin': 20.0},
        ]) {
          await mount(
              tester,
              platform,
              table(
                  props: {...props, 'empty': textControl('No records')},
                  columns: [column(10, 'Name')],
                  rows: []));
          expect(tester.takeException(), isNull);
          // heading_row_height 56, table height 400.
          final box = tester.getRect(find.text('No records'));
          expect(box.top, closeTo(56, .5), reason: '$props');
          expect(box.bottom, closeTo(400, .5), reason: '$props');
          // Nothing is added under it, so the body does not scroll.
          await tester.drag(find.text('No records'), const Offset(0, -100));
          await tester.pumpAndSettle();
          expect(tester.getRect(find.text('No records')).top, closeTo(56, .5),
              reason: '$props');

          await mount(
              tester,
              platform,
              table(props: {
                ...props,
                'empty': {
                  '_c': 'Container',
                  '_i': 90,
                  'alignment': {'x': 0, 'y': 0},
                  'content': textControl('Centered'),
                },
              }, columns: [
                column(10, 'Name')
              ], rows: []));
          expect(tester.takeException(), isNull);
          final center = tester.getCenter(find.text('Centered'));
          expect(center.dy, closeTo((56 + 400) / 2, .5), reason: '$props');
          expect(center.dx, closeTo(600 / 2, .5), reason: '$props');
        }
      });

      testWidgets('a table with rows does not show the empty control',
          (tester) async {
        for (final props in [
          <String, dynamic>{},
          <String, dynamic>{'bottom_margin': 20.0},
        ]) {
          await mount(
              tester,
              platform,
              table(props: {
                ...props,
                'empty': textControl('No records')
              }, columns: [
                column(10, 'Name')
              ], rows: [
                row(20, [cell(30, 'Ada')])
              ]));
          expect(tester.takeException(), isNull);
          expect(find.text('Ada'), findsOneWidget, reason: '$props');
          expect(find.text('No records'), findsNothing, reason: '$props');
        }
      });

      // data_table_2 needs a bounded height (it reports a layout error in a
      // Column), so only the Cupertino renderer lays out a table without one.
      if (platform == TargetPlatform.iOS) {
        testWidgets(
            'a table without a height sizes the empty control to its content',
            (tester) async {
          await mount(tester, platform, {
            '_c': 'Column',
            '_i': 2,
            'controls': [
              {
                ...table(
                    props: {'empty': textControl('No records')},
                    columns: [column(10, 'Name')],
                    rows: []),
              }..remove('height'),
            ],
          });
          expect(tester.takeException(), isNull);
          final box = tester.getRect(find.text('No records'));
          expect(box.top, closeTo(56, .5));
          expect(
              box.height, closeTo(tester.getSize(find.text('Name')).height, .5),
              reason: 'one line of text, not the height of a bounded table');
        });
      }

      testWidgets(
          'the checkbox column reflects selection and sends select_all and '
          'select_change', (tester) async {
        final m = await mount(
            tester,
            platform,
            table(props: {
              'show_checkbox_column': true,
              'on_select_all': true,
            }, columns: [
              column(10, 'Name'),
            ], rows: [
              row(20, [cell(30, 'Ada')],
                  {'selected': false, 'on_select_change': true}),
              row(21, [cell(31, 'Bob')],
                  {'selected': true, 'on_select_change': true}),
            ]));
        expect(tester.takeException(), isNull);
        expect(checkboxes(platform), findsNWidgets(3));
        expect(checkboxValues(tester, platform), [null, false, true],
            reason: 'heading is mixed while some rows are selected');
        await tester.tap(checkboxes(platform).at(0));
        await tester.pumpAndSettle();
        expect(m.backend.sent.single, [1, 'select_all', true]);
        await tester.tap(checkboxes(platform).at(1));
        await tester.pumpAndSettle();
        expect(m.backend.sent.last, [20, 'select_change', true]);
        await tester.tap(checkboxes(platform).at(2));
        await tester.pumpAndSettle();
        expect(m.backend.sent.last, [21, 'select_change', false]);
        expect(m.backend.events, hasLength(3));
      });

      testWidgets(
          'without on_select_all the heading checkbox selects each '
          'subscribed row', (tester) async {
        final m = await mount(
            tester,
            platform,
            table(props: {
              'show_checkbox_column': true,
            }, columns: [
              column(10, 'Name'),
            ], rows: [
              row(20, [cell(30, 'Ada')], {'on_select_change': true}),
              row(21, [cell(31, 'Bob')], {'on_select_change': true}),
              row(22, [cell(32, 'Cy')]),
            ]));
        expect(checkboxes(platform), findsNWidgets(4));
        await tester.tap(checkboxes(platform).first);
        await tester.pumpAndSettle();
        expect(m.backend.sent, [
          [20, 'select_change', true],
          [21, 'select_change', true],
        ]);

        await mount(
            tester,
            platform,
            table(props: {
              'show_checkbox_column': true,
              'show_heading_checkbox': false,
            }, columns: [
              column(10, 'Name'),
            ], rows: [
              row(20, [cell(30, 'Ada')], {'on_select_change': true}),
              row(21, [cell(31, 'Bob')], {'on_select_change': true}),
            ]));
        expect(checkboxes(platform), findsNWidgets(2));
      });

      testWidgets('tapping a row without on_tap toggles its selection',
          (tester) async {
        final m = await mount(
            tester,
            platform,
            table(columns: [
              column(10, 'Name'),
            ], rows: [
              row(20, [cell(30, 'Ada')],
                  {'selected': false, 'on_select_change': true}),
              row(21, [cell(31, 'Bob')],
                  {'selected': true, 'on_select_change': true}),
            ]));
        await tester.tap(find.text('Ada'));
        await settleTap(tester);
        await tester.tap(find.text('Bob'));
        await settleTap(tester);
        expect(m.backend.sent, [
          [20, 'select_change', true],
          [21, 'select_change', false],
        ]);
      });

      testWidgets('column on_sort sends the column index and new direction',
          (tester) async {
        Map<String, dynamic> wire(bool ascending) => table(props: {
              'sort_column_index': 0,
              'sort_ascending': ascending,
            }, columns: [
              column(10, 'A', {'on_sort': true}),
              column(11, 'B', {'on_sort': true}),
              column(12, 'C'),
            ], rows: [
              row(20, [cell(30, 'a'), cell(31, 'b'), cell(32, 'c')]),
            ]);
        var m = await mount(tester, platform, wire(true));
        await tester.tap(find.text('A'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('B'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('C'));
        await tester.pumpAndSettle();
        expect(m.backend.sent, [
          [
            10,
            'sort',
            {'ci': 0, 'asc': false}
          ],
          [
            11,
            'sort',
            {'ci': 1, 'asc': true}
          ],
        ]);

        m = await mount(tester, platform, wire(false));
        await tester.tap(find.text('A'));
        await tester.pumpAndSettle();
        expect(m.backend.sent.single, [
          10,
          'sort',
          {'ci': 0, 'asc': true}
        ]);
      });

      testWidgets('row gestures reach Ruby only when subscribed',
          (tester) async {
        final m = await mount(
            tester,
            platform,
            table(columns: [
              column(10, 'Name'),
            ], rows: [
              row(20, [
                cell(30, 'Ada')
              ], {
                'on_tap': true,
                'on_double_tap': true,
                'on_long_press': true,
                'on_secondary_tap': true,
                'on_secondary_tap_down': true,
              }),
              row(21, [cell(31, 'Bob')]),
            ]));
        await tester.tap(find.text('Ada'));
        await settleTap(tester);
        expect(m.backend.eventsOf(20), ['tap']);

        await tester.tap(find.text('Ada'));
        await tester.pump(const Duration(milliseconds: 60));
        await tester.tap(find.text('Ada'));
        await settleTap(tester);
        expect(m.backend.eventsOf(20), ['tap', 'double_tap']);

        await tester.longPress(find.text('Ada'));
        await tester.pumpAndSettle();
        expect(m.backend.eventsOf(20), ['tap', 'double_tap', 'long_press']);

        final at = tester.getCenter(find.text('Ada'));
        await tester.tapAt(at, buttons: kSecondaryMouseButton);
        await settleTap(tester);
        expect(m.backend.eventsOf(20).skip(3),
            ['secondary_tap_down', 'secondary_tap']);
        final down = m.backend.events
            .firstWhere((e) => e.name == 'secondary_tap_down')
            .data as Map;
        expect(down.keys, containsAll(['k', 'l', 'g']));
        expect(down['g'], {'x': at.dx, 'y': at.dy});

        final before = m.backend.events.length;
        await tester.tap(find.text('Bob'));
        await settleTap(tester);
        await tester.longPress(find.text('Bob'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Bob'), buttons: kSecondaryMouseButton);
        await settleTap(tester);
        expect(m.backend.events, hasLength(before),
            reason: 'a row without subscriptions sends nothing');
      });

      testWidgets('cell gestures reach the cell, then its row', (tester) async {
        final m = await mount(
            tester,
            platform,
            table(columns: [
              column(10, 'Name'),
            ], rows: [
              row(20, [
                cell(30, 'Ada', {
                  'on_tap': true,
                  'on_double_tap': true,
                  'on_long_press': true,
                  'on_tap_down': true,
                }),
              ], {
                'on_tap': true,
                'on_double_tap': true,
                'on_long_press': true,
              }),
              row(21, [
                cell(31, 'Bob', {'on_tap_cancel': true})
              ]),
              row(22, [cell(32, 'Cy')]),
            ]));
        final at = tester.getCenter(find.text('Ada'));
        await tester.tapAt(at);
        await settleTap(tester);
        expect([for (final e in m.backend.events) (e.id, e.name)],
            [(30, 'tap_down'), (30, 'tap'), (20, 'tap')]);
        final down = m.backend.events.first.data as Map;
        expect(down['g'], {'x': at.dx, 'y': at.dy});
        expect(down.keys, containsAll(['k', 'l', 'g']));

        m.backend.events.clear();
        await tester.tapAt(at);
        await tester.pump(const Duration(milliseconds: 60));
        await tester.tapAt(at);
        await settleTap(tester);
        expect([
          for (final e in m.backend.events)
            if (e.name != 'tap_down') (e.id, e.name)
        ], [
          (30, 'double_tap'),
          (20, 'double_tap')
        ]);

        m.backend.events.clear();
        await tester.longPressAt(at);
        await tester.pumpAndSettle();
        expect([
          for (final e in m.backend.events)
            if (e.name != 'tap_down') (e.id, e.name)
        ], [
          (30, 'long_press'),
          (20, 'long_press')
        ]);

        // A press that turns into a drag cancels the cell's tap.
        m.backend.events.clear();
        final gesture =
            await tester.startGesture(tester.getCenter(find.text('Bob')));
        await tester.pump(const Duration(milliseconds: 150));
        await gesture.moveBy(const Offset(0, 80));
        await tester.pump();
        await gesture.up();
        await tester.pumpAndSettle();
        expect(m.backend.sent, [
          [31, 'tap_cancel', null]
        ]);

        m.backend.events.clear();
        await tester.tap(find.text('Cy'));
        await settleTap(tester);
        await tester.longPress(find.text('Cy'));
        await tester.pumpAndSettle();
        expect(m.backend.events, isEmpty);
      });

      testWidgets(
          'fixed rows and columns stay put and take the fixed colors while '
          'the body scrolls', (tester) async {
        await mount(
            tester,
            platform,
            table(props: {
              'height': 200.0,
              'min_width': 900.0,
              'fixed_top_rows': 1,
              'fixed_left_columns': 1,
              'fixed_columns_color': '#00ffff',
              'fixed_corner_color': '#ff8800',
            }, columns: [
              column(10, 'Name'),
              column(11, 'Note'),
              column(12, 'Qty'),
            ], rows: [
              for (var i = 0; i < 8; i++)
                row(20 + i, [
                  cell(40 + i * 3, 'Row $i'),
                  cell(41 + i * 3, 'Note $i'),
                  cell(42 + i * 3, 'Qty $i'),
                ]),
            ]));
        expect(tester.takeException(), isNull);
        expect(rowBackground(tester, platform, 'Name', null),
            const Color(0xffff8800));
        expect(rowBackground(tester, platform, 'Row 0', 20),
            const Color(0xff00ffff));
        expect(rowBackground(tester, platform, 'Note 0', 20),
            isNot(const Color(0xff00ffff)));

        final heading = tester.getTopLeft(find.text('Note'));
        final firstColumnX = tester.getTopLeft(find.text('Row 0')).dx;
        final noteX = tester.getTopLeft(find.text('Note 0')).dx;
        await tester.drag(find.text('Note 0'), const Offset(-150, 0));
        await tester.pumpAndSettle();
        expect(tester.getTopLeft(find.text('Row 0')).dx, firstColumnX);
        expect(tester.getTopLeft(find.text('Note 0')).dx, lessThan(noteX));
        expect(tester.getTopLeft(find.text('Note')).dx,
            closeTo(tester.getTopLeft(find.text('Note 0')).dx, .5),
            reason: 'the fixed heading scrolls with the body horizontally');

        final rowY = tester.getTopLeft(find.text('Row 1')).dy;
        await tester.drag(find.text('Qty 2'), const Offset(0, -100));
        await tester.pumpAndSettle();
        expect(tester.getTopLeft(find.text('Note')).dy, heading.dy);
        expect(tester.getTopLeft(find.text('Row 1')).dy, lessThan(rowY));
        expect(tester.getTopLeft(find.text('Row 1')).dy,
            closeTo(tester.getTopLeft(find.text('Note 1')).dy, .5),
            reason: 'the fixed column scrolls with the body vertically');
      });
    });
  }
}
