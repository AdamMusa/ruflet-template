import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ruflet_charts/src/utils/bar_chart.dart';
import 'package:ruflet_charts/src/utils/charts.dart';
import 'package:ruflet_charts/src/utils/radar_chart.dart';

void main() {
  test('chart enum names accept camelCase and Ruby snake_case', () {
    for (final name in ['spaceBetween', 'space_between', 'SPACE_BETWEEN']) {
      expect(parseBarChartAlignment(name), BarChartAlignment.spaceBetween,
          reason: name);
    }
    expect(
        parseBarChartAlignment('space_evenly'), BarChartAlignment.spaceEvenly);
    expect(parseTooltipDirection('Bottom'), TooltipDirection.bottom);
    expect(parseFLHorizontalAlignment('right'), FLHorizontalAlignment.right);
    expect(parseRadarShape('POLYGON'), RadarShape.polygon);
  });

  test('unknown chart enum names keep the default', () {
    expect(parseBarChartAlignment('space_out', BarChartAlignment.center),
        BarChartAlignment.center);
    expect(parseTooltipDirection(null, TooltipDirection.auto),
        TooltipDirection.auto);
    expect(parseRadarShape('square'), isNull);
  });
}
