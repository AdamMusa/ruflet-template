// Ruby's container: box geometry, decoration and its click, long press,
// hover and tap-down events, on both designs.
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/control_harness.dart';

// ruflet-coverage: Container

Map<String, dynamic> _container(Map<String, dynamic> props) => {
      '_c': 'Container',
      '_i': 2,
      'key': 'box',
      'width': 120,
      'height': 80,
      'content': {
        '_c': 'Container',
        '_i': 3,
        'key': 'inner',
        'width': 20,
        'height': 10,
      },
      ...props,
    };

Rect _rect(WidgetTester tester, String key) =>
    tester.getRect(find.byKey(ValueKey<Object>(key)).last);

/// The BoxDecoration painted inside the Ruby container (the first one).
BoxDecoration? _decoration(WidgetTester tester) {
  final boxes = find.descendant(
      of: find.byKey(const ValueKey<Object>('box')).first,
      matching: find.byType(DecoratedBox));
  if (boxes.evaluate().isEmpty) return null;
  return tester.widget<DecoratedBox>(boxes.first).decoration as BoxDecoration;
}

List<String> _events(HarnessMount mount) => [
      for (final m in mount.backend.sent)
        if (m.props == null) '${m.id}:${m.name}'
    ];

void main() {
  for (final design in HarnessDesign.values) {
    final name = design.name;

    group('$name Container', () {
      testWidgets('width, height, padding, margin and alignment place it',
          (tester) async {
        await mountWire(
            tester,
            design,
            _container({
              'padding': 10,
              'margin': {'left': 7, 'top': 5, 'right': 0, 'bottom': 0},
              'alignment': {'x': 1, 'y': 1},
            }));
        expect(tester.takeException(), isNull);
        final box = _rect(tester, 'box');
        expect(box.size, const Size(127, 85));
        final inner = _rect(tester, 'inner').shift(-box.topLeft);
        // Right/bottom aligned inside the 10-padded 120x80 box after margin.
        expect(inner,
            const Rect.fromLTWH(7 + 120 - 10 - 20, 5 + 80 - 10 - 10, 20, 10));
      });

      testWidgets('bgcolor, border_radius, border and gradient decorate it',
          (tester) async {
        await mountWire(
            tester,
            design,
            _container({
              'bgcolor': '#336699',
              'border_radius': 12,
              'border': {
                'left': {'width': 2, 'color': '#ff0000'},
                'top': {'width': 2, 'color': '#ff0000'},
                'right': {'width': 2, 'color': '#ff0000'},
                'bottom': {'width': 2, 'color': '#ff0000'},
              },
            }));
        final decoration = _decoration(tester)!;
        expect(decoration.color, const Color(0xFF336699));
        expect(decoration.borderRadius, BorderRadius.circular(12));
        final border = decoration.border as Border;
        expect(border.top.width, 2);
        expect(border.top.color, const Color(0xFFFF0000));

        await mountWire(
            tester,
            design,
            _container({
              'gradient': {
                '_type': 'linear',
                'begin': {'x': -1, 'y': 0},
                'end': {'x': 1, 'y': 0},
                'colors': ['#000000', '#ffffff'],
              },
              'shape': 'circle',
            }));
        final gradient = _decoration(tester)!;
        expect(gradient.shape, BoxShape.circle);
        expect(gradient.gradient, isA<LinearGradient>());
        expect((gradient.gradient! as LinearGradient).colors,
            const [Color(0xFF000000), Color(0xFFFFFFFF)]);
      });

      testWidgets('on_click and on_long_press reach Ruby', (tester) async {
        final mount = await mountWire(tester, design,
            _container({'on_click': true, 'on_long_press': true}));
        await tester.tap(find.byKey(const ValueKey<Object>('box')).last);
        await tester.pumpAndSettle();
        await tester.longPress(find.byKey(const ValueKey<Object>('box')).last);
        await tester.pumpAndSettle();
        expect(_events(mount), ['2:click', '2:long_press']);
      });

      testWidgets('on_tap_down sends the local and global position',
          (tester) async {
        final mount =
            await mountWire(tester, design, _container({'on_tap_down': true}));
        final origin = _rect(tester, 'box').topLeft;
        await tester.tapAt(origin + const Offset(30, 20));
        await tester.pumpAndSettle();
        final down =
            mount.backend.sent.singleWhere((m) => m.name == 'tap_down');
        final data = down.data as Map;
        expect(data['l'], {'x': 30.0, 'y': 20.0});
        expect(data['g'], {'x': origin.dx + 30, 'y': origin.dy + 20});
      });

      testWidgets('on_hover reports entering and leaving', (tester) async {
        final mount =
            await mountWire(tester, design, _container({'on_hover': true}));
        final gesture =
            await tester.createGesture(kind: PointerDeviceKind.mouse);
        await gesture.addPointer(location: const Offset(700, 500));
        addTearDown(gesture.removePointer);
        await gesture.moveTo(_rect(tester, 'box').center);
        await tester.pumpAndSettle();
        await gesture.moveTo(const Offset(700, 500));
        await tester.pumpAndSettle();
        expect([
          for (final m in mount.backend.sent)
            if (m.name == 'hover') m.data
        ], [
          true,
          false
        ]);
      });

      testWidgets('without on_click, or when disabled, a tap sends nothing',
          (tester) async {
        var mount = await mountWire(tester, design, _container({}));
        await tester.tap(find.byKey(const ValueKey<Object>('box')).last);
        await tester.pumpAndSettle();
        expect(_events(mount), isEmpty);

        mount = await mountWire(
            tester, design, _container({'on_click': true, 'disabled': true}));
        await tester.tap(find.byKey(const ValueKey<Object>('box')).last,
            warnIfMissed: false);
        await tester.pumpAndSettle();
        expect(_events(mount), isEmpty);
      });
    });
  }
}
