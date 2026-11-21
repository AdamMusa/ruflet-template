// Ruby sends a data item's tooltip as the item's own `tooltip` (a text or a
// map of options), never as Flet's `_internals.tooltip` (still read).
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ruflet_charts/ruflet_charts.dart';

import 'support/harness.dart';

const customTooltip = {
  'text': 'Max',
  'text_style': {'color': '#00ff00', 'size': 13},
};

void main() {
  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    group('data item tooltips ($platform)', () {
      testWidgets('bar rods show the tooltip Ruby sent', (tester) async {
        await mountWire(
            tester,
            platform,
            wire('BarChart', 1, {
              'width': 300,
              'height': 200,
              'groups': [
                wire('BarChartGroup', 2, {
                  'x': 0,
                  'rods': [
                    wire('BarChartRod', 3, {'to_y': 8, 'tooltip': 'Peak'}),
                    wire('BarChartRod', 4,
                        {'to_y': 6, 'tooltip': customTooltip}),
                    wire('BarChartRod', 5, {'to_y': 4}),
                    wire('BarChartRod', 6, {
                      'to_y': 2,
                      'tooltip': 'Hidden',
                      'show_tooltip': false
                    }),
                    wire('BarChartRod', 7, {'to_y': 1, 'show_tooltip': false}),
                    // Flet's Python sends the rod tooltip here.
                    wire('BarChartRod', 8, {
                      'to_y': 5,
                      '_internals': {
                        'tooltip': {'text': 'Legacy'}
                      },
                    }),
                  ],
                }),
              ],
            }),
            extensions: [Extension()]);

        final data = tester.widget<BarChart>(find.byType(BarChart)).data;
        final group = data.barGroups.single;
        BarTooltipItem? item(int rod) => data.barTouchData.touchTooltipData
            .getTooltipItem(group, 0, group.barRods[rod], rod);
        expect(item(0)?.text, 'Peak');
        expect(item(1)?.text, 'Max');
        expect(item(1)?.textStyle.color, const Color(0xFF00FF00));
        expect(item(1)?.textStyle.fontSize, 13);
        expect(item(2)?.text, '4.0', reason: 'no tooltip: the rod value');
        // No chart tooltip: a rod's own text keeps fl_chart's label style.
        expect(item(0)?.textStyle, item(2)?.textStyle);
        expect(item(2)?.textStyle.fontWeight, FontWeight.bold);
        expect(item(3), isNull);
        expect(item(4), isNull, reason: 'show_tooltip: false, no tooltip');
        expect(item(5)?.text, 'Legacy');
      });

      testWidgets('line points show the tooltip Ruby sent', (tester) async {
        await mountWire(
            tester,
            platform,
            wire('LineChart', 1, {
              'width': 300,
              'height': 200,
              'data_series': [
                wire('LineChartData', 2, {
                  'points': [
                    wire('LineChartDataPoint', 3,
                        {'x': 1, 'y': 1, 'tooltip': 'Start'}),
                    wire('LineChartDataPoint', 4,
                        {'x': 2, 'y': 3, 'tooltip': customTooltip}),
                    wire('LineChartDataPoint', 5, {'x': 3, 'y': 2}),
                    wire('LineChartDataPoint', 6,
                        {'x': 4, 'y': 1, 'show_tooltip': false}),
                    wire('LineChartDataPoint', 7, {
                      'x': 5,
                      'y': 2,
                      '_internals': {
                        'tooltip': {'text': 'Legacy'}
                      },
                    }),
                  ],
                }),
              ],
            }),
            extensions: [Extension()]);

        final data = tester.widget<LineChart>(find.byType(LineChart)).data;
        final bar = data.lineBarsData.single;
        final items = data.lineTouchData.touchTooltipData.getTooltipItems([
          for (var i = 0; i < bar.spots.length; i++)
            LineBarSpot(bar, 0, bar.spots[i]),
        ]);
        expect(items.map((i) => i?.text).toList(),
            ['Start', 'Max', '2.0', null, 'Legacy']);
        expect(items[1]?.textStyle.color, const Color(0xFF00FF00));
        // No chart tooltip: a point's own text keeps fl_chart's label style.
        expect(items[0]?.textStyle, items[2]?.textStyle);
        expect(items[2]?.textStyle.fontWeight, FontWeight.bold);
      });

      testWidgets('scatter spots show the tooltip Ruby sent', (tester) async {
        await mountWire(
            tester,
            platform,
            wire('ScatterChart', 1, {
              'width': 300,
              'height': 200,
              'spots': [
                wire(
                    'ScatterChartSpot', 2, {'x': 1, 'y': 2, 'tooltip': 'Here'}),
                wire('ScatterChartSpot', 3, {'x': 2, 'y': 3}),
                wire('ScatterChartSpot', 4, {
                  'x': 3,
                  'y': 1,
                  '_internals': {
                    'tooltip': {'text': 'Legacy'}
                  },
                }),
              ],
            }),
            extensions: [Extension()]);

        final data =
            tester.widget<ScatterChart>(find.byType(ScatterChart)).data;
        final tooltip = data.scatterTouchData.touchTooltipData;
        expect(tooltip.getTooltipItems(data.scatterSpots[0])?.text, 'Here');
        // A spot without a tooltip of its own shows none, as before.
        expect(tooltip.getTooltipItems(data.scatterSpots[1]), isNull);
        expect(tooltip.getTooltipItems(data.scatterSpots[2])?.text, 'Legacy');
      });

      testWidgets('candlestick spots show the tooltip Ruby sent',
          (tester) async {
        await mountWire(
            tester,
            platform,
            wire('CandlestickChart', 1, {
              'width': 300,
              'height': 200,
              'spots': [
                wire('CandlestickChartSpot', 2, {
                  'x': 1,
                  'open': 2,
                  'high': 4,
                  'low': 1,
                  'close': 3,
                  'tooltip': customTooltip,
                }),
              ],
            }),
            extensions: [Extension()]);

        final data =
            tester.widget<CandlestickChart>(find.byType(CandlestickChart)).data;
        final item = data.candlestickTouchData.touchTooltipData.getTooltipItems(
            data.candlestickPainter, data.candlestickSpots.single, 0);
        expect(item?.text, 'Max');
        expect(item?.textStyle?.color, const Color(0xFF00FF00));
      });
    });
  }
}
