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
            pageUri: Uri.parse('inprocess://custom-scroll-view-test'),
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
    events.add(name);
  }
}

int _ids = 1000;

Map<String, dynamic> _node(String type,
        [Map<String, dynamic> props = const {}]) =>
    {'_c': type, '_i': ++_ids, ...props};

Map<String, dynamic> _text(String value) => _node('Text', {'value': value});

/// A fixed-height box the test can locate by its Ruby `key`.
Map<String, dynamic> _box(String key, double height, {String? label}) =>
    _node('Container', {
      'key': key,
      'height': height,
      'bgcolor': '#dddddd',
      if (label != null) 'content': _text(label),
    });

Widget _host(RufletBackend backend, Control control,
    {double width = 400, double height = 600}) {
  final body = Align(
    alignment: Alignment.topLeft,
    child: SizedBox(
        width: width, height: height, child: ControlWidget(control: control)),
  );
  return ChangeNotifierProvider<RufletBackend>.value(
    value: backend,
    child: backend.platform == TargetPlatform.iOS
        ? CupertinoApp(home: body)
        : material.MaterialApp(home: body),
  );
}

// The item ControlWidget and the control it builds share the Ruby key.
// Ruby keys arrive as ValueKey<Object>.
Finder _byKey(String key) => find.byKey(ValueKey<Object>(key));

Rect _rect(WidgetTester tester, String key) =>
    tester.getRect(_byKey(key).first);

ScrollPosition _position(WidgetTester tester) =>
    tester.state<ScrollableState>(find.byType(Scrollable).first).position;

Future<void> _scrollTo(
    WidgetTester tester, Control control, double offset) async {
  await control.invokeMethod(
      'scroll_to', {'offset': offset}, const Duration(seconds: 1));
  await tester.pump();
}

void main() {
  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    final design = platform == TargetPlatform.iOS ? 'Cupertino' : 'Material';

    testWidgets('$design lays slivers out in order with a two-column grid',
        (tester) async {
      final backend = _Backend(platform);
      final control = Control.fromMap(
          _node('CustomScrollView', {
            'slivers': [
              _node('SliverToBoxAdapter', {'content': _box('box', 50)}),
              _node('SliverList', {
                'controls': [_box('a0', 40), _box('a1', 40), _box('a2', 40)],
              }),
              _node('SliverGrid', {
                'runs_count': 2,
                'spacing': 10,
                'run_spacing': 20,
                'child_aspect_ratio': 2.0,
                'controls': [
                  _box('g0', 10),
                  _box('g1', 10),
                  _box('g2', 10),
                ],
              }),
              _text('Auto-wrapped'),
              _node('SliverFillRemaining', {'content': _box('fill', 10)}),
            ],
          }),
          backend);
      await tester.pumpWidget(_host(backend, control));
      expect(tester.takeException(), isNull);
      expect(find.byType(ErrorControl), findsNothing);
      expect(find.byType(CustomScrollView), findsOneWidget);

      // Order: box, list items, grid rows, auto-wrapped text, fill.
      expect(_rect(tester, 'box'), const Rect.fromLTWH(0, 0, 400, 50));
      expect(_rect(tester, 'a0'), const Rect.fromLTWH(0, 50, 400, 40));
      expect(_rect(tester, 'a1').top, 90);
      expect(_rect(tester, 'a2').top, 130);

      // Grid: 2 tiles per row, run_spacing between columns, spacing between
      // rows, aspect ratio 2.0 fixes the tile height.
      const tileWidth = (400 - 20) / 2;
      expect(_rect(tester, 'g0'),
          const Rect.fromLTWH(0, 170, tileWidth, tileWidth / 2));
      expect(_rect(tester, 'g1'),
          const Rect.fromLTWH(tileWidth + 20, 170, tileWidth, tileWidth / 2));
      expect(_rect(tester, 'g2').topLeft,
          const Offset(0, 170 + tileWidth / 2 + 10));

      final gridBottom = _rect(tester, 'g2').bottom;
      expect(find.text('Auto-wrapped'), findsOneWidget);
      final autoWrapped = tester.getRect(find.text('Auto-wrapped'));
      expect(autoWrapped.top, gridBottom);

      // Fill remaining takes the rest of the 600px viewport.
      final fill = _rect(tester, 'fill');
      expect(fill.top, autoWrapped.bottom);
      expect(fill.bottom, 600);

      if (platform == TargetPlatform.iOS) {
        expect(find.byWidgetPredicate(materialOnly), findsNothing);
      }
    });

    testWidgets('$design fill-remaining takes exactly the leftover height',
        (tester) async {
      final backend = _Backend(platform);
      final control = Control.fromMap(
          _node('CustomScrollView', {
            'slivers': [
              _node('SliverToBoxAdapter', {'content': _box('top', 100)}),
              _node('SliverFillRemaining', {
                'content': _box('fill', 20, label: 'Empty state'),
              }),
            ],
          }),
          backend);
      await tester.pumpWidget(_host(backend, control));
      expect(_rect(tester, 'fill'), const Rect.fromLTWH(0, 100, 400, 500));
      // Nothing to scroll: the filler exactly fits.
      expect(_position(tester).maxScrollExtent, 0);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        '$design sticky section headers pin, then leave with their group',
        (tester) async {
      final backend = _Backend(platform);
      final control = Control.fromMap(
          _node('CustomScrollView', {
            'slivers': [
              _node('SliverList', {
                'header': _box('h1', 30, label: 'Today'),
                'sticky_header': true,
                'controls': [
                  for (var i = 0; i < 20; i++) _box('a$i', 50),
                ],
              }),
              _node('SliverList', {
                'header': _box('h2', 30, label: 'Earlier'),
                'sticky_header': true,
                'controls': [
                  for (var i = 0; i < 20; i++) _box('b$i', 50),
                ],
              }),
            ],
          }),
          backend);
      await tester.pumpWidget(_host(backend, control, height: 300));
      expect(_rect(tester, 'h1').top, 0);
      expect(_rect(tester, 'a0').top, 30);

      // Items scroll under the pinned header.
      await _scrollTo(tester, control, 200);
      expect(_rect(tester, 'h1'), const Rect.fromLTWH(0, 0, 400, 30));
      expect(_rect(tester, 'a4').top, 30 + 4 * 50 - 200);

      // Group 1 is 30 + 20 * 50 = 1030 tall: at 1020 its end pushes the
      // header up and the next section's header follows right below.
      await _scrollTo(tester, control, 1020);
      expect(_rect(tester, 'h1').bottom, 10);
      expect(_rect(tester, 'h2').top, 10);

      // Past the group, the second header is the pinned one.
      await _scrollTo(tester, control, 1200);
      expect(_byKey('h1'), findsNothing);
      expect(_rect(tester, 'h2'), const Rect.fromLTWH(0, 0, 400, 30));
      expect(tester.takeException(), isNull);
    });

    testWidgets('$design non-sticky headers scroll away with their items',
        (tester) async {
      final backend = _Backend(platform);
      final control = Control.fromMap(
          _node('CustomScrollView', {
            'slivers': [
              _node('SliverGrid', {
                'header': _box('h', 30),
                'runs_count': 3,
                'controls': [
                  for (var i = 0; i < 30; i++) _box('g$i', 10),
                ],
              }),
            ],
          }),
          backend);
      await tester.pumpWidget(_host(backend, control, height: 300));
      await _scrollTo(tester, control, 20);
      expect(_rect(tester, 'h').top, -20);
      expect(tester.takeException(), isNull);
    });

    testWidgets('$design list spacing, padding and background are honored',
        (tester) async {
      final backend = _Backend(platform);
      final control = Control.fromMap(
          _node('CustomScrollView', {
            'slivers': [
              _node('SliverList', {
                'spacing': 8,
                'padding': {'left': 16, 'top': 12, 'right': 16, 'bottom': 0},
                'bgcolor': '#ff0000',
                'controls': [_box('a0', 40), _box('a1', 40)],
              }),
              _node('SliverList', {
                'item_extent': 25,
                'build_controls_on_demand': false,
                'controls': [_box('c0', 40), _box('c1', 40)],
              }),
            ],
          }),
          backend);
      await tester.pumpWidget(_host(backend, control));
      expect(_rect(tester, 'a0'), const Rect.fromLTWH(16, 12, 368, 40));
      expect(_rect(tester, 'a1').top, 12 + 40 + 8);
      expect(find.byType(DecoratedSliver), findsOneWidget);
      // item_extent forces every row to 25px.
      expect(_rect(tester, 'c0'), const Rect.fromLTWH(0, 100, 400, 25));
      expect(_rect(tester, 'c1').top, 125);
      expect(tester.takeException(), isNull);
    });

    testWidgets('$design scroll_to reaches the end and on_scroll fires',
        (tester) async {
      final backend = _Backend(platform);
      final control = Control.fromMap(
          _node('CustomScrollView', {
            'on_scroll': true,
            'scroll_interval': 0,
            'slivers': [
              _node('SliverList', {
                'controls': [
                  for (var i = 0; i < 40; i++) _box('a$i', 50),
                ],
              }),
            ],
          }),
          backend);
      await tester.pumpWidget(_host(backend, control));
      await _scrollTo(tester, control, -1);
      final position = _position(tester);
      expect(position.pixels, position.maxScrollExtent);
      expect(position.maxScrollExtent, 40 * 50 - 600);
      expect(_rect(tester, 'a39').bottom, 600);
      expect(backend.events, contains('scroll'));
      expect(tester.takeException(), isNull);
    });

    testWidgets('$design rebuilds a sliver when Ruby patches it',
        (tester) async {
      final backend = _Backend(platform);
      final control = Control.fromMap(
          _node('CustomScrollView', {
            'slivers': [
              _node('SliverToBoxAdapter', {'content': _box('top', 20)}),
              _node('SliverList', {
                'controls': [_box('a0', 40)],
              }),
            ],
          }),
          backend);
      await tester.pumpWidget(_host(backend, control));
      final list = control.children('slivers')[1];
      list.update({
        'controls': [_box('a0', 40), _box('a1', 40)]
      }, shouldNotify: true);
      await tester.pump();
      expect(_rect(tester, 'a1').top, 60);

      final top = control.children('slivers')[0];
      top.update({'visible': false}, shouldNotify: true);
      await tester.pump();
      expect(_byKey('top'), findsNothing);
      expect(_rect(tester, 'a0').top, 0);
      expect(tester.takeException(), isNull);
    });

    testWidgets('$design falls back to block children in controls',
        (tester) async {
      final backend = _Backend(platform);
      final control = Control.fromMap(
          _node('CustomScrollView', {
            'controls': [
              _node('SliverList', {
                'controls': [_box('a0', 40)],
              }),
              _text('Block text'),
            ],
          }),
          backend);
      await tester.pumpWidget(_host(backend, control));
      expect(_rect(tester, 'a0').top, 0);
      expect(tester.getTopLeft(find.text('Block text')).dy, 40);
      expect(tester.takeException(), isNull);
    });

    testWidgets('$design shrink-wraps in an unbounded column', (tester) async {
      final backend = _Backend(platform);
      final control = Control.fromMap(
          _node('Column', {
            'scroll': 'auto',
            'controls': [
              _node('CustomScrollView', {
                'slivers': [
                  _node('SliverList', {
                    'controls': [_box('a0', 40), _box('a1', 40)],
                  }),
                  _node('SliverFillRemaining', {'content': _box('fill', 30)}),
                ],
              }),
              _box('after', 10),
            ],
          }),
          backend);
      await tester.pumpWidget(_host(backend, control));
      expect(tester.takeException(), isNull);
      // The filler cannot fill an unbounded viewport; it becomes a box.
      expect(_rect(tester, 'fill'), const Rect.fromLTWH(0, 80, 400, 30));
      // Column spacing (10) follows the 110px shrink-wrapped scroll view.
      expect(_rect(tester, 'after').top, 120);
    });

    testWidgets('$design horizontal scroll view honors axis and reverse',
        (tester) async {
      final backend = _Backend(platform);
      final control = Control.fromMap(
          _node('Column', {
            'spacing': 0,
            'controls': [
              _node('CustomScrollView', {
                'horizontal': true,
                'height': 100,
                'slivers': [
                  _node('SliverList', {
                    'controls': [
                      for (var i = 0; i < 3; i++)
                        _node('Container', {'key': 'h$i', 'width': 120}),
                    ],
                  }),
                ],
              }),
            ],
          }),
          backend);
      await tester.pumpWidget(_host(backend, control));
      expect(_rect(tester, 'h0'), const Rect.fromLTWH(0, 0, 120, 100));
      expect(_rect(tester, 'h1').left, 120);

      final reversed = Control.fromMap(
          _node('CustomScrollView', {
            'reverse': true,
            'slivers': [
              _node('SliverList', {
                'controls': [_box('r0', 40), _box('r1', 40)],
              }),
            ],
          }),
          backend);
      await tester.pumpWidget(_host(backend, reversed));
      expect(_rect(tester, 'r0'), const Rect.fromLTWH(0, 560, 400, 40));
      expect(_rect(tester, 'r1').top, 520);

      final unbounded = Control.fromMap(
          _node('Column', {
            'scroll': 'auto',
            'controls': [
              _node('CustomScrollView', {
                'horizontal': true,
                'slivers': [_text('x')]
              }),
            ],
          }),
          backend);
      await tester.pumpWidget(_host(backend, unbounded));
      expect(find.byType(ErrorControl), findsOneWidget);
    });
  }
}
