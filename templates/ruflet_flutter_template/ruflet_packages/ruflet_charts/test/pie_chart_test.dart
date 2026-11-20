// ruflet-coverage: PieChart PieChartSection
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ruflet_charts/ruflet_charts.dart';

import 'support/harness.dart';

/// A pie chart as Ruby serializes `pie_chart(sections: [...], ...)`: two
/// equal halves, the first below the horizontal axis, the second above.
Map<String, dynamic> pieChart({Map<String, dynamic> props = const {}}) =>
    wire('PieChart', 1, {
      'width': 200,
      'height': 200,
      'center_space_radius': 0,
      'sections': [
        wire('PieChartSection', 2, {
          'value': 1,
          'color': '#ff0000',
          'radius': 80,
          'title': 'Rent',
          'title_style': {'size': 12, 'color': '#ffffff'},
          'title_position': 0.6,
          'border_side': {'width': 2, 'color': '#000000'},
        }),
        wire('PieChartSection', 3, {
          'value': 1,
          'color': '#00ff00',
          'radius': 70,
          'badge': wire('Text', 4, {'value': 'B'}),
          'badge_position': 1.1,
        }),
      ],
      ...props,
    });

PieChartData pieData(WidgetTester tester) =>
    tester.widget<PieChart>(find.byType(PieChart)).data;

Future<void> tapPie(WidgetTester tester, Offset offset) async {
  await tester.tapAt(tester.getTopLeft(find.byType(PieChart)) + offset);
  await tester.pumpAndSettle();
}

void main() {
  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    group('PieChart ($platform)', () {
      testWidgets('renders sections from the wire', (tester) async {
        await mountWire(
            tester,
            platform,
            pieChart(props: {
              'center_space_radius': 10,
              'center_space_color': '#abcdef',
              'sections_space': 3,
              'start_degree_offset': 45,
            }),
            extensions: [Extension()]);

        expect(tester.getSize(find.byType(PieChart)), const Size(200, 200));
        final data = pieData(tester);
        expect(data.centerSpaceRadius, 10);
        expect(data.centerSpaceColor, const Color(0xFFABCDEF));
        expect(data.sectionsSpace, 3);
        expect(data.startDegreeOffset, 45);

        final rent = data.sections.first;
        expect(rent.value, 1);
        expect(rent.color, const Color(0xFFFF0000));
        expect(rent.radius, 80);
        expect(rent.showTitle, isTrue);
        expect(rent.title, 'Rent');
        expect(rent.titleStyle?.fontSize, 12);
        expect(rent.titleStyle?.color, const Color(0xFFFFFFFF));
        expect(rent.titlePositionPercentageOffset, 0.6);
        expect(rent.borderSide.width, 2);

        final other = data.sections.last;
        expect(other.color, const Color(0xFF00FF00));
        expect(other.radius, 70);
        expect(other.showTitle, isFalse);
        expect(other.badgePositionPercentageOffset, 1.1);
        expect(find.text('B'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('tapping a section reaches Ruby only when subscribed',
          (tester) async {
        var mounted = await mountWire(tester, platform, pieChart(),
            extensions: [Extension()]);
        expect(pieData(tester).pieTouchData.touchCallback, isNull);
        await tapPie(tester, const Offset(100, 150));
        expect(mounted.backend.events, isEmpty);

        mounted = await mountWire(
            tester, platform, pieChart(props: {'on_event': true}),
            extensions: [Extension()]);
        await tapPie(tester, const Offset(100, 150));
        await tapPie(tester, const Offset(100, 50));
        final taps = mounted.backend.events
            .where((e) => (e.data as Map)['type'] == 'tapUp')
            .toList();
        expect(taps.map((e) => (e.id, e.name)).toSet(), {(1, 'event')});
        expect(taps.map((e) => e.data).toList(), [
          {'type': 'tapUp', 'section_index': 0, 'local_x': 100, 'local_y': 150},
          {'type': 'tapUp', 'section_index': 1, 'local_x': 100, 'local_y': 50},
        ]);
        expect(tester.takeException(), isNull);
      });
    });
  }
}
