// ruflet-coverage: RadarChart RadarChartTitle RadarDataSet RadarDataSetEntry
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ruflet_charts/ruflet_charts.dart';

import 'support/harness.dart';

/// A radar chart as Ruby serializes `radar_chart(data_sets: [...], ...)`:
/// one data set whose first entry (the largest) points straight up.
Map<String, dynamic> radarChart(
        {Map<String, dynamic> props = const {},
        Map<String, dynamic> dataSet = const {}}) =>
    wire('RadarChart', 1, {
      'width': 200,
      'height': 200,
      'data_sets': [
        wire('RadarDataSet', 2, {
          'entries': [
            wire('RadarDataSetEntry', 3, {'value': 3}),
            wire('RadarDataSetEntry', 4, {'value': 1}),
            wire('RadarDataSetEntry', 5, {'value': 2}),
          ],
          ...dataSet,
        }),
      ],
      ...props,
    });

RadarChartData radarData(WidgetTester tester) =>
    tester.widget<RadarChart>(find.byType(RadarChart)).data;

/// Taps the first entry, at the top of the radar.
Future<void> tapFirstEntry(WidgetTester tester) async {
  await tester.tapAt(
      tester.getTopLeft(find.byType(RadarChart)) + const Offset(100, 16));
  await tester.pumpAndSettle();
}

void main() {
  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    group('RadarChart ($platform)', () {
      testWidgets('renders data sets, entries and titles from the wire',
          (tester) async {
        await mountWire(
            tester,
            platform,
            radarChart(props: {
              'radar_bgcolor': '#f0f0f0',
              'radar_shape': 'circle',
              'radar_border_side': {'width': 3, 'color': '#111111'},
              'tick_count': 4,
              'center_min_value': true,
              'title_position_percentage_offset': 0.3,
              'titles': [
                wire('RadarChartTitle', 6, {'text': 'Speed'}),
                wire('RadarChartTitle', 7, {'text': 'Range', 'angle': 30}),
              ],
            }, dataSet: {
              'fill_color': '#4400ff00',
              'border_color': '#00ff00',
              'border_width': 3,
              'entry_radius': 6,
            }),
            extensions: [Extension()]);

        expect(tester.getSize(find.byType(RadarChart)), const Size(200, 200));
        final data = radarData(tester);
        expect(data.radarBackgroundColor, const Color(0xFFF0F0F0));
        expect(data.radarShape, RadarShape.circle);
        expect(data.radarBorderData.width, 3);
        expect(data.radarBorderData.color, const Color(0xFF111111));
        expect(data.tickCount, 4);
        expect(data.isMinValueAtCenter, isTrue);
        expect(data.titlePositionPercentageOffset, 0.3);

        final dataSet = data.dataSets.single;
        expect(dataSet.dataEntries.map((e) => e.value).toList(), [3, 1, 2]);
        expect(dataSet.fillColor, const Color(0x4400FF00));
        expect(dataSet.borderColor, const Color(0xFF00FF00));
        expect(dataSet.borderWidth, 3);
        expect(dataSet.entryRadius, 6);

        final speed = data.getTitle!(0, 12);
        expect(speed.text, 'Speed');
        expect(speed.angle, 12, reason: 'no angle: the radar places it');
        final range = data.getTitle!(1, 12);
        expect(range.text, 'Range');
        expect(range.angle, 30);
        expect(data.getTitle!(2, 12).text, '', reason: 'no title for entry 3');
        expect(tester.takeException(), isNull);
      });

      testWidgets('a disabled radar ignores touches', (tester) async {
        await mountWire(tester, platform, radarChart(props: {'disabled': true}),
            extensions: [Extension()]);
        expect(radarData(tester).radarTouchData.enabled, isFalse);
      });

      testWidgets('tapping an entry reaches Ruby only when subscribed',
          (tester) async {
        var mounted = await mountWire(tester, platform, radarChart(),
            extensions: [Extension()]);
        await tapFirstEntry(tester);
        expect(mounted.backend.events, isEmpty);

        mounted = await mountWire(
            tester, platform, radarChart(props: {'on_event': true}),
            extensions: [Extension()]);
        await tapFirstEntry(tester);
        final events = mounted.backend.events;
        expect(events.map((e) => (e.id, e.name)).toSet(), {(1, 'event')});
        expect(events.last.data, {
          'type': 'tapUp',
          'data_set_index': 0,
          'entry_index': 0,
          'entry_value': 3.0,
        });
        expect(tester.takeException(), isNull);
      });
    });
  }
}
