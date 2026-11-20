import 'package:equatable/equatable.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:ruflet/ruflet.dart';
import 'package:flutter/widgets.dart';

import 'charts.dart';

class LineChartEventData extends Equatable {
  final String eventType;
  final List<LineChartEventDataSpot> barSpots;

  const LineChartEventData({required this.eventType, required this.barSpots});

  factory LineChartEventData.fromDetails(
      FlTouchEvent event, LineTouchResponse? response) {
    return LineChartEventData(
        eventType: resolveFlTouchEventType(event),
        barSpots: response != null && response.lineBarSpots != null
            ? response.lineBarSpots!
                .map((bs) => LineChartEventDataSpot(
                    barIndex: bs.barIndex, spotIndex: bs.spotIndex))
                .toList()
            : []);
  }

  // Spots go to Ruby as plain maps: the wire encoder cannot serialize
  // LineChartEventDataSpot objects.
  Map<String, dynamic> toMap() => <String, dynamic>{
        'type': eventType,
        'spots': barSpots.map((spot) => spot.toMap()).toList(),
      };

  @override
  List<Object?> get props => [eventType, barSpots];
}

class LineChartEventDataSpot extends Equatable {
  final int barIndex;
  final int spotIndex;

  const LineChartEventDataSpot(
      {required this.barIndex, required this.spotIndex});

  Map<String, dynamic> toMap() => <String, dynamic>{
        'bar_index': barIndex,
        'spot_index': spotIndex,
      };

  @override
  List<Object?> get props => [barIndex, spotIndex];
}

/// What [dataPoint] shows when touched. [fallback] is fl_chart's default item
/// when the chart has no `tooltip` of its own: a point without a tooltip
/// shows it, and a point with one keeps its label style. With a chart
/// `tooltip`, a point without one shows its value.
LineTooltipItem? parseLineTooltipItem(
    Control dataPoint, LineBarSpot spot, BuildContext context,
    [LineTooltipItem? fallback]) {
  if (!dataPoint.getBool("show_tooltip", true)!) return null;

  final own = chartItemTooltip(dataPoint);
  if (own == null && fallback != null) return fallback;
  var tooltip = own ?? const {};

  final theme = RufletStyleTheme.of(context);
  var style = parseTextStyle(
      tooltip["text_style"], theme, fallback?.textStyle ?? const TextStyle())!;
  if (style.color == null) {
    style = style.copyWith(
        color: spot.bar.gradient?.colors.first ??
            spot.bar.color ??
            const Color(0xFF607D8B));
  }
  return LineTooltipItem(
      tooltip["text"] ?? dataPoint.getDouble("y", 0)!.toString(), style,
      textAlign: parseTextAlign(tooltip["text_align"], TextAlign.center)!,
      textDirection: parseBool(tooltip["rtl"], false)!
          ? TextDirection.rtl
          : TextDirection.ltr,
      children: tooltip["text_spans"] != null
          ? parseTextSpans(tooltip["text_spans"], theme, (s, eventName,
              [eventData]) {
              s.triggerEvent(eventName, eventData);
            })
          : null);
}

/// The touch tooltip. Flet's Python always sends a chart `tooltip`; Ruby only
/// when the app sets one. Without it the chart keeps fl_chart's own tooltip
/// (color, label style, value text), as before, and only a point's own
/// `tooltip` or `show_tooltip: false` changes what that point shows.
LineTouchTooltipData parseLineTouchTooltipData(
    BuildContext context, Control control) {
  final tooltip = chartTooltipConfig(control);

  // fl_chart needs one item per touched spot; a null item hides that spot's.
  List<LineTooltipItem?> getTooltipItems(List<LineBarSpot> touchedSpots) => [
        for (final spot in touchedSpots)
          parseLineTooltipItem(
              control
                  .children("data_series")[spot.barIndex]
                  .children("points")[spot.spotIndex],
              spot,
              context,
              tooltip == null ? defaultLineTooltipItem([spot]).single : null),
      ];

  if (tooltip == null) {
    return LineTouchTooltipData(getTooltipItems: getTooltipItems);
  }

  final theme = RufletStyleTheme.of(context);

  return LineTouchTooltipData(
    getTooltipColor: (LineBarSpot spot) => parseColor(
        tooltip["bgcolor"], theme, const Color.fromRGBO(96, 125, 139, 1))!,
    tooltipBorderRadius: parseBorderRadius(tooltip["border_radius"]),
    tooltipMargin: parseDouble(tooltip["margin"], 16)!,
    tooltipPadding: parsePadding(tooltip["padding"],
        const EdgeInsets.symmetric(horizontal: 16, vertical: 8))!,
    maxContentWidth: parseDouble(tooltip["max_width"], 120)!,
    rotateAngle: parseDouble(tooltip["rotation"], 0.0)!,
    tooltipHorizontalOffset: parseDouble(tooltip["horizontal_offset"], 0)!,
    tooltipBorder: parseBorderSide(tooltip["border_side"], theme,
        defaultValue: BorderSide.none)!,
    fitInsideHorizontally:
        parseBool(tooltip["fit_inside_horizontally"], false)!,
    fitInsideVertically: parseBool(tooltip["fit_inside_vertically"], false)!,
    showOnTopOfTheChartBoxArea:
        parseBool(tooltip["show_on_top_of_chart_box_area"], false)!,
    tooltipHorizontalAlignment: parseFLHorizontalAlignment(
        tooltip["horizontal_alignment"], FLHorizontalAlignment.center)!,
    getTooltipItems: getTooltipItems,
  );
}

LineChartBarData parseLineChartBarData(
    Control parent,
    Control chartData,
    bool interactiveChart,
    BuildContext context,
    Map<int, List<FlSpot>> barSpots) {
  final theme = RufletStyleTheme.of(context);

  var aboveLineBgcolor = chartData.getColor("above_line_bgcolor", context);
  var aboveLineGradient = chartData.getGradient("above_line_gradient", theme);
  var belowLineBgcolor = chartData.getColor("below_line_bgcolor", context);
  var belowLineGradient = chartData.getGradient("below_line_gradient", theme);
  var dashPattern = chartData.get("dash_pattern");
  var barColor = chartData.getColor("color", context, const Color(0xFF00BCD4))!;
  var barGradient = chartData.getGradient("gradient", theme);
  var aboveLine =
      parseFlLine(chartData.get("above_line"), RufletStyleTheme.of(context));
  var belowLine =
      parseFlLine(chartData.get("below_line"), RufletStyleTheme.of(context));
  var aboveLineCutoffY = chartData.getDouble("above_line_cutoff_y");
  var belowLineCutoffY = chartData.getDouble("below_line_cutoff_y");
  var stepDirection = chartData.getDouble("step_direction");

  Map<FlSpot, Control> spots = {
    for (var e in chartData.children("points"))
      FlSpot(e.getDouble("x", 0)!, e.getDouble("y", 0)!): e
  };
  return LineChartBarData(
      preventCurveOverShooting:
          chartData.getBool("prevent_curve_over_shooting", false)!,
      preventCurveOvershootingThreshold:
          chartData.getDouble("prevent_curve_over_shooting_threshold", 10.0)!,
      spots: barSpots[chartData.id] ?? [],
      curveSmoothness: chartData.getDouble("curve_smoothness", 0.35)!,
      show: chartData.visible,
      isStepLineChart: stepDirection != null,
      lineChartStepData: LineChartStepData(stepDirection: stepDirection ?? 0.5),
      showingIndicators: chartData
          .children("points")
          .asMap()
          .entries
          .where(
              (dp) => !interactiveChart && dp.value.getBool("selected", false)!)
          .map((e) => e.key)
          .toList(),
      isCurved: chartData.getBool("curved", false)!,
      isStrokeCapRound: chartData.getBool("rounded_stroke_cap", false)!,
      isStrokeJoinRound: chartData.getBool("rounded_stroke_join", false)!,
      barWidth: chartData.getDouble("stroke_width", 2.0)!,
      dashArray: dashPattern != null
          ? (dashPattern as List).map((e) => parseInt(e)).nonNulls.toList()
          : null,
      shadow:
          parseBoxShadow(chartData.get("shadow"), RufletStyleTheme.of(context)) ??
              const Shadow(color: Color(0x00000000)),
      dotData: FlDotData(
          show: true,
          getDotPainter: (spot, percent, barData, index) {
            var allDotsPainter = parseChartDotPainter(
                chartData.get("point"), theme, percent, barColor, barGradient);
            var dotPainter = parseChartDotPainter(
                chartData.children("points")[index].get("point"),
                theme,
                percent,
                barColor,
                barGradient);
            return dotPainter ?? allDotsPainter ?? invisibleDotPainter;
          }),
      aboveBarData: aboveLineBgcolor != null ||
              aboveLineGradient != null ||
              aboveLine != null
          ? BarAreaData(
              show: true,
              color: aboveLineBgcolor,
              gradient: aboveLineGradient,
              applyCutOffY: aboveLineCutoffY != null,
              cutOffY: aboveLineCutoffY ?? 0,
              spotsLine: BarAreaSpotsLine(
                show: aboveLine != null,
                flLineStyle: aboveLine ?? const FlLine(),
                checkToShowSpotLine: (spot) =>
                    spots[spot]!.getBool("show_above_line", true)!,
              ))
          : null,
      belowBarData: belowLineBgcolor != null ||
              belowLineGradient != null ||
              belowLine != null
          ? BarAreaData(
              show: true,
              color: belowLineBgcolor,
              gradient: belowLineGradient,
              applyCutOffY: belowLineCutoffY != null,
              cutOffY: belowLineCutoffY ?? 0,
              spotsLine: BarAreaSpotsLine(
                show: belowLine != null,
                flLineStyle: belowLine ?? const FlLine(),
                checkToShowSpotLine: (spot) =>
                    spots[spot]!.getBool("show_below_line", true)!,
              ))
          : null,
      color: barColor,
      gradient: barGradient);
}
