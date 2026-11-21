// ruflet-coverage: CandlestickChart CandlestickChartSpot
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ruflet_charts/ruflet_charts.dart';

import 'support/harness.dart';

/// A candlestick chart as Ruby serializes
/// `candlestick_chart(spots: [...], ...)`: one candle in the middle.
Map<String, dynamic> candlestickChart(
        {Map<String, dynamic> props = const {},
        Map<String, dynamic> spot = const {}}) =>
    wire('CandlestickChart', 1, {
      'width': 300,
      'height': 200,
      'min_x': 0,
      'max_x': 2,
      'min_y': 0,
      'max_y': 5,
      'spots': [
        wire('CandlestickChartSpot', 2,
            {'x': 1, 'open': 2, 'high': 4, 'low': 1, 'close': 3, ...spot}),
        wire('CandlestickChartSpot', 3,
            {'x': 1.8, 'open': 3, 'high': 3.5, 'low': 0.5, 'close': 1}),
      ],
      ...props,
    });

CandlestickChartData candleData(WidgetTester tester) =>
    tester.widget<CandlestickChart>(find.byType(CandlestickChart)).data;

Future<void> tapFirstCandle(WidgetTester tester) async {
  await tester.tapAt(tester.getTopLeft(find.byType(CandlestickChart)) +
      const Offset(150, 100));
  await tester.pumpAndSettle();
}

void main() {
  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    group('CandlestickChart ($platform)', () {
      testWidgets('renders candles from the wire', (tester) async {
        await mountWire(
            tester,
            platform,
            candlestickChart(props: {
              'bgcolor': '#f5f5f5',
              'baseline_y': 2.5,
              'touch_spot_threshold': 12,
            }, spot: {
              'selected': true,
            }),
            extensions: [Extension()]);

        expect(tester.getSize(find.byType(CandlestickChart)),
            const Size(300, 200));
        final data = candleData(tester);
        expect(
            (data.minX, data.maxX, data.minY, data.maxY), (0.0, 2.0, 0.0, 5.0));
        expect(data.backgroundColor, const Color(0xFFF5F5F5));
        expect(data.baselineY, 2.5);
        expect(data.candlestickTouchData.touchSpotThreshold, 12);
        expect(data.showingTooltipIndicators, [0]);
        expect(
            data.candlestickSpots
                .map((s) => (s.x, s.open, s.high, s.low, s.close))
                .toList(),
            [
              (1.0, 2.0, 4.0, 1.0, 3.0),
              (1.8, 3.0, 3.5, 0.5, 1.0),
            ]);
        expect(data.candlestickSpots.first.isUp, isTrue);
        expect(data.candlestickSpots.last.isUp, isFalse);
        expect(tester.takeException(), isNull);
      });

      testWidgets('hidden candles are not drawn', (tester) async {
        await mountWire(
            tester, platform, candlestickChart(spot: {'visible': false}),
            extensions: [Extension()]);
        expect(candleData(tester).candlestickSpots.single.x, 1.8);
      });

      testWidgets('a disabled chart ignores touches', (tester) async {
        await mountWire(
            tester, platform, candlestickChart(props: {'disabled': true}),
            extensions: [Extension()]);
        expect(candleData(tester).candlestickTouchData.enabled, isFalse);
      });

      testWidgets('tapping a candle reaches Ruby only when subscribed',
          (tester) async {
        var mounted = await mountWire(tester, platform, candlestickChart(),
            extensions: [Extension()]);
        expect(candleData(tester).candlestickTouchData.touchCallback, isNull);
        await tapFirstCandle(tester);
        expect(mounted.backend.events, isEmpty);

        mounted = await mountWire(
            tester, platform, candlestickChart(props: {'on_event': true}),
            extensions: [Extension()]);
        await tapFirstCandle(tester);
        final events = mounted.backend.events;
        expect(events.map((e) => (e.id, e.name)).toSet(), {(1, 'event')});
        expect(events.last.data, {'type': 'tapUp', 'spot_index': 0});
        expect(tester.takeException(), isNull);
      });
    });
  }
}
