// ruflet-coverage: ScatterChart ScatterChartSpot
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ruflet_charts/ruflet_charts.dart';

import 'support/harness.dart';

/// A scatter chart as Ruby serializes `scatter_chart(spots: [...], ...)`:
/// the first spot sits in the middle of the chart.
Map<String, dynamic> scatterChart(
        {Map<String, dynamic> props = const {},
        Map<String, dynamic> spot = const {}}) =>
    wire('ScatterChart', 1, {
      'width': 300,
      'height': 200,
      'min_x': 0,
      'max_x': 4,
      'min_y': 0,
      'max_y': 4,
      'spots': [
        wire('ScatterChartSpot', 2,
            {'x': 2, 'y': 2, 'radius': 10, 'color': '#ff0000', ...spot}),
        wire('ScatterChartSpot', 3, {
          'x': 3,
          'y': 1,
          'point': {'_type': 'ChartSquarePoint', 'size': 7},
        }),
      ],
      ...props,
    });

ScatterChartData scatterData(WidgetTester tester) =>
    tester.widget<ScatterChart>(find.byType(ScatterChart)).data;

Future<void> tapFirstSpot(WidgetTester tester) async {
  await tester.tapAt(
      tester.getTopLeft(find.byType(ScatterChart)) + const Offset(150, 100));
  await tester.pumpAndSettle();
}

void main() {
  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    group('ScatterChart ($platform)', () {
      testWidgets('renders spots from the wire', (tester) async {
        await mountWire(
            tester,
            platform,
            scatterChart(props: {
              'bgcolor': '#fefefe',
              'baseline_x': 2,
              'rotation_quarter_turns': 1,
            }, spot: {
              'render_priority': 3,
              'label_text': 'Mid',
              'label_text_style': {'size': 11},
              'selected': true,
            }),
            extensions: [Extension()]);

        expect(tester.getSize(find.byType(ScatterChart)), const Size(300, 200));
        final data = scatterData(tester);
        expect(
            (data.minX, data.maxX, data.minY, data.maxY), (0.0, 4.0, 0.0, 4.0));
        expect(data.backgroundColor, const Color(0xFFFEFEFE));
        expect(data.baselineX, 2);
        expect(data.rotationQuarterTurns, 1);
        expect(data.showingTooltipIndicators, [0]);

        final mid = data.scatterSpots.first;
        expect((mid.x, mid.y), (2.0, 2.0));
        expect(mid.renderPriority, 3);
        final painter = mid.dotPainter as FlDotCirclePainter;
        expect(painter.radius, 10);
        expect(painter.color, const Color(0xFFFF0000));
        expect(data.scatterLabelSettings.getLabelFunction(0, mid), 'Mid');
        final style =
            data.scatterLabelSettings.getLabelTextStyleFunction(0, mid)!;
        expect(style.fontSize, 11);
        expect(style.color, const Color(0xFFFF0000),
            reason: 'an uncolored label takes the spot color');

        final square = data.scatterSpots.last;
        expect((square.x, square.y), (3.0, 1.0));
        expect((square.dotPainter as FlDotSquarePainter).size, 7);
        expect(tester.takeException(), isNull);
      });

      testWidgets('hidden spots are not drawn', (tester) async {
        await mountWire(
            tester, platform, scatterChart(spot: {'visible': false}),
            extensions: [Extension()]);
        expect(scatterData(tester).scatterSpots.single.x, 3);
      });

      testWidgets('tapping a spot reaches Ruby only when subscribed',
          (tester) async {
        var mounted = await mountWire(tester, platform, scatterChart(),
            extensions: [Extension()]);
        expect(scatterData(tester).scatterTouchData.touchCallback, isNull);
        await tapFirstSpot(tester);
        expect(mounted.backend.events, isEmpty);

        mounted = await mountWire(
            tester, platform, scatterChart(props: {'on_event': true}),
            extensions: [Extension()]);
        await tapFirstSpot(tester);
        final events = mounted.backend.events;
        expect(events.map((e) => (e.id, e.name)).toSet(), {(1, 'event')});
        expect(events.last.data, {'type': 'tapUp', 'spot_index': 0});
        expect(tester.takeException(), isNull);
      });
    });
  }
}
