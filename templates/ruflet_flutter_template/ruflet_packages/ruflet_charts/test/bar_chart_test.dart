// ruflet-coverage: BarChart BarChartGroup BarChartRod BarChartRodStackItem
// ruflet-coverage: ChartAxis ChartAxisLabel
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ruflet_charts/ruflet_charts.dart';

import 'support/harness.dart';

/// A bar chart as Ruby serializes `bar_chart(groups: [...], ...)`.
Map<String, dynamic> barChart(
        {Map<String, dynamic> props = const {},
        List<Map<String, dynamic>>? groups}) =>
    wire('BarChart', 1, {
      'width': 300,
      'height': 200,
      'min_y': 0,
      'max_y': 10,
      'groups': groups ??
          [
            wire('BarChartGroup', 2, {
              'x': 0,
              'rods': [
                wire('BarChartRod', 3,
                    {'from_y': 0, 'to_y': 8, 'width': 24, 'color': '#ff0000'}),
              ],
            }),
          ],
      ...props,
    });

BarChartData barData(WidgetTester tester) =>
    tester.widget<BarChart>(find.byType(BarChart)).data;

/// Taps [offset] inside the chart's own box.
Future<void> tapChart(WidgetTester tester, Offset offset) async {
  await tester.tapAt(tester.getTopLeft(find.byType(BarChart)) + offset);
  await tester.pumpAndSettle();
}

void main() {
  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    group('BarChart ($platform)', () {
      testWidgets('renders groups, rods and stack items from the wire',
          (tester) async {
        await mountWire(
            tester,
            platform,
            barChart(props: {
              'bgcolor': '#102030',
              'baseline_y': 1,
              'group_alignment': 'space_around',
              'interactive': false,
            }, groups: [
              wire('BarChartGroup', 2, {
                'x': 4,
                'spacing': 6,
                'group_vertically': true,
                'rods': [
                  wire('BarChartRod', 3, {
                    'from_y': 1,
                    'to_y': 9,
                    'width': 18,
                    'color': '#00ff00',
                    'border_radius': 3,
                    'border_side': {'width': 2, 'color': '#123456'},
                    'bg_from_y': 0,
                    'bg_to_y': 10,
                    'bgcolor': '#eeeeee',
                    'selected': true,
                    'stack_items': [
                      wire('BarChartRodStackItem', 4,
                          {'from_y': 1, 'to_y': 4, 'color': '#0000ff'}),
                      wire('BarChartRodStackItem', 5,
                          {'from_y': 4, 'to_y': 9, 'color': '#ffff00'}),
                    ],
                  }),
                  wire('BarChartRod', 6, {'to_y': 5}),
                ],
              }),
            ]),
            extensions: [Extension()]);

        expect(tester.getSize(find.byType(BarChart)), const Size(300, 200));
        final data = barData(tester);
        expect(data.minY, 0);
        expect(data.maxY, 10);
        expect(data.baselineY, 1);
        expect(data.backgroundColor, const Color(0xFF102030));
        expect(data.alignment, BarChartAlignment.spaceAround);
        expect(data.barTouchData.enabled, isFalse);

        final group = data.barGroups.single;
        expect(group.x, 4);
        expect(group.barsSpace, 6);
        expect(group.groupVertically, isTrue);
        // A selected rod shows its tooltip while the chart is not
        // interactive.
        expect(group.showingTooltipIndicators, [0]);

        final rod = group.barRods.first;
        expect(rod.fromY, 1);
        expect(rod.toY, 9);
        expect(rod.width, 18);
        expect(rod.color, const Color(0xFF00FF00));
        expect(rod.borderRadius, BorderRadius.circular(3));
        expect(rod.borderSide.width, 2);
        expect(rod.borderSide.color, const Color(0xFF123456));
        expect(rod.backDrawRodData.show, isTrue);
        expect(rod.backDrawRodData.fromY, 0);
        expect(rod.backDrawRodData.toY, 10);
        expect(rod.backDrawRodData.color, const Color(0xFFEEEEEE));
        expect(
            rod.rodStackItems.map((s) => (s.fromY, s.toY, s.color)).toList(), [
          (1.0, 4.0, const Color(0xFF0000FF)),
          (4.0, 9.0, const Color(0xFFFFFF00)),
        ]);

        final plain = group.barRods.last;
        expect(plain.toY, 5);
        expect(plain.backDrawRodData.show, isFalse);
        expect(plain.rodStackItems, isEmpty);
        expect(tester.takeException(), isNull);
      });

      testWidgets('spaces groups by the group_spacing Ruby sends',
          (tester) async {
        // Ruflet.bar_chart(group_spacing: 12, group_alignment: :start, ...)
        await mountWire(tester, platform,
            barChart(props: {'group_spacing': 12, 'group_alignment': 'start'}),
            extensions: [Extension()]);
        expect(barData(tester).groupsSpace, 12);
        expect(barData(tester).alignment, BarChartAlignment.start);

        // The name this renderer read before stays a fallback.
        await mountWire(tester, platform, barChart(props: {'spacing': 9}),
            extensions: [Extension()]);
        expect(barData(tester).groupsSpace, 9);
      });

      testWidgets('renders stack items Ruby markup sends as rod_stack_items',
          (tester) async {
        // ruflet_rails routes <bar-chart-rod-stack-item> into the rod's
        // `rod_stack_items`.
        await mountWire(
            tester,
            platform,
            barChart(groups: [
              wire('BarChartGroup', 2, {
                'x': 0,
                'rods': [
                  wire('BarChartRod', 3, {
                    'to_y': 6,
                    'rod_stack_items': [
                      wire('BarChartRodStackItem', 4,
                          {'from_y': 0, 'to_y': 2, 'color': '#0000ff'}),
                      wire('BarChartRodStackItem', 5,
                          {'from_y': 2, 'to_y': 6, 'color': '#ffff00'}),
                    ],
                  }),
                ],
              }),
            ]),
            extensions: [Extension()]);

        final rod = barData(tester).barGroups.single.barRods.single;
        expect(
            rod.rodStackItems.map((s) => (s.fromY, s.toY, s.color)).toList(), [
          (0.0, 2.0, const Color(0xFF0000FF)),
          (2.0, 6.0, const Color(0xFFFFFF00)),
        ]);
      });

      testWidgets('renders axes, axis labels, grid lines and border',
          (tester) async {
        await mountWire(
            tester,
            platform,
            barChart(props: {
              'left_axis': wire('ChartAxis', 10, {
                'title': wire('Text', 11, {'value': 'Revenue'}),
                'title_size': 20,
                'label_size': 30,
                'label_spacing': 5,
                'show_min': false,
              }),
              'bottom_axis': wire('ChartAxis', 12, {
                'label_size': 24,
                'labels': [
                  wire('ChartAxisLabel', 13, {'value': 0, 'label': 'Q1'}),
                  wire('ChartAxisLabel', 14, {
                    'value': 1,
                    'label': wire('Text', 15, {'value': 'Q2'}),
                  }),
                ],
              }),
              'horizontal_grid_lines': {
                'interval': 2,
                'color': '#cccccc',
                'width': 1,
              },
              'border': {
                'bottom': {'width': 2, 'color': '#333333'},
              },
            }, groups: [
              for (final x in [0, 1])
                wire('BarChartGroup', 20 + x, {
                  'x': x,
                  'rods': [
                    wire('BarChartRod', 30 + x, {'to_y': 4}),
                  ],
                }),
            ]),
            extensions: [Extension()]);

        final titles = barData(tester).titlesData;
        expect(titles.show, isTrue);
        expect(titles.leftTitles.axisNameSize, 20);
        expect(titles.leftTitles.sideTitles.showTitles, isTrue);
        expect(titles.leftTitles.sideTitles.reservedSize, 30);
        expect(titles.leftTitles.sideTitles.interval, 5);
        expect(titles.leftTitles.sideTitles.minIncluded, isFalse);
        expect(titles.leftTitles.sideTitles.maxIncluded, isTrue);
        expect(titles.bottomTitles.sideTitles.reservedSize, 24);
        // Axes Ruby left out draw no labels.
        expect(titles.topTitles.sideTitles.showTitles, isFalse);
        expect(titles.rightTitles.sideTitles.showTitles, isFalse);
        expect(find.text('Revenue'), findsOneWidget);
        expect(find.text('Q1'), findsOneWidget);
        expect(find.text('Q2'), findsOneWidget);

        final grid = barData(tester).gridData;
        expect(grid.show, isTrue);
        expect(grid.drawHorizontalLine, isTrue);
        expect(grid.drawVerticalLine, isFalse);
        expect(grid.horizontalInterval, 2);
        final line = grid.getDrawingHorizontalLine(2);
        expect(line.color, const Color(0xFFCCCCCC));
        expect(line.strokeWidth, 1);

        final border = barData(tester).borderData;
        expect(border.show, isTrue);
        expect(border.border.bottom.width, 2);
        expect(border.border.bottom.color, const Color(0xFF333333));
        expect(border.border.top, BorderSide.none);
        expect(tester.takeException(), isNull);
      });

      testWidgets('tapping a rod reaches Ruby only when subscribed',
          (tester) async {
        var mounted = await mountWire(tester, platform, barChart(),
            extensions: [Extension()]);
        expect(barData(tester).barTouchData.touchCallback, isNull);
        await tapChart(tester, const Offset(150, 150));
        expect(mounted.backend.events, isEmpty);

        mounted = await mountWire(
            tester, platform, barChart(props: {'on_event': true}),
            extensions: [Extension()]);
        await tapChart(tester, const Offset(150, 150));
        final events = mounted.backend.events;
        expect(events.map((e) => (e.id, e.name)).toSet(), {(1, 'event')});
        expect(events.last.data, {
          'type': 'tapUp',
          'group_index': 0,
          'rod_index': 0,
          'stack_item_index': -1,
        });
        expect(tester.takeException(), isNull);
      });
    });
  }
}
