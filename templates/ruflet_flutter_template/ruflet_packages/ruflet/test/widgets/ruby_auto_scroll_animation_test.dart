// Ruby's auto_scroll_animation (Flet 1.0.5): the animation auto_scroll moves
// to the end with, read by the shared ScrollableControl of every scrollable
// control, on both designs. ResponsiveRow and ExpansionPanelList gain the
// scroll surface (scroll, auto_scroll, scroll_to, on_scroll) they have in Flet.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:ruflet/ruflet.dart';
import 'package:ruflet/src/controls/scrollable_control.dart';

import '../support/control_harness.dart';

List<Map<String, dynamic>> _items(int count, {int col = 12}) => [
      for (var i = 0; i < count; i++)
        {
          '_c': 'Container',
          '_i': 1000 + i,
          'height': 50,
          'width': 50,
          'col': col,
          'content': {'_c': 'Text', '_i': 2000 + i, 'value': 'Item $i'},
        }
    ];

List<Map<String, dynamic>> _panels(int count) => [
      for (var i = 0; i < count; i++)
        {
          '_c': 'ExpansionPanel',
          '_i': 3000 + i,
          'expanded': true,
          'header': {'_c': 'Text', '_i': 4000 + i, 'value': 'Panel $i'},
          'content': {
            '_c': 'Container',
            '_i': 5000 + i,
            'height': 80,
            'content': {'_c': 'Text', '_i': 6000 + i, 'value': 'Body $i'},
          },
        }
    ];

Map<String, dynamic> _fixture(String type) => switch (type) {
      'ListView' => {'_c': 'ListView', '_i': 1, 'controls': _items(30)},
      'GridView' => {
          '_c': 'GridView',
          '_i': 1,
          'runs_count': 3,
          'controls': _items(60)
        },
      'Column' => {
          '_c': 'Column',
          '_i': 1,
          'scroll': 'auto',
          'controls': _items(30)
        },
      'Row' => {'_c': 'Row', '_i': 1, 'scroll': 'auto', 'controls': _items(30)},
      'ReorderableListView' => {
          '_c': 'ReorderableListView',
          '_i': 1,
          'expand': true,
          'controls': _items(30)
        },
      'CustomScrollView' => {
          '_c': 'CustomScrollView',
          '_i': 1,
          'slivers': [
            {'_c': 'SliverList', '_i': 2, 'controls': _items(30)}
          ],
        },
      'ResponsiveRow' => {
          '_c': 'ResponsiveRow',
          '_i': 1,
          'scroll': 'auto',
          'controls': _items(30, col: 6),
        },
      'ExpansionPanelList' => {
          '_c': 'ExpansionPanelList',
          '_i': 1,
          'scroll': 'auto',
          'controls': _panels(8),
        },
      _ => throw ArgumentError(type),
    };

const _types = [
  'ListView',
  'GridView',
  'Column',
  'Row',
  'ReorderableListView',
  'CustomScrollView',
  'ResponsiveRow',
  'ExpansionPanelList',
];

/// The scroll position the control's ScrollableControl drives.
ScrollPosition _position(WidgetTester tester) => tester
    .state<ScrollableState>(find
        .descendant(
            of: find.byType(ScrollableControl),
            matching: find.byType(Scrollable))
        .first)
    .position;

Future<Control> _mount(WidgetTester tester, HarnessDesign design,
    Map<String, dynamic> wire) async {
  final backend = HarnessBackend(design);
  final control = Control.fromMap(copyWire(wire), backend);
  await tester.pumpWidget(harnessApp(
      backend,
      design,
      SizedBox(
          width: 300, height: 200, child: ControlWidget(control: control))));
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
  return control;
}

/// Mounts the View on the Page, as a Ruby session does.
Future<Control> _mountView(WidgetTester tester, HarnessDesign design) async {
  final backend = HarnessBackend(design)..isLoading = false;
  final view = Control.fromMap({
    '_c': 'View',
    '_i': 20,
    'route': '/',
    'scroll': 'auto',
    '_internals': {'host_expanded': true},
    'controls': _items(40),
  }, backend, parent: backend.page);
  backend.page.update({
    'platform': design.platform.name,
    'views': [view]
  }, shouldNotify: true);
  await tester.binding.setSurfaceSize(const Size(400, 300));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(ChangeNotifierProvider<RufletBackend>.value(
      value: backend, child: ControlWidget(control: backend.page)));
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
  return view;
}

/// Turns auto_scroll on (from the top) with [animation] and checks how the
/// position reaches the end: by [mid] it is under way, by [end] it is there.
Future<void> _expectAutoScroll(
    WidgetTester tester, Control control, Object? animation,
    {required Duration mid, required Duration end}) async {
  final position = _position(tester);
  position.jumpTo(0);
  await tester.pump();
  control.update({'auto_scroll': true, 'auto_scroll_animation': animation},
      shouldNotify: true);
  await tester.pump(); // builds; auto_scroll starts after the frame
  final max = position.maxScrollExtent;
  expect(max, greaterThan(100), reason: 'the fixture scrolls');
  if (mid == Duration.zero) {
    expect(position.pixels, max, reason: '$animation jumps to the end');
  } else {
    await tester.pump(); // the animation's first tick is its time zero
    await tester.pump(mid);
    expect(position.pixels, allOf(greaterThan(0), lessThan(max)),
        reason: '$animation is animating at $mid');
    await tester.pump(end - mid);
    expect(position.pixels, max, reason: '$animation reached the end by $end');
  }
  control.update({'auto_scroll': false}, shouldNotify: true);
  await tester.pumpAndSettle();
}

Future<void> _expectAllAnimations(WidgetTester tester, Control control) async {
  // Flet's default: one second, ease.
  await _expectAutoScroll(tester, control, null,
      mid: const Duration(milliseconds: 500),
      end: const Duration(milliseconds: 1100));
  await _expectAutoScroll(
      tester, control, {'duration': 200, 'curve': 'easeOut'},
      mid: const Duration(milliseconds: 100),
      end: const Duration(milliseconds: 250));
  // An int is a duration in milliseconds; 0 (or false) jumps.
  await _expectAutoScroll(tester, control, 400,
      mid: const Duration(milliseconds: 200),
      end: const Duration(milliseconds: 450));
  await _expectAutoScroll(tester, control, 0,
      mid: Duration.zero, end: Duration.zero);
  await _expectAutoScroll(tester, control, false,
      mid: Duration.zero, end: Duration.zero);
  await _expectAutoScroll(tester, control, {'duration': 0},
      mid: Duration.zero, end: Duration.zero);
  expect(tester.takeException(), isNull);
}

void main() {
  for (final design in HarnessDesign.values) {
    for (final type in _types) {
      testWidgets('${design.name}: $type honors auto_scroll_animation',
          (tester) async {
        final control = await _mount(tester, design, _fixture(type));
        await _expectAllAnimations(tester, control);
      });
    }

    testWidgets('${design.name}: View honors auto_scroll_animation',
        (tester) async {
      final view = await _mountView(tester, design);
      await _expectAllAnimations(tester, view);
    });

    for (final type in ['ResponsiveRow', 'ExpansionPanelList']) {
      testWidgets(
          '${design.name}: $type scrolls, answers scroll_to and '
          'reports on_scroll', (tester) async {
        final wire = _fixture(type)..['on_scroll'] = true;
        final mount = await mountWire(
            tester,
            design,
            {
              '_c': 'Container',
              '_i': 900,
              'width': 300,
              'height': 200,
              'content': wire,
            },
            surface: const Size(400, 400));
        final control = mount.control(1);
        final position = _position(tester);
        expect(position.maxScrollExtent, greaterThan(100));

        final outcome = await invokeOutcome(tester, control, 'scroll_to',
            args: {'offset': 60}, timeout: const Duration(seconds: 1));
        expect(outcome.error, isNull);
        expect(position.pixels, 60);

        await tester.drag(find.byType(ScrollableControl), const Offset(0, -40));
        await tester.pumpAndSettle();
        expect(
            mount.backend.sent
                .where((m) => m.id == 1 && m.name == 'scroll')
                .isNotEmpty,
            isTrue,
            reason: 'on_scroll is reported');
        expect(tester.takeException(), isNull);
      });

      testWidgets('${design.name}: $type without scroll lays out unchanged',
          (tester) async {
        final wire = _fixture(type)..remove('scroll');
        await _mount(tester, design, {
          '_c': 'Column',
          '_i': 900,
          'scroll': 'auto',
          'controls': [wire],
        });
        expect(
            find.descendant(
                of: find.byType(ScrollableControl).at(1),
                matching: find.byType(Scrollable)),
            findsNothing,
            reason: 'no scroll view of its own without scroll');
      });
    }
  }
}
