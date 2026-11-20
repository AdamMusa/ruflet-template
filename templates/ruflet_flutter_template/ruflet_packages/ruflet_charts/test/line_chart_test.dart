// ruflet-coverage: LineChart LineChartData LineChartDataPoint
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ruflet_charts/ruflet_charts.dart';

import 'support/harness.dart';

/// A line chart as Ruby serializes `line_chart(data_series: [...], ...)`.
Map<String, dynamic> lineChart(
        {Map<String, dynamic> props = const {},
        Map<String, dynamic> series = const {},
        Map<String, dynamic> point = const {}}) =>
    wire('LineChart', 1, {
      'width': 300,
      'height': 200,
      'min_x': 0,
      'max_x': 4,
      'min_y': 0,
      'max_y': 4,
      'data_series': [
        wire('LineChartData', 2, {
          'color': '#ff0000',
          'points': [
            wire('LineChartDataPoint', 3, {'x': 1, 'y': 1}),
            wire('LineChartDataPoint', 4, {'x': 2, 'y': 3, ...point}),
          ],
          ...series,
        }),
      ],
      ...props,
    });

LineChartData lineData(WidgetTester tester) =>
    tester.widget<LineChart>(find.byType(LineChart)).data;

/// Taps the second point, (2, 3), at the middle top quarter of the chart.
Future<void> tapPoint(WidgetTester tester) async {
  await tester
      .tapAt(tester.getTopLeft(find.byType(LineChart)) + const Offset(150, 50));
  await tester.pumpAndSettle();
}

void main() {
  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    group('LineChart ($platform)', () {
      testWidgets('renders data series and points from the wire',
          (tester) async {
        await mountWire(
            tester,
            platform,
            lineChart(props: {
              'bgcolor': '#fafafa',
              'baseline_x': 1,
              'baseline_y': 2,
              'interactive': false,
              'vertical_grid_lines': {'interval': 1, 'color': '#dddddd'},
            }, series: {
              'stroke_width': 4,
              'curved': true,
              'curve_smoothness': 0.5,
              'rounded_stroke_cap': true,
              'dash_pattern': [4, 2],
              'below_line_bgcolor': '#22ff0000',
              'below_line_cutoff_y': 0.5,
              'point': true,
            }, point: {
              'selected': true,
            }),
            extensions: [Extension()]);

        expect(tester.getSize(find.byType(LineChart)), const Size(300, 200));
        final data = lineData(tester);
        expect(
            (data.minX, data.maxX, data.minY, data.maxY), (0.0, 4.0, 0.0, 4.0));
        expect(data.baselineX, 1);
        expect(data.baselineY, 2);
        expect(data.backgroundColor, const Color(0xFFFAFAFA));
        expect(data.lineTouchData.enabled, isFalse);
        expect(data.gridData.drawVerticalLine, isTrue);
        expect(data.gridData.drawHorizontalLine, isFalse);
        expect(data.gridData.verticalInterval, 1);

        final bar = data.lineBarsData.single;
        expect(bar.spots, const [FlSpot(1, 1), FlSpot(2, 3)]);
        expect(bar.color, const Color(0xFFFF0000));
        expect(bar.barWidth, 4);
        expect(bar.isCurved, isTrue);
        expect(bar.curveSmoothness, 0.5);
        expect(bar.isStrokeCapRound, isTrue);
        expect(bar.dashArray, [4, 2]);
        expect(bar.belowBarData.show, isTrue);
        expect(bar.belowBarData.color, const Color(0x22FF0000));
        expect(bar.belowBarData.applyCutOffY, isTrue);
        expect(bar.belowBarData.cutOffY, 0.5);
        expect(bar.aboveBarData.show, isFalse);
        // `point: true` draws the default dot on every point.
        final dot = bar.dotData.getDotPainter(bar.spots[0], 0, bar, 0);
        expect(dot, isA<FlDotCirclePainter>());
        expect((dot as FlDotCirclePainter).radius, 4);
        // A selected point shows its indicator while not interactive.
        expect(bar.showingIndicators, [1]);
        expect(data.showingTooltipIndicators.single.showingSpots.single.x, 2);
        expect(tester.takeException(), isNull);
      });

      testWidgets('a point overrides the series dot painter', (tester) async {
        await mountWire(
            tester,
            platform,
            lineChart(series: {
              'point': {'_type': 'ChartCirclePoint', 'radius': 3},
            }, point: {
              'point': {
                '_type': 'ChartSquarePoint',
                'size': 9,
                'color': '#00ff00',
              },
            }),
            extensions: [Extension()]);

        final bar = lineData(tester).lineBarsData.single;
        final first = bar.dotData.getDotPainter(bar.spots[0], 0, bar, 0);
        final second = bar.dotData.getDotPainter(bar.spots[1], 0, bar, 1);
        expect((first as FlDotCirclePainter).radius, 3);
        expect(first.color, const Color(0xFFFF0000));
        expect((second as FlDotSquarePainter).size, 9);
        expect(second.color, const Color(0xFF00FF00));
      });

      testWidgets('hidden series are not drawn', (tester) async {
        await mountWire(tester, platform, lineChart(series: {'visible': false}),
            extensions: [Extension()]);
        expect(lineData(tester).lineBarsData, isEmpty);
      });

      testWidgets('tapping a point reaches Ruby only when subscribed',
          (tester) async {
        var mounted = await mountWire(tester, platform, lineChart(),
            extensions: [Extension()]);
        expect(lineData(tester).lineTouchData.touchCallback, isNull);
        await tapPoint(tester);
        expect(mounted.backend.events, isEmpty);

        mounted = await mountWire(
            tester, platform, lineChart(props: {'on_event': true}),
            extensions: [Extension()]);
        await tapPoint(tester);
        final events = mounted.backend.events;
        expect(events.map((e) => (e.id, e.name)).toSet(), {(1, 'event')});
        // The touched spots reach Ruby as plain maps the wire can encode.
        expect(events.last.data, {
          'type': 'tapUp',
          'spots': [
            {'bar_index': 0, 'spot_index': 1},
          ],
        });
        expect(tester.takeException(), isNull);
      });

      for (final tooltip in [null, const {'bgcolor': '#00ff00'}]) {
        testWidgets(
            'touching a point with show_tooltip false paints no tooltip '
            '(chart tooltip: $tooltip)', (tester) async {
          // fl_chart needs one (nullable) item per touched spot; dropping the
          // hidden point's item threw while painting the tooltip.
          await mountWire(
              tester,
              platform,
              lineChart(
                  props: {if (tooltip != null) 'tooltip': tooltip},
                  point: {'show_tooltip': false}),
              extensions: [Extension()]);
          final bar = lineData(tester).lineBarsData.single;
          final items = lineData(tester)
              .lineTouchData
              .touchTooltipData
              .getTooltipItems([
            LineBarSpot(bar, 0, bar.spots[0]),
            LineBarSpot(bar, 0, bar.spots[1]),
          ]);
          expect(items.map((i) => i?.text).toList(), ['1.0', null]);

          final gesture = await tester.startGesture(
              tester.getTopLeft(find.byType(LineChart)) +
                  const Offset(150, 50));
          await tester.pump(const Duration(milliseconds: 50));
          expect(tester.takeException(), isNull);
          await gesture.up();
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        });
      }
    });
  }
}
