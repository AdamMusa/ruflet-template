import 'package:ruflet/ruflet.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' as material;
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

RufletBackend _backend(TargetPlatform platform) => RufletBackend(
      pageUri: Uri.parse('inprocess://fitted-box-test'),
      assetsDir: '',
      extensions: [],
      multiView: false,
    )..platform = platform;

Widget _host(RufletBackend backend, Widget child) {
  final body = Align(alignment: Alignment.topLeft, child: child);
  return ChangeNotifierProvider<RufletBackend>.value(
    value: backend,
    child: backend.platform == TargetPlatform.iOS
        ? CupertinoApp(home: CupertinoPageScaffold(child: body))
        : material.MaterialApp(home: material.Scaffold(body: body)),
  );
}

/// A Ruby `fitted_box` (100x40) around a fixed-size child, keyed "child".
Control _fittedBox(RufletBackend backend, Map<String, dynamic> props,
        {double childWidth = 400, double childHeight = 40}) =>
    Control.fromMap({
      '_c': 'FittedBox',
      '_i': 1,
      'width': 100,
      'height': 40,
      'content': {
        '_c': 'Container',
        '_i': 2,
        'key': 'child',
        'width': childWidth,
        'height': childHeight,
        'bgcolor': '#336699',
      },
      ...props,
    }, backend);

Future<Rect> _childRect(
    WidgetTester tester, RufletBackend backend, Map<String, dynamic> props,
    {double childWidth = 400, double childHeight = 40}) async {
  await tester.pumpWidget(_host(
      backend,
      ControlWidget(
          control: _fittedBox(backend, props,
              childWidth: childWidth, childHeight: childHeight))));
  expect(tester.takeException(), isNull);
  expect(find.byType(ErrorControl), findsNothing);
  // The box keeps its own Ruby size whatever the fit.
  expect(tester.getSize(find.byType(FittedBox)), const Size(100, 40));
  final origin = tester.getTopLeft(find.byType(FittedBox));
  // getRect maps through FittedBox's transform: the painted rectangle.
  return tester
      .getRect(find.byKey(const ValueKey<Object>('child')))
      .shift(-origin);
}

void main() {
  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    final name = platform.name;

    testWidgets('$name: scaleDown shrinks an oversized child to fit',
        (tester) async {
      final backend = _backend(platform);
      final rect = await _childRect(tester, backend, {'fit': 'scaleDown'});
      expect(rect, const Rect.fromLTWH(0, 15, 100, 10));
      final fitted = tester.widget<FittedBox>(find.byType(FittedBox));
      expect(fitted.fit, BoxFit.scaleDown);
      expect(fitted.alignment, Alignment.center);
      expect(fitted.clipBehavior, Clip.none);
    });

    testWidgets('$name: scaleDown leaves a small child unscaled',
        (tester) async {
      final backend = _backend(platform);
      final rect = await _childRect(tester, backend, {'fit': 'scale_down'},
          childWidth: 50, childHeight: 20);
      expect(rect, const Rect.fromLTWH(25, 10, 50, 20));
    });

    testWidgets('$name: default fit is contain and scales a small child up',
        (tester) async {
      final backend = _backend(platform);
      final rect = await _childRect(tester, backend, {},
          childWidth: 50, childHeight: 10);
      expect(
          tester.widget<FittedBox>(find.byType(FittedBox)).fit, BoxFit.contain);
      expect(rect, const Rect.fromLTWH(0, 10, 100, 20));
    });

    final expected = <String, Rect>{
      'fill': const Rect.fromLTWH(0, 0, 100, 40),
      'cover': const Rect.fromLTWH(-150, 0, 400, 40),
      'fitWidth': const Rect.fromLTWH(0, 15, 100, 10),
      'fit_height': const Rect.fromLTWH(-150, 0, 400, 40),
      'none': const Rect.fromLTWH(-150, 0, 400, 40),
    };
    for (final entry in expected.entries) {
      testWidgets('$name: fit ${entry.key} paints the expected rectangle',
          (tester) async {
        final backend = _backend(platform);
        final rect = await _childRect(tester, backend, {'fit': entry.key});
        expect(rect, entry.value);
      });
    }

    testWidgets('$name: alignment and clip_behavior are forwarded',
        (tester) async {
      final backend = _backend(platform);
      final rect = await _childRect(tester, backend, {
        'fit': 'contain',
        'alignment': {'x': -1, 'y': 1},
        'clip_behavior': 'hard_edge',
      });
      expect(rect, const Rect.fromLTWH(0, 30, 100, 10));
      final fitted = tester.widget<FittedBox>(find.byType(FittedBox));
      expect(fitted.alignment, const Alignment(-1, 1));
      expect(fitted.clipBehavior, Clip.hardEdge);
    });

    testWidgets('$name: missing content renders an empty box', (tester) async {
      final backend = _backend(platform);
      final control = Control.fromMap(
          {'_c': 'FittedBox', '_i': 1, 'width': 30, 'height': 30}, backend);
      await tester.pumpWidget(_host(backend, ControlWidget(control: control)));
      expect(tester.takeException(), isNull);
      expect(find.byType(ErrorControl), findsNothing);
      expect(tester.getSize(find.byType(FittedBox)), const Size(30, 30));
    });
  }
}
