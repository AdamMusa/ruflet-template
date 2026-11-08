import 'package:ruflet/ruflet.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' as material;
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'control_renderer_matrix_test.dart' show materialOnly;

class _Backend extends RufletBackend {
  final events = <(String, dynamic)>[];
  _Backend(TargetPlatform target)
      : super(
            pageUri: Uri.parse('inprocess://draggable-sheet-test'),
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
  void triggerControlEventById(int controlId, String eventName,
          [dynamic eventData]) =>
      events.add((eventName, eventData));

  List<Map> get extents => [
        for (final (name, data) in events)
          if (name == 'extent_change') data as Map
      ];
}

Control _sheet(_Backend backend, [Map<String, dynamic> props = const {}]) =>
    Control.fromMap({
      '_c': 'DraggableScrollableSheet',
      '_i': 1,
      'on_extent_change': true,
      'header': {'_c': 'Text', '_i': 2, 'value': 'Nearby'},
      'controls': [
        for (var i = 0; i < 30; i++)
          {'_c': 'Text', '_i': 10 + i, 'value': 'Place $i'}
      ],
      ...props,
    }, backend);

Future<void> _show(WidgetTester tester, _Backend backend, Control sheet) async {
  final child = SizedBox.expand(child: ControlWidget(control: sheet));
  await tester.pumpWidget(ChangeNotifierProvider<RufletBackend>.value(
    value: backend,
    child: backend.platform == TargetPlatform.iOS
        ? CupertinoApp(
            home: CupertinoPageScaffold(
                backgroundColor: const Color(0xFF00FF00), child: child))
        : material.MaterialApp(home: material.Scaffold(body: child)),
  ));
  await tester.pumpAndSettle();
}

bool _ios(_Backend backend) => backend.platform == TargetPlatform.iOS;

/// The visible sheet surface: the shadowed DecoratedBox on iOS, the Material
/// on Android.
Finder _surface(_Backend backend) => _ios(backend)
    ? find.byWidgetPredicate((w) =>
        w is DecoratedBox &&
        w.decoration is BoxDecoration &&
        (w.decoration as BoxDecoration).boxShadow != null)
    : find
        .descendant(
            of: find.byType(DraggableScrollableSheet),
            matching: find.byType(material.Material))
        .first;

Finder _handle(_Backend backend) => find.byWidgetPredicate((w) =>
    w is SizedBox &&
    (_ios(backend)
        ? w.width == 36 && w.height == 5
        : w.width == 32 && w.height == 4));

double _height(WidgetTester tester, _Backend backend) =>
    tester.getRect(_surface(backend)).height;

void main() {
  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    group('$platform DraggableScrollableSheet', () {
      late _Backend backend;
      setUp(() => backend = _Backend(platform));

      testWidgets('starts at initial_child_size with surface, handle, header',
          (tester) async {
        await _show(tester, backend, _sheet(backend));

        final surface = tester.getRect(_surface(backend));
        expect(surface.height, 300);
        expect(surface.bottom, 600);
        expect(surface.width, 800);

        expect(_handle(backend), findsOneWidget);
        final handle = tester.getRect(_handle(backend));
        expect(handle.center.dx, 400);
        expect(handle.top, surface.top + (_ios(backend) ? 6 : 22));
        expect(tester.getTopLeft(find.text('Nearby')).dy,
            greaterThanOrEqualTo(handle.bottom));
        expect(find.text('Place 0'), findsOneWidget);
        expect(tester.getTopLeft(find.text('Place 0')).dy,
            greaterThanOrEqualTo(tester.getBottomLeft(find.text('Nearby')).dy));

        if (_ios(backend)) {
          final decoration = tester
              .widget<DecoratedBox>(_surface(backend))
              .decoration as BoxDecoration;
          expect(decoration.color!.toARGB32(), 0xFFFFFFFF);
          expect(decoration.borderRadius,
              const BorderRadius.vertical(top: Radius.circular(12)));
          expect(decoration.boxShadow!.single.blurRadius, 12);
          expect(
              find.ancestor(
                  of: find.text('Place 0'),
                  matching: find.byWidgetPredicate((w) =>
                      w is ClipRRect &&
                      w.borderRadius ==
                          const BorderRadius.vertical(
                              top: Radius.circular(12)))),
              findsOneWidget);
          expect(find.byWidgetPredicate(materialOnly), findsNothing);
        } else {
          final sheet = tester.widget<material.Material>(_surface(backend));
          expect(sheet.elevation, 1);
          expect((sheet.shape as material.RoundedRectangleBorder).borderRadius,
              const BorderRadius.vertical(top: Radius.circular(28)));
          expect(find.byType(CupertinoPageScaffold), findsNothing);
        }
        expect(tester.takeException(), isNull);
      });

      testWidgets('bgcolor, border_radius and show_drag_handle: false',
          (tester) async {
        await _show(
            tester,
            backend,
            _sheet(backend, {
              'bgcolor': '#123456',
              'border_radius': 20,
              'show_drag_handle': false,
            }));
        expect(_handle(backend), findsNothing);
        if (_ios(backend)) {
          final decoration = tester
              .widget<DecoratedBox>(_surface(backend))
              .decoration as BoxDecoration;
          expect(decoration.color, const Color(0xFF123456));
          expect(decoration.borderRadius, BorderRadius.circular(20));
          expect(find.byWidgetPredicate(materialOnly), findsNothing);
        } else {
          final sheet = tester.widget<material.Material>(_surface(backend));
          expect(sheet.color, const Color(0xFF123456));
          expect((sheet.shape as material.RoundedRectangleBorder).borderRadius,
              BorderRadius.circular(20));
        }
        // Without a handle the header is the first thing on the surface.
        expect(tester.getTopLeft(find.text('Nearby')).dy,
            tester.getRect(_surface(backend)).top);
        expect(tester.takeException(), isNull);
      });

      testWidgets('padding and spacing lay out the list', (tester) async {
        await _show(
            tester,
            backend,
            _sheet(backend, {
              'show_drag_handle': false,
              'padding': {'left': 16, 'top': 8, 'right': 16, 'bottom': 0},
              'spacing': 10,
            }));
        final header = tester.getRect(find.text('Nearby'));
        final first = tester.getRect(find.text('Place 0'));
        final second = tester.getRect(find.text('Place 1'));
        expect(first.left, 16);
        expect(first.top, header.bottom + 8);
        expect(second.top, first.bottom + 10);
        expect(tester.takeException(), isNull);
      });

      testWidgets('dragging the header grows the sheet and fires extent_change',
          (tester) async {
        await _show(tester, backend, _sheet(backend));
        expect(backend.extents, isEmpty);

        await tester.timedDrag(find.text('Nearby'), const Offset(0, -220),
            const Duration(milliseconds: 600));
        await tester.pumpAndSettle();

        final height = _height(tester, backend);
        expect(height, greaterThan(480));
        expect(backend.extents, isNotEmpty);
        final last = backend.extents.last;
        expect(last['extent'], closeTo(height / 600, 0.001));
        expect(last['min'], 0.25);
        expect(last['max'], 1.0);
        // Throttled: a 600 ms drag must not send one event per frame.
        expect(backend.extents.length, lessThan(20));
        expect(tester.takeException(), isNull);
      });

      testWidgets('without on_extent_change no event is sent', (tester) async {
        await _show(
            tester, backend, _sheet(backend, {'on_extent_change': null}));
        await tester.timedDrag(find.text('Nearby'), const Offset(0, -150),
            const Duration(milliseconds: 300));
        await tester.pumpAndSettle();
        expect(_height(tester, backend), greaterThan(400));
        expect(backend.events, isEmpty);
      });

      for (final (drag, expected) in [
        (-120.0, 300.0), // ~0.70 -> nearest snap 0.5
        (-200.0, 600.0), // ~0.83 -> max 1.0
        (100.0, 150.0), // ~0.33 -> min 0.25
      ]) {
        testWidgets('snap with snap_sizes settles drag $drag on $expected',
            (tester) async {
          await _show(
              tester,
              backend,
              _sheet(backend, {
                'snap': true,
                'snap_sizes': [0.5],
              }));
          await tester.timedDrag(find.text('Nearby'), Offset(0, drag),
              const Duration(milliseconds: 800));
          await tester.pumpAndSettle();
          expect(_height(tester, backend), closeTo(expected, 0.5));
          expect(
              backend.extents.last['extent'], closeTo(expected / 600, 0.001));
          expect(tester.takeException(), isNull);
        });
      }

      testWidgets('invalid snap_sizes are sanitised instead of asserting',
          (tester) async {
        await _show(
            tester,
            backend,
            _sheet(backend, {
              'snap': true,
              'min_child_size': 0.2,
              'max_child_size': 0.9,
              'initial_child_size': 2,
              'snap_sizes': [0.95, 0.6, 'x', 0.2, 0.1, 0.6],
            }));
        // initial_child_size is clamped into [min, max].
        expect(_height(tester, backend), closeTo(540, 0.5));
        await tester.timedDrag(find.text('Nearby'), const Offset(0, 150),
            const Duration(milliseconds: 800));
        await tester.pumpAndSettle();
        expect(_height(tester, backend), closeTo(360, 0.5));
        expect(tester.takeException(), isNull);
      });

      testWidgets('animate_to and jump_to drive the sheet', (tester) async {
        final sheet = _sheet(backend);
        await _show(tester, backend, sheet);

        final animate = sheet.invokeMethod('animate_to',
            {'size': 1.0, 'duration': 200}, const Duration(seconds: 1));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        expect(_height(tester, backend), inExclusiveRange(300, 600));
        await tester.pumpAndSettle();
        expect(await animate, isNull);
        expect(_height(tester, backend), 600);

        sheet.invokeMethod(
            'jump_to', {'size': 0.25}, const Duration(seconds: 1));
        await tester.pumpAndSettle();
        expect(_height(tester, backend), 150);
        expect(backend.extents.last['extent'], 0.25);

        // Methods other listeners own are ignored.
        expect(
            await sheet.invokeMethod(
                'scroll_to', {'offset': 10}, const Duration(seconds: 1)),
            isNull);
        expect(tester.takeException(), isNull);
      });

      testWidgets('keeps its extent across Ruby updates', (tester) async {
        final sheet = _sheet(backend, {
          'snap': true,
          'snap_sizes': [0.5]
        });
        await _show(tester, backend, sheet);
        sheet.invokeMethod(
            'jump_to', {'size': 1.0}, const Duration(seconds: 1));
        await tester.pumpAndSettle();
        sheet.updateProperties({
          'bgcolor': '#654321',
          'snap_sizes': [0.5]
        }, python: false, notify: true);
        await tester.pumpAndSettle();
        expect(_height(tester, backend), 600);
        expect(tester.takeException(), isNull);
      });

      testWidgets('an unbounded parent renders an error instead of crashing',
          (tester) async {
        final sheet = _sheet(backend);
        await tester.pumpWidget(ChangeNotifierProvider<RufletBackend>.value(
          value: backend,
          child: _ios(backend)
              ? CupertinoApp(
                  home: SingleChildScrollView(
                      child: ControlWidget(control: sheet)))
              : material.MaterialApp(
                  home: SingleChildScrollView(
                      child: ControlWidget(control: sheet))),
        ));
        await tester.pump();
        expect(find.byType(ErrorControl), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    });
  }
}
