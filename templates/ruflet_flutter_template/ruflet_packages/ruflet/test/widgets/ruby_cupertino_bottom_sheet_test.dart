import 'package:ruflet/ruflet.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' as material;
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'control_renderer_matrix_test.dart' show materialOnly;

class _Backend extends RufletBackend {
  final events = <String>[];
  _Backend(TargetPlatform target)
      : super(
            pageUri: Uri.parse('inprocess://bottom-sheet-test'),
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
  void triggerControlEvent(Control control, String name, [dynamic data]) =>
      events.add(name);
}

const _body = 'Sheet body';
const _topRadius = BorderRadius.vertical(top: Radius.circular(12));

Map<String, dynamic> _text([int id = 2]) =>
    {'_c': 'Text', '_i': id, 'value': _body};

Control _sheet(_Backend backend,
        [Map<String, dynamic> props = const {},
        Map<String, dynamic>? content]) =>
    Control.fromMap({
      '_c': 'BottomSheet',
      '_i': 1,
      'open': true,
      'content': content ?? _text(),
      ...props,
    }, backend);

Future<void> _show(WidgetTester tester, _Backend backend, Control sheet) async {
  final child = Center(child: ControlWidget(control: sheet));
  await tester.pumpWidget(ChangeNotifierProvider<RufletBackend>.value(
    value: backend,
    child: backend.platform == TargetPlatform.iOS
        ? CupertinoApp(home: CupertinoPageScaffold(child: child))
        : material.MaterialApp(home: material.Scaffold(body: child)),
  ));
  await tester.pumpAndSettle();
}

/// The rounded iOS popup surface (ClipRRect) that hosts the Ruby content.
Finder _surface() => find.ancestor(
    of: find.text(_body),
    matching: find.byWidgetPredicate(
        (w) => w is ClipRRect && w.borderRadius == _topRadius));

Color _surfaceColor(WidgetTester tester, Finder surface) => tester
    .widget<ColoredBox>(
        find.descendant(of: surface, matching: find.byType(ColoredBox)).first)
    .color;

Finder _grabber() => find
    .byWidgetPredicate((w) => w is SizedBox && w.width == 36 && w.height == 5);

void _expectCupertinoOnly(WidgetTester tester) {
  expect(find.byWidgetPredicate(materialOnly), findsNothing);
  expect(find.byType(material.BottomSheet), findsNothing);
  expect(tester.takeException(), isNull);
}

void main() {
  group('iOS BottomSheet', () {
    late _Backend backend;
    setUp(() => backend = _Backend(TargetPlatform.iOS));

    testWidgets('paints a rounded system surface around non-picker content',
        (tester) async {
      final sheet = _sheet(backend);
      await _show(tester, backend, sheet);

      expect(_surface(), findsOneWidget);
      final rect = tester.getRect(_surface());
      expect(rect.bottom, 600);
      expect(rect.width, 800);
      expect(_surfaceColor(tester, _surface()).toARGB32(), 0xFFFFFFFF);
      expect(_grabber(), findsNothing);
      // Presented as a popup inside the owning navigator, never the root one.
      expect(ModalRoute.of(tester.element(find.text(_body))),
          isA<CupertinoModalPopupRoute<void>>());
      _expectCupertinoOnly(tester);
    });

    testWidgets('bgcolor paints the sheet surface', (tester) async {
      await _show(tester, backend, _sheet(backend, {'bgcolor': '#123456'}));
      expect(_surfaceColor(tester, _surface()).toARGB32(), 0xFF123456);
      _expectCupertinoOnly(tester);
    });

    testWidgets('show_drag_handle adds a 36x5 grabber at the top',
        (tester) async {
      await _show(tester, backend, _sheet(backend, {'show_drag_handle': true}));
      expect(_grabber(), findsOneWidget);
      final grabber = tester.getRect(_grabber());
      final surface = tester.getRect(_surface());
      expect(grabber.size, const Size(36, 5));
      expect(grabber.center.dx, 400);
      expect(grabber.top, surface.top + 6);
      expect(tester.getTopLeft(find.text(_body)).dy,
          greaterThanOrEqualTo(grabber.bottom + 6));
      final decoration = tester
          .widget<DecoratedBox>(find.ancestor(
              of: _grabber(), matching: find.byType(DecoratedBox)))
          .decoration as BoxDecoration;
      expect(decoration.color!.toARGB32(),
          CupertinoColors.systemGrey3.color.toARGB32());
      expect(decoration.borderRadius, BorderRadius.circular(2.5));
      _expectCupertinoOnly(tester);
    });

    testWidgets('use_safe_area keeps content above the home indicator',
        (tester) async {
      tester.view.padding = const FakeViewPadding(bottom: 34 * 3);
      addTearDown(tester.view.reset);
      await _show(tester, backend, _sheet(backend));
      expect(tester.getRect(_surface()).bottom, 600);
      expect(tester.getBottomLeft(find.text(_body)).dy, closeTo(566, 0.01));
      _expectCupertinoOnly(tester);
    });

    testWidgets('use_safe_area: false lets content reach the bottom edge',
        (tester) async {
      tester.view.padding = const FakeViewPadding(bottom: 34 * 3);
      addTearDown(tester.view.reset);
      await _show(tester, backend, _sheet(backend, {'use_safe_area': false}));
      expect(tester.getBottomLeft(find.text(_body)).dy, closeTo(600, 0.01));
      _expectCupertinoOnly(tester);
    });

    testWidgets('keyboard inset lifts the surface above the keyboard',
        (tester) async {
      tester.view.viewInsets = const FakeViewPadding(bottom: 300 * 3);
      addTearDown(tester.view.reset);
      await _show(tester, backend, _sheet(backend));
      expect(tester.getRect(_surface()).bottom, 300);
      _expectCupertinoOnly(tester);
    });

    testWidgets(
        'maintain_bottom_view_insets_padding: false leaves the keyboard inset',
        (tester) async {
      tester.view.viewInsets = const FakeViewPadding(bottom: 300 * 3);
      addTearDown(tester.view.reset);
      await _show(tester, backend,
          _sheet(backend, {'maintain_bottom_view_insets_padding': false}));
      expect(tester.getRect(_surface()).bottom, 600);
      _expectCupertinoOnly(tester);
    });

    final tall = {
      '_c': 'Container',
      '_i': 2,
      'height': 2000,
      'content': _text(3),
    };

    testWidgets('non-scrollable sheets are capped at 9/16 of the screen',
        (tester) async {
      await _show(tester, backend, _sheet(backend, const {}, tall));
      expect(tester.getRect(_surface()).height, 600 * 9 / 16);
      _expectCupertinoOnly(tester);
    });

    testWidgets('scrollable sheets may grow up to the top safe inset',
        (tester) async {
      tester.view.padding = const FakeViewPadding(top: 47 * 3);
      addTearDown(tester.view.reset);
      await _show(tester, backend, _sheet(backend, {'scrollable': true}, tall));
      expect(tester.getRect(_surface()).top, 47);
      expect(tester.getRect(_surface()).bottom, 600);
      _expectCupertinoOnly(tester);
    });

    testWidgets('size_constraints bound the surface', (tester) async {
      await _show(
          tester,
          backend,
          _sheet(
              backend,
              {
                'size_constraints': {'max_height': 200, 'max_width': 500}
              },
              tall));
      expect(tester.getRect(_surface()).size, const Size(500, 200));
      expect(tester.getRect(_surface()).center.dx, 400);
      _expectCupertinoOnly(tester);
    });

    testWidgets('height fixes the surface and padding insets the content',
        (tester) async {
      await _show(
          tester,
          backend,
          _sheet(backend, {
            'height': 250,
            'padding': {'left': 16, 'top': 20}
          }));
      expect(tester.getRect(_surface()).height, 250);
      expect(
          tester.getTopLeft(find.text(_body)) - tester.getTopLeft(_surface()),
          const Offset(16, 20));
      _expectCupertinoOnly(tester);
    });

    testWidgets('drag past the threshold dismisses and fires dismiss',
        (tester) async {
      final sheet = _sheet(backend, {'draggable': true, 'height': 300});
      await _show(tester, backend, sheet);

      // 50px of a 300px sheet (< 25 %), slowly: springs back.
      await tester.timedDrag(find.text(_body), const Offset(0, 50),
          const Duration(milliseconds: 600));
      await tester.pumpAndSettle();
      expect(tester.getRect(_surface()).bottom, 600);
      expect(backend.events, isEmpty);

      // Mid-drag the surface follows the finger.
      final gesture =
          await tester.startGesture(tester.getCenter(find.text(_body)));
      await gesture.moveBy(const Offset(0, 20));
      await gesture.moveBy(const Offset(0, 40));
      await tester.pump();
      expect(tester.getRect(_surface()).bottom, greaterThan(630));
      await gesture.moveBy(const Offset(0, 60));
      await tester.pump(const Duration(milliseconds: 500));
      await gesture.up();
      await tester.pumpAndSettle();

      expect(_surface(), findsNothing);
      expect(sheet.get('open'), isFalse);
      expect(backend.events, ['dismiss']);
      _expectCupertinoOnly(tester);
    });

    testWidgets('a fast downward fling dismisses even a short drag',
        (tester) async {
      final sheet = _sheet(backend, {'draggable': true, 'height': 300});
      await _show(tester, backend, sheet);
      // 60px is 20 % of the sheet: only the 1500 px/s velocity dismisses it.
      await tester.fling(find.text(_body), const Offset(0, 60), 1500);
      await tester.pumpAndSettle();
      expect(_surface(), findsNothing);
      expect(backend.events, ['dismiss']);
      _expectCupertinoOnly(tester);
    });

    testWidgets('popups do not drag unless draggable is set (D-8)',
        (tester) async {
      final sheet = _sheet(backend, {'height': 300});
      await _show(tester, backend, sheet);
      await tester.fling(find.text(_body), const Offset(0, 250), 1500);
      await tester.pumpAndSettle();
      expect(tester.getRect(_surface()).bottom, 600);
      expect(sheet.get('open'), isTrue);
      expect(backend.events, isEmpty);
      _expectCupertinoOnly(tester);
    });

    testWidgets('scrollable sheets only drag from the top 44px',
        (tester) async {
      final sheet = _sheet(backend, {
        'draggable': true,
        'scrollable': true,
        'show_drag_handle': true
      }, {
        '_c': 'Container',
        '_i': 2,
        'height': 2000,
        'alignment': {'x': 0, 'y': 1},
        'content': _text(3),
      });
      await _show(tester, backend, sheet);
      final top = tester.getRect(_surface()).top;

      await tester.timedDragFrom(Offset(400, top + 200), const Offset(0, 300),
          const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(tester.getRect(_surface()).top, top);
      expect(backend.events, isEmpty);

      await tester.timedDragFrom(Offset(400, top + 10), const Offset(0, 300),
          const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(_surface(), findsNothing);
      expect(backend.events, ['dismiss']);
      _expectCupertinoOnly(tester);
    });

    testWidgets('barrier tap dismisses with a live barrier color',
        (tester) async {
      final sheet = _sheet(backend, {'barrier_color': '#88112233'});
      await _show(tester, backend, sheet);
      final barrier = find.byType(AnimatedModalBarrier).last;
      expect(tester.getRect(barrier), const Rect.fromLTWH(0, 0, 800, 600));
      expect(tester.widget<AnimatedModalBarrier>(barrier).color.value,
          const Color(0x88112233));
      sheet.updateProperties({'barrier_color': '#99123456'},
          python: false, notify: true);
      await tester.pumpAndSettle();
      expect(tester.widget<AnimatedModalBarrier>(barrier).color.value,
          const Color(0x99123456));
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(_surface(), findsNothing);
      expect(backend.events, ['dismiss']);
      _expectCupertinoOnly(tester);
    });

    for (final props in [
      {'modal': true},
      {'dismissible': false},
    ]) {
      testWidgets('$props keeps the sheet open on barrier tap', (tester) async {
        await _show(tester, backend, _sheet(backend, props));
        await tester.tapAt(const Offset(10, 10));
        await tester.pumpAndSettle();
        expect(_surface(), findsOneWidget);
        expect(backend.events, isEmpty);
        _expectCupertinoOnly(tester);
      });
    }

    testWidgets('open: false pops only the sheet and fires dismiss once',
        (tester) async {
      final sheet = _sheet(backend, {'open': false});
      await _show(tester, backend, sheet);
      expect(_surface(), findsNothing);

      sheet.updateProperties({'open': true}, python: false, notify: true);
      await tester.pumpAndSettle();
      expect(_surface(), findsOneWidget);
      sheet.updateProperties({'open': false}, python: false, notify: true);
      await tester.pumpAndSettle();
      expect(_surface(), findsNothing);
      expect(find.byType(CupertinoPageScaffold), findsOneWidget);
      expect(backend.events, ['dismiss']);

      // Rebuilds while the exit animation runs never pop a second route.
      final inner = GlobalKey<NavigatorState>();
      await tester.pumpWidget(ChangeNotifierProvider<RufletBackend>.value(
        value: backend,
        child: CupertinoApp(
          home: Navigator(
            key: inner,
            onGenerateRoute: (_) => CupertinoPageRoute<void>(
                builder: (_) => CupertinoPageScaffold(
                    child: Center(child: ControlWidget(control: sheet)))),
          ),
        ),
      ));
      inner.currentState!.push(CupertinoPageRoute<void>(
          builder: (_) => CupertinoPageScaffold(
              child: Center(child: ControlWidget(control: sheet)))));
      await tester.pumpAndSettle();
      sheet.updateProperties({'open': true}, python: false, notify: true);
      await tester.pumpAndSettle();
      expect(Navigator.of(tester.element(find.text(_body))),
          same(inner.currentState));
      sheet.updateProperties({'open': false}, python: false, notify: true);
      await tester.pump();
      sheet.updateProperties({'bgcolor': '#123456'},
          python: false, notify: true);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));
      sheet.updateProperties({'bgcolor': '#654321'},
          python: false, notify: true);
      await tester.pumpAndSettle();
      expect(_surface(), findsNothing);
      expect(inner.currentState!.canPop(), isTrue,
          reason: 'the pushed page under the sheet must survive');
      expect(backend.events, ['dismiss', 'dismiss']);
      backend.events.clear();

      // Closing while the entrance animation runs, then reopening, still works.
      sheet.updateProperties({'open': true}, python: false, notify: true);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      sheet.updateProperties({'open': false}, python: false, notify: true);
      await tester.pumpAndSettle();
      expect(_surface(), findsNothing);
      expect(backend.events, ['dismiss']);
      sheet.updateProperties({'open': true}, python: false, notify: true);
      await tester.pumpAndSettle();
      expect(_surface(), findsOneWidget);
      _expectCupertinoOnly(tester);
    });

    testWidgets('fullscreen presents the native iOS page sheet',
        (tester) async {
      final sheet = _sheet(backend,
          {'fullscreen': true, 'show_drag_handle': true, 'bgcolor': '#123456'});
      await _show(tester, backend, sheet);

      expect(find.byType(CupertinoSheetTransition), findsWidgets);
      expect(ModalRoute.of(tester.element(find.text(_body))),
          isA<CupertinoSheetRoute<void>>());
      expect(_grabber(), findsOneWidget);
      final surface = find
          .ancestor(of: find.text(_body), matching: find.byType(ColoredBox))
          .first;
      expect(tester.widget<ColoredBox>(surface).color, const Color(0xFF123456));
      final rect = tester.getRect(surface);
      expect(rect.width, 800);
      expect(rect.bottom, 600);
      expect(rect.height, greaterThan(500));
      _expectCupertinoOnly(tester);

      // Page sheets drag to dismiss by default (D-8).
      await tester.fling(find.text(_body), const Offset(0, 400), 2000);
      await tester.pumpAndSettle();
      expect(find.text(_body), findsNothing);
      expect(sheet.get('open'), isFalse);
      expect(backend.events, ['dismiss']);
    });

    testWidgets('fullscreen with draggable: false cannot be dragged away',
        (tester) async {
      final sheet = _sheet(backend, {'fullscreen': true, 'draggable': false});
      await _show(tester, backend, sheet);
      await tester.fling(find.text(_body), const Offset(0, 400), 2000);
      await tester.pumpAndSettle();
      expect(find.text(_body), findsOneWidget);
      expect(backend.events, isEmpty);

      sheet.updateProperties({'open': false}, python: false, notify: true);
      await tester.pumpAndSettle();
      expect(find.text(_body), findsNothing);
      expect(backend.events, ['dismiss']);
      _expectCupertinoOnly(tester);
    });

    testWidgets('picker content keeps the fixed-height picker panel',
        (tester) async {
      await _show(
          tester,
          backend,
          _sheet(backend, {'show_drag_handle': true},
              {'_c': 'TimerPicker', '_i': 2, 'value': 0}));
      final panel = find.ancestor(
          of: find.byType(CupertinoTimerPicker),
          matching: find.byType(Container));
      expect(tester.getRect(panel.first).height, 220);
      expect(_grabber(), findsNothing);
      _expectCupertinoOnly(tester);
    });
  });

  group('Android BottomSheet (Material path unchanged)', () {
    late _Backend backend;
    setUp(() => backend = _Backend(TargetPlatform.android));

    testWidgets('renders the Material sheet with its surface and handle',
        (tester) async {
      await _show(tester, backend,
          _sheet(backend, {'bgcolor': '#123456', 'show_drag_handle': true}));
      final sheet = tester
          .widget<material.BottomSheet>(find.byType(material.BottomSheet));
      expect(sheet.backgroundColor, const Color(0xFF123456));
      expect(sheet.showDragHandle, isTrue);
      expect(tester.getRect(find.byType(material.BottomSheet)).bottom, 600);
      expect(_surface(), findsNothing);
      expect(find.byType(CupertinoSheetTransition), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('keyboard inset pads the Material sheet content',
        (tester) async {
      tester.view.viewInsets = const FakeViewPadding(bottom: 300 * 3);
      addTearDown(tester.view.reset);
      await _show(tester, backend, _sheet(backend));
      expect(tester.getBottomLeft(find.text(_body)).dy, lessThanOrEqualTo(300));
      expect(tester.takeException(), isNull);
    });

    testWidgets('draggable: true drags the Material sheet away',
        (tester) async {
      final sheet = _sheet(backend, {'draggable': true});
      await _show(tester, backend, sheet);
      await tester.fling(find.text(_body), const Offset(0, 300), 1500);
      await tester.pumpAndSettle();
      expect(find.byType(material.BottomSheet), findsNothing);
      expect(sheet.get('open'), isFalse);
      expect(backend.events, ['dismiss']);
    });

    testWidgets('Material default does not drag', (tester) async {
      final sheet = _sheet(backend);
      await _show(tester, backend, sheet);
      await tester.fling(find.text(_body), const Offset(0, 300), 1500);
      await tester.pumpAndSettle();
      expect(find.byType(material.BottomSheet), findsOneWidget);
      expect(backend.events, isEmpty);
    });
  });
}
