import 'package:ruflet/ruflet.dart';
import 'package:ruflet/src/utils/cupertino_theme.dart';
import 'package:ruflet_charts/src/candlestick_chart.dart';
import 'package:ruflet_charts/src/utils/charts.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Material, Theme;
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class _Backend extends RufletBackend {
  _Backend()
      : super(
            pageUri: Uri.parse('ruflet://test'),
            assetsDir: '',
            extensions: [],
            multiView: false) {
    platform = TargetPlatform.iOS;
  }

  final events = <(String, dynamic)>[];

  @override
  void triggerControlEvent(Control control, String eventName, [dynamic data]) {
    events.add((eventName, data));
  }
}

void main() {
  test('candlestick touch painter obtains outline from neutral native theme',
      () {
    final indicator = chartTouchIndicator(
        const RufletStyleTheme(colors: {'outline': Color(0xFF112233)}));
    final painter = indicator.painter as AxisLinesIndicatorPainter;
    expect(painter.horizontalLineProvider!(2)!.color,
        const Color(0xFF112233).withValues(alpha: 0.5));
    expect(painter.verticalLineProvider!(3)!.color,
        const Color(0xFF112233).withValues(alpha: 0.5));
  });

  testWidgets(
      'interactive candlesticks preserve events without a Material theme',
      (tester) async {
    final backend = _Backend();
    final spot = Control(
        id: 2,
        type: 'CandlestickSpot',
        backend: backend,
        properties: {
          'x': 1.0,
          'open': 2.0,
          'high': 4.0,
          'low': 1.0,
          'close': 3.0
        });
    final control =
        Control(id: 1, type: 'CandlestickChart', backend: backend, properties: {
      'spots': [spot],
      'min_x': 0.0,
      'max_x': 2.0,
      'min_y': 0.0,
      'max_y': 5.0,
      'on_event': true
    });
    await tester.pumpWidget(ChangeNotifierProvider<RufletBackend>.value(
      value: backend,
      child: CupertinoApp(
        builder: (context, child) => RufletStyleThemeScope(
            data: cupertinoStyleTheme(context), child: child!),
        home: Center(
            child: SizedBox(
                width: 300,
                height: 250,
                child: CandlestickChartControl(control: control))),
      ),
    ));
    await tester.pumpAndSettle();
    final chart =
        tester.widget<CandlestickChart>(find.byType(CandlestickChart));
    expect(chart.data.touchedPointIndicator?.painter, isNotNull);
    await tester.tapAt(tester.getCenter(find.byType(CandlestickChart)));
    await tester.pumpAndSettle();
    expect(backend.events, isNotEmpty);
    expect(find.byType(Material), findsNothing);
    expect(find.byType(Theme), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
