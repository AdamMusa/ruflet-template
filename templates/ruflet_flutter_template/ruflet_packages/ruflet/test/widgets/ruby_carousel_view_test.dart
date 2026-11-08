import 'package:ruflet/ruflet.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' as material;
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class _Backend extends RufletBackend {
  final events = <List<dynamic>>[];

  _Backend(TargetPlatform target)
      : super(
            pageUri: Uri.parse('inprocess://carousel-test'),
            assetsDir: '',
            extensions: [],
            multiView: false) {
    platform = target;
  }

  @override
  void updateControl(int id, Map<String, dynamic> props,
          {bool dart = true, bool python = true, bool notify = false}) =>
      super.updateControl(id, props, dart: dart, python: false, notify: notify);

  @override
  void triggerControlEvent(Control control, String name, [dynamic data]) {
    if (control.get("on_$name") == true) events.add([name, data]);
  }
}

bool _materialOnly(Widget widget) =>
    widget is material.Material ||
    widget is material.InkResponse ||
    widget is material.CarouselView ||
    widget is material.Scrollbar;

Widget _host(RufletBackend backend, Widget child,
    {double? width = 400, double? height = 200}) {
  // height: null puts the carousel in a vertical scroll view (unbounded).
  final body = height == null
      ? SingleChildScrollView(child: SizedBox(width: width, child: child))
      : Align(
          alignment: Alignment.topLeft,
          child: SizedBox(width: width, height: height, child: child));
  return ChangeNotifierProvider<RufletBackend>.value(
    value: backend,
    child: backend.platform == TargetPlatform.iOS
        ? CupertinoApp(home: CupertinoPageScaffold(child: body))
        : material.MaterialApp(home: material.Scaffold(body: body)),
  );
}

Map<String, dynamic> _item(int i) => {
      '_c': 'Container',
      '_i': 100 + i,
      'key': 'item$i',
      'content': {'_c': 'Text', '_i': 200 + i, 'value': 'Item $i'},
    };

Finder _itemFinder(int i) => find.byKey(ValueKey<Object>('item$i'));

Future<Control> _pump(
    WidgetTester tester, _Backend backend, Map<String, dynamic> props,
    {int count = 5, double? width = 400, double? height = 200}) async {
  final control = Control.fromMap({
    '_c': 'CarouselView',
    '_i': 1,
    'horizontal': true,
    'controls': [for (var i = 0; i < count; i++) _item(i)],
    ...props,
  }, backend);
  await tester.pumpWidget(_host(backend, ControlWidget(control: control),
      width: width, height: height));
  await tester.pumpAndSettle();
  return control;
}

double _carouselLeft(WidgetTester tester) =>
    tester.getTopLeft(find.byType(Scrollable).first).dx;

void main() {
  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    final name = platform.name;

    testWidgets('$name: items are item_extent wide, laid out in order',
        (tester) async {
      final backend = _Backend(platform);
      await _pump(tester, backend, {'item_extent': 150, 'padding': 0});
      expect(tester.takeException(), isNull);
      expect(find.byType(ErrorControl), findsNothing);
      final first = tester.getRect(_itemFinder(0));
      final second = tester.getRect(_itemFinder(1));
      expect(first.width, 150);
      expect(first.height, 200);
      expect(first.left, _carouselLeft(tester));
      expect(second.left, first.left + 150);
      expect(second.width, 150);
      if (platform == TargetPlatform.iOS) {
        expect(find.byWidgetPredicate(_materialOnly), findsNothing);
      } else {
        final carousel = tester
            .widget<material.CarouselView>(find.byType(material.CarouselView));
        expect(carousel.itemExtent, 150);
        expect(carousel.flexWeights, isNull);
        expect(find.byType(CupertinoButton), findsNothing);
      }
    });

    testWidgets('$name: default padding insets every item by 4',
        (tester) async {
      final backend = _Backend(platform);
      await _pump(tester, backend, {'item_extent': 150});
      final first = tester.getRect(_itemFinder(0));
      expect(first.width, 142);
      expect(first.height, 192);
      expect(first.left, _carouselLeft(tester) + 4);
      expect(tester.getRect(_itemFinder(1)).left, first.left + 150);
    });

    testWidgets('$name: tapping an item fires item_click with its index',
        (tester) async {
      final backend = _Backend(platform);
      await _pump(tester, backend, {'item_extent': 150, 'on_item_click': true});
      await tester.tap(find.text('Item 1'));
      await tester.pumpAndSettle();
      expect(backend.events, [
        ['item_click', 1]
      ]);

      final quiet = _Backend(platform);
      await _pump(tester, quiet, {'item_extent': 150});
      await tester.tap(find.text('Item 1'));
      await tester.pumpAndSettle();
      expect(quiet.events, isEmpty);
    });

    testWidgets('$name: animate_to_item scrolls the item to the leading edge',
        (tester) async {
      final backend = _Backend(platform);
      final control =
          await _pump(tester, backend, {'item_extent': 150, 'padding': 0});
      final done = control.invokeMethod(
          'animate_to_item',
          {'index': 2, 'duration': 200, 'curve': 'ease_in_out'},
          const Duration(seconds: 1));
      await tester.pumpAndSettle();
      await done;
      expect(tester.takeException(), isNull);
      expect(tester.getRect(_itemFinder(2)).left, _carouselLeft(tester));

      // Out-of-range indexes clamp instead of throwing.
      final last = control.invokeMethod(
          'animate_to_item', {'index': 99}, const Duration(seconds: 1));
      await tester.pumpAndSettle();
      await last;
      expect(tester.takeException(), isNull);
      expect(tester.getRect(_itemFinder(4)).right,
          closeTo(_carouselLeft(tester) + 400, 0.5));
    });

    testWidgets('$name: initial_item starts on that item', (tester) async {
      final backend = _Backend(platform);
      await _pump(tester, backend,
          {'item_extent': 150, 'padding': 0, 'initial_item': 1});
      expect(tester.getRect(_itemFinder(1)).left, _carouselLeft(tester));
    });

    testWidgets('$name: item_snapping settles on a whole item', (tester) async {
      final backend = _Backend(platform);
      await _pump(tester, backend,
          {'item_extent': 150, 'padding': 0, 'item_snapping': true});
      await tester.drag(find.text('Item 1'), const Offset(-200, 0));
      await tester.pumpAndSettle();
      final left = _carouselLeft(tester);
      final aligned = [
        for (var i = 0; i < 5; i++)
          if (_itemFinder(i).evaluate().isNotEmpty)
            (tester.getRect(_itemFinder(i)).left - left).abs() < 0.5
      ];
      expect(aligned, contains(true));
      expect(tester.getRect(_itemFinder(1)).left, closeTo(left, 0.5));
    });

    testWidgets('$name: flex_weights sizes the leading item by its share',
        (tester) async {
      final backend = _Backend(platform);
      await _pump(tester, backend, {
        'flex_weights': [2, 1, 1],
        'padding': 0,
      });
      expect(tester.takeException(), isNull);
      expect(find.byType(ErrorControl), findsNothing);
      expect(tester.getRect(_itemFinder(0)).width, closeTo(200, 0.5));
      expect(tester.getRect(_itemFinder(0)).left, _carouselLeft(tester));
      if (platform == TargetPlatform.android) {
        final carousel = tester
            .widget<material.CarouselView>(find.byType(material.CarouselView));
        expect(carousel.flexWeights, [2, 1, 1]);
      } else {
        expect(find.byType(PageView), findsOneWidget);
        expect(find.byWidgetPredicate(_materialOnly), findsNothing);
      }
    });

    testWidgets('$name: vertical carousel stacks items by item_extent',
        (tester) async {
      final backend = _Backend(platform);
      await _pump(tester, backend,
          {'item_extent': 80, 'padding': 0, 'horizontal': false},
          width: 200, height: 300);
      final first = tester.getRect(_itemFinder(0));
      final second = tester.getRect(_itemFinder(1));
      expect(first.height, 80);
      expect(first.width, 200);
      expect(second.top, first.top + 80);
      expect(second.left, first.left);
    });

    testWidgets('$name: surface props reach the renderer', (tester) async {
      final backend = _Backend(platform);
      await _pump(tester, backend, {
        'item_extent': 150,
        'bgcolor': '#ff0000',
        'elevation': 3,
        'item_clip_behavior': 'hard_edge',
        'shape': {'_type': 'roundedRectangle', 'radius': 6},
        'reverse': true,
      });
      expect(tester.takeException(), isNull);
      if (platform == TargetPlatform.iOS) {
        final surface =
            tester.widget<PhysicalShape>(find.byType(PhysicalShape).first);
        expect(surface.color, const Color(0xffff0000));
        expect(surface.elevation, 3);
        expect(surface.clipBehavior, Clip.hardEdge);
        final shape = (surface.clipper as ShapeBorderClipper).shape
            as RoundedRectangleBorder;
        expect(shape.borderRadius, BorderRadius.circular(6));
        expect(find.byType(ListView), findsOneWidget);
        expect(tester.widget<ListView>(find.byType(ListView)).reverse, isTrue);
      } else {
        final carousel = tester
            .widget<material.CarouselView>(find.byType(material.CarouselView));
        expect(carousel.backgroundColor, const Color(0xffff0000));
        expect(carousel.elevation, 3);
        expect(carousel.itemClipBehavior, Clip.hardEdge);
        expect((carousel.shape as RoundedRectangleBorder).borderRadius,
            BorderRadius.circular(6));
        expect(carousel.reverse, isTrue);
      }
      // reverse: item 0 sits at the trailing (right) edge.
      expect(tester.getRect(_itemFinder(0)).right,
          closeTo(_carouselLeft(tester) + 400 - 4, 0.5));
    });

    if (platform == TargetPlatform.iOS) {
      testWidgets('iOS: default item surface is a 20 px rounded card',
          (tester) async {
        final backend = _Backend(platform);
        await _pump(tester, backend, {'item_extent': 150});
        final surface =
            tester.widget<PhysicalShape>(find.byType(PhysicalShape).first);
        final shape = (surface.clipper as ShapeBorderClipper).shape
            as RoundedRectangleBorder;
        expect(shape.borderRadius, BorderRadius.circular(20));
        expect(surface.clipBehavior, Clip.antiAlias);
        expect(surface.elevation, 0);
      });

      testWidgets('iOS: pressing an item dims it like a CupertinoButton',
          (tester) async {
        final backend = _Backend(platform);
        await _pump(
            tester, backend, {'item_extent': 150, 'on_item_click': true});
        final gesture =
            await tester.startGesture(tester.getCenter(find.text('Item 0')));
        await tester.pumpAndSettle();
        final dimmed = tester.widget<AnimatedOpacity>(find
            .ancestor(
                of: find.text('Item 0'), matching: find.byType(AnimatedOpacity))
            .first);
        expect(dimmed.opacity, 0.6);
        await gesture.up();
        await tester.pumpAndSettle();
        expect(backend.events, [
          ['item_click', 0]
        ]);
      });
    }

    testWidgets('$name: missing extent and unbounded height are errors',
        (tester) async {
      final backend = _Backend(platform);
      await _pump(tester, backend, {});
      expect(tester.takeException(), isNull);
      expect(find.byType(ErrorControl), findsOneWidget);
      expect(find.textContaining('item_extent'), findsWidgets);

      await _pump(tester, backend, {
        'flex_weights': [2, 0]
      });
      expect(find.byType(ErrorControl), findsOneWidget);

      await _pump(tester, backend, {'item_extent': 150}, height: null);
      expect(tester.takeException(), isNull);
      expect(find.byType(ErrorControl), findsOneWidget);
      expect(find.textContaining('bounded height'), findsOneWidget);
    });
  }
}
