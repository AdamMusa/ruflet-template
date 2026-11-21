// A chart's `tooltip` map is fl_chart's touch tooltip configuration. Ruby
// sends it as-is (no Flet `_internals.skip_properties`), so the chart must
// keep it out of the generic control tooltip LayoutControl adds.
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart' show Tooltip;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ruflet_charts/ruflet_charts.dart';

import 'support/harness.dart';

Map<String, dynamic> chart(String type, Object? tooltip) {
  final props = <String, dynamic>{
    'width': 300,
    'height': 200,
    'tooltip': tooltip,
  };
  return switch (type) {
    'BarChart' => wire(type, 1, {
        ...props,
        'groups': [
          wire('BarChartGroup', 2, {
            'x': 0,
            'rods': [
              wire('BarChartRod', 3, {'to_y': 8}),
            ],
          }),
        ],
      }),
    'LineChart' => wire(type, 1, {
        ...props,
        'data_series': [
          wire('LineChartData', 2, {
            'points': [
              wire('LineChartDataPoint', 3, {'x': 1, 'y': 2}),
            ],
          }),
        ],
      }),
    'ScatterChart' => wire(type, 1, {
        ...props,
        'spots': [
          wire('ScatterChartSpot', 2, {'x': 1, 'y': 2}),
        ],
      }),
    _ => wire(type, 1, {
        ...props,
        'spots': [
          wire('CandlestickChartSpot', 2,
              {'x': 1, 'open': 2, 'high': 4, 'low': 1, 'close': 3}),
        ],
      }),
  };
}

/// The touch tooltip background color the chart hands fl_chart.
Color touchTooltipColor(WidgetTester tester, String type) {
  switch (type) {
    case 'BarChart':
      final data = tester.widget<BarChart>(find.byType(BarChart)).data;
      return data.barTouchData.touchTooltipData
          .getTooltipColor(data.barGroups.single);
    case 'LineChart':
      final data = tester.widget<LineChart>(find.byType(LineChart)).data;
      final bar = data.lineBarsData.single;
      return data.lineTouchData.touchTooltipData
          .getTooltipColor(LineBarSpot(bar, 0, bar.spots.single));
    case 'ScatterChart':
      final data = tester.widget<ScatterChart>(find.byType(ScatterChart)).data;
      return data.scatterTouchData.touchTooltipData
          .getTooltipColor(data.scatterSpots.single);
    default:
      final data =
          tester.widget<CandlestickChart>(find.byType(CandlestickChart)).data;
      return data.candlestickTouchData.touchTooltipData
          .getTooltipColor(data.candlestickSpots.single);
  }
}

/// The control tooltip showing [message]: Material's Tooltip, or the
/// Semantics tooltip of the Cupertino overlay.
Finder controlTooltip(TargetPlatform platform, String message) =>
    platform == TargetPlatform.android
        ? find.byTooltip(message)
        : find.byWidgetPredicate((widget) =>
            widget is Semantics && widget.properties.tooltip == message);

void main() {
  const types = ['BarChart', 'LineChart', 'ScatterChart', 'CandlestickChart'];
  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    for (final type in types) {
      testWidgets(
          '$type tooltip map configures the touch tooltip only ($platform)',
          (tester) async {
        await mountWire(tester, platform, chart(type, {'bgcolor': '#ff0000'}),
            extensions: [Extension()]);

        expect(tester.takeException(), isNull);
        final rendered = find.byWidgetPredicate(
            (widget) => widget.runtimeType.toString() == type);
        expect(tester.getSize(rendered), const Size(300, 200));
        expect(touchTooltipColor(tester, type), const Color(0xFFFF0000));
        expect(find.byType(Tooltip), findsNothing);
      });
    }

    for (final type in types) {
      testWidgets('$type text tooltip stays the control tooltip ($platform)',
          (tester) async {
        // Reading a text as the touch tooltip map threw "type 'String' is
        // not a subtype of type 'int' of 'index'" while building the chart.
        await mountWire(tester, platform, chart(type, 'Sales'),
            extensions: [Extension()]);

        expect(tester.takeException(), isNull);
        final rendered = find.byWidgetPredicate(
            (widget) => widget.runtimeType.toString() == type);
        expect(tester.getSize(rendered), const Size(300, 200));
        expect(controlTooltip(platform, 'Sales'), findsOneWidget);
      });
    }

    for (final type in types) {
      testWidgets(
          '$type tooltip map with a message is also the control tooltip '
          '($platform)', (tester) async {
        // Only a map without a message broke Material; one with a message
        // already made a working control tooltip, and still does.
        await mountWire(tester, platform,
            chart(type, {'message': 'Sales', 'bgcolor': '#ff0000'}),
            extensions: [Extension()]);

        expect(tester.takeException(), isNull);
        final rendered = find.byWidgetPredicate(
            (widget) => widget.runtimeType.toString() == type);
        expect(tester.getSize(rendered), const Size(300, 200));
        expect(touchTooltipColor(tester, type), const Color(0xFFFF0000));
        expect(controlTooltip(platform, 'Sales'), findsOneWidget);
      });
    }

    testWidgets(
        'a tooltip map Ruby gives a message becomes the control tooltip '
        '($platform)', (tester) async {
      final mounted = await mountWire(
          tester, platform, chart('BarChart', {'bgcolor': '#ff0000'}),
          extensions: [Extension()]);
      expect(find.byType(Tooltip), findsNothing);

      // Ruby's page sends a changed property as a whole-value replace op.
      Future<void> rubySets(Map<String, dynamic> tooltip) async {
        mounted.root.applyPatch([
          [0],
          [0, 0, 'tooltip', tooltip]
        ], mounted.backend);
        await tester.pumpAndSettle();
      }

      await rubySets({'message': 'Sales', 'bgcolor': '#00ff00'});
      expect(tester.takeException(), isNull);
      expect(controlTooltip(platform, 'Sales'), findsOneWidget);
      expect(touchTooltipColor(tester, 'BarChart'), const Color(0xFF00FF00));

      await rubySets({'bgcolor': '#0000ff'});
      expect(tester.takeException(), isNull);
      expect(find.byType(Tooltip), findsNothing);
      expect(controlTooltip(platform, 'Sales'), findsNothing);
      expect(touchTooltipColor(tester, 'BarChart'), const Color(0xFF0000FF));
    });

    testWidgets(
        'a tooltip map Ruby replaces with a text becomes the control '
        'tooltip ($platform)', (tester) async {
      final mounted = await mountWire(
          tester, platform, chart('BarChart', {'bgcolor': '#ff0000'}),
          extensions: [Extension()]);
      expect(find.byType(Tooltip), findsNothing);

      mounted.backend.updateControl(1, {'tooltip': 'Sales'}, notify: true);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      if (platform == TargetPlatform.android) {
        expect(find.byTooltip('Sales'), findsOneWidget);
      }

      mounted.backend
          .updateControl(1, {'tooltip': {'bgcolor': '#00ff00'}}, notify: true);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(Tooltip), findsNothing);
      expect(touchTooltipColor(tester, 'BarChart'), const Color(0xFF00FF00));
    });

    testWidgets('a tooltip skip Flet sent is kept ($platform)', (tester) async {
      await mountWire(
          tester,
          platform,
          {
            ...chart('BarChart', 'Sales'),
            '_internals': {
              'skip_properties': ['tooltip']
            },
          },
          extensions: [Extension()]);
      expect(tester.takeException(), isNull);
      expect(find.byType(BarChart), findsOneWidget);
      expect(find.byType(Tooltip), findsNothing);
    });

    testWidgets(
        'without a chart tooltip, bar and line charts keep fl_chart\'s '
        'tooltip ($platform)', (tester) async {
      // Ruby sends no chart `tooltip` unless the app sets one; fl_chart's
      // own box and label style stay as they were.
      await mountWire(tester, platform, chart('BarChart', null),
          extensions: [Extension()]);
      final bar = tester.widget<BarChart>(find.byType(BarChart)).data;
      final barTooltip = bar.barTouchData.touchTooltipData;
      const barDefaults = BarTouchTooltipData();
      final group = bar.barGroups.single;
      final rod = group.barRods.single;
      expect(barTooltip.getTooltipColor(group), defaultBarTooltipColor(group));
      expect(barTooltip.tooltipBorderRadius, barDefaults.tooltipBorderRadius);
      expect(barTooltip.tooltipPadding, barDefaults.tooltipPadding);
      expect(barTooltip.tooltipMargin, barDefaults.tooltipMargin);
      expect(barTooltip.maxContentWidth, barDefaults.maxContentWidth);
      final barItem = barTooltip.getTooltipItem(group, 0, rod, 0)!;
      final barDefault = defaultBarTooltipItem(group, 0, rod, 0)!;
      expect(barItem.text, barDefault.text);
      expect(barItem.textStyle, barDefault.textStyle);
      expect(barItem.textStyle.fontWeight, FontWeight.bold);

      await mountWire(tester, platform, chart('LineChart', null),
          extensions: [Extension()]);
      final line = tester.widget<LineChart>(find.byType(LineChart)).data;
      final lineTooltip = line.lineTouchData.touchTooltipData;
      const lineDefaults = LineTouchTooltipData();
      final series = line.lineBarsData.single;
      final spot = LineBarSpot(series, 0, series.spots.single);
      expect(lineTooltip.getTooltipColor(spot), defaultLineTooltipColor(spot));
      expect(lineTooltip.tooltipBorderRadius, lineDefaults.tooltipBorderRadius);
      expect(lineTooltip.tooltipPadding, lineDefaults.tooltipPadding);
      expect(lineTooltip.tooltipMargin, lineDefaults.tooltipMargin);
      expect(lineTooltip.maxContentWidth, lineDefaults.maxContentWidth);
      final lineItem = lineTooltip.getTooltipItems([spot]).single!;
      final lineDefault = defaultLineTooltipItem([spot]).single;
      expect(lineItem.text, lineDefault.text);
      expect(lineItem.textStyle, lineDefault.textStyle);
    });
  }
}
