import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ruflet/ruflet.dart';
import 'package:ruflet/src/controls/adaptive_sliver_app_bar.dart';
import 'package:ruflet/src/widgets/platform_scrollbar.dart';

import '../support/control_harness.dart';

int _ids = 7000;

Map<String, dynamic> _node(String type,
        [Map<String, dynamic> props = const {}]) =>
    {'_c': type, '_i': ++_ids, ...props};

Map<String, dynamic> _text(String value) => _node('Text', {'value': value});

Map<String, dynamic> _box(String key, double height) =>
    _node('Container', {'key': key, 'height': height, 'bgcolor': '#dddddd'});

List<Map<String, dynamic>> _rows(String prefix) =>
    [for (var i = 0; i < 40; i++) _box('$prefix$i', 50)];

Map<String, dynamic> _list(String prefix) =>
    _node('ListView', {'controls': _rows(prefix)});

/// The collapsing header: a pinned app bar with a flexible space (inside the
/// bar on Material, the sliver after it on iOS) and the tab bar as bottom.
Map<String, dynamic> _appBar() => _node('SliverAppBar', {
      'title': _text('Mail'),
      'pinned': true,
      'flexible_space': _box('hero', 120),
      'bottom': _node('TabBar', {
        'tabs': [
          _node('Tab', {'label': 'Inbox'}),
          _node('Tab', {'label': 'Sent'}),
        ]
      }),
    });

/// Tabs around a NestedScrollView over [body] (by default a TabBarView of
/// two 40-row lists, `a` and `b`).
Map<String, dynamic> _mail(
        {Map<String, dynamic>? body, Map<String, dynamic> props = const {}}) =>
    _node('Tabs', {
      'length': 2,
      'content': _node('NestedScrollView', {
        'header_slivers': [_appBar()],
        'body': body ??
            _node('TabBarView', {
              'controls': [_list('a'), _list('b')]
            }),
        ...props,
      }),
    });

Finder _key(String key) => find.byKey(ValueKey<Object>(key)).first;

bool _shown(String key) =>
    find.byKey(ValueKey<Object>(key)).evaluate().isNotEmpty;

Rect _rect(WidgetTester tester, String key) => tester.getRect(_key(key));

/// Top of a row, or -infinity once it scrolled out of the built range.
double _top(WidgetTester tester, String key) =>
    _shown(key) ? _rect(tester, key).top : double.negativeInfinity;

SliverGeometry _bar(WidgetTester tester) => tester
    .renderObject<RenderSliver>(
        find.byType(AdaptiveSliverAppBarControl, skipOffstage: false))
    .geometry!;

/// Height the pinned header keeps when fully collapsed: toolbar + tab bar.
double _pinned(HarnessDesign design) =>
    design == HarnessDesign.ios ? 44.0 + 48 : 56.0 + 48;

/// Where the header ends: the bar, or on iOS the flexible space sliver below
/// it while that is still showing.
double _headerBottom(WidgetTester tester, HarnessDesign design) {
  final bar = _bar(tester).paintExtent;
  if (design != HarnessDesign.ios || !_shown('hero')) return bar;
  return math.max(bar, _rect(tester, 'hero').bottom);
}

/// The NestedScrollView: the mounted root, or the content of a Tabs root.
Control _nested(HarnessMount mount) => mount.root.type == 'NestedScrollView'
    ? mount.root
    : mount.control(mount.root.child('content')!.id);

Future<void> _scrollTo(
    WidgetTester tester, HarnessMount mount, double offset) async {
  final outcome = await invokeOutcome(tester, _nested(mount), 'scroll_to',
      args: {'offset': offset});
  expect(outcome.error, isNull);
  await tester.pumpAndSettle();
}

void main() {
  for (final design in HarnessDesign.values) {
    final name = design.name;

    testWidgets(
        '$name: the header collapses as a tab list scrolls and stays '
        'pinned above it', (tester) async {
      await mountWire(tester, design, _mail());
      expect(tester.takeException(), isNull);
      expect(find.byType(ErrorControl), findsNothing);
      expect(find.byType(NestedScrollView), findsOneWidget);

      // Expanded: the first row starts right below the whole header.
      final expanded = _headerBottom(tester, design);
      expect(expanded, greaterThan(_pinned(design)));
      expect(_rect(tester, 'a0').top, expanded);

      // Dragging the list first collapses the header; the list does not
      // scroll yet, so its first row stays right below the header.
      await tester.drag(_key('a2'), const Offset(0, -80));
      await tester.pumpAndSettle();
      final partial = _headerBottom(tester, design);
      expect(partial, lessThan(expanded));
      expect(partial, greaterThan(_pinned(design)));
      expect(_rect(tester, 'a0').top, partial);

      // Far enough, the bar stays pinned and the list scrolls under it.
      await tester.drag(_key('a4'), const Offset(0, -1000));
      await tester.pumpAndSettle();
      expect(_bar(tester).paintExtent, _pinned(design));
      final title = tester.getRect(find.text('Mail').last);
      expect(title.top, greaterThanOrEqualTo(0));
      expect(title.bottom, lessThanOrEqualTo(_pinned(design)));
      expect(find.text('Sent').hitTestable(), findsOneWidget);
      expect(_shown('a0') && _rect(tester, 'a0').bottom > _pinned(design),
          isFalse);
      expect(tester.takeException(), isNull);
    });

    testWidgets('$name: a collapsed header never hides the first row',
        (tester) async {
      final mount = await mountWire(tester, design, _mail());
      final expanded = _headerBottom(tester, design);

      // scroll_to(-1): the header fully collapsed, the list at its top. The
      // first row starts below the pinned bar, not under it.
      await _scrollTo(tester, mount, -1);
      expect(_bar(tester).paintExtent, _pinned(design));
      expect(_bar(tester).maxScrollObstructionExtent, _pinned(design));
      expect(_rect(tester, 'a0').top, _pinned(design));
      expect(
          find.byKey(const ValueKey<Object>('a0')).hitTestable(), findsWidgets);

      // scroll_to(0) expands the header and returns the list to its top.
      await tester.drag(_key('a3'), const Offset(0, -400));
      await tester.pumpAndSettle();
      expect(_top(tester, 'a0'), lessThan(_pinned(design)));
      await _scrollTo(tester, mount, 0);
      expect(_headerBottom(tester, design), expanded);
      expect(_rect(tester, 'a0').top, expanded);
    });

    testWidgets('$name: tabs in the body switch, each below the pinned header',
        (tester) async {
      await mountWire(tester, design, _mail());

      // Scroll the Inbox list deep, collapsing the header.
      await tester.drag(_key('a4'), const Offset(0, -1200));
      await tester.pumpAndSettle();
      expect(_bar(tester).paintExtent, _pinned(design));

      await tester.tap(find.text('Sent'));
      await tester.pumpAndSettle();
      expect(
          find.byKey(const ValueKey<Object>('b0')).hitTestable(), findsWidgets);
      // The Sent list starts at its top, right below the pinned header.
      expect(_rect(tester, 'b0').top, _pinned(design));
      expect(_bar(tester).paintExtent, _pinned(design));

      // Its rows scroll with the header too.
      await tester.drag(_key('b3'), const Offset(0, -300));
      await tester.pumpAndSettle();
      expect(_top(tester, 'b0'), lessThan(_pinned(design)));

      // Back on Inbox, the list kept its own offset.
      await tester.tap(find.text('Inbox'));
      await tester.pumpAndSettle();
      expect(
          find.byKey(const ValueKey<Object>('a0')).hitTestable(), findsNothing);
      expect(find.byKey(const ValueKey<Object>('a30')).hitTestable(),
          findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('$name: on_scroll reports the header scroll', (tester) async {
      final mount =
          await mountWire(tester, design, _mail(props: {'on_scroll': true}));
      final id = _nested(mount).id;
      final expanded = _headerBottom(tester, design);

      await tester.drag(_key('a2'), const Offset(0, -80));
      await tester.pumpAndSettle();

      final events = [
        for (final m in mount.backend.sent)
          if (m.id == id && m.name == 'scroll') m.data as Map
      ];
      expect(events.map((e) => e['event_type']),
          containsAll(['start', 'update', 'end']));
      final last = events.lastWhere((e) => e['event_type'] == 'update');
      expect(last['pixels'] as double, greaterThan(0));
      // The outer scroll spans the collapsible part of the header.
      expect(last['max_scroll_extent'], expanded - _pinned(design));
    });

    for (final body in <String, Map<String, dynamic> Function()>{
      'column with scroll': () => _node(
          'Column', {'scroll': 'auto', 'spacing': 0, 'controls': _rows('a')}),
      'grid view': () => _node('GridView', {
            'runs_count': 1,
            'child_aspect_ratio': 16.0,
            'spacing': 0,
            'controls': _rows('a')
          }),
      'custom scroll view': () => _node('CustomScrollView', {
            'slivers': [
              _node('SliverList', {'controls': _rows('a')})
            ]
          }),
      'list view': () => _list('a'),
    }.entries) {
      testWidgets(
          '$name: a ${body.key} body scrolls with the header and '
          'starts below it', (tester) async {
        final mount =
            await mountWire(tester, design, _mail(body: body.value()));
        expect(tester.takeException(), isNull);
        expect(find.byType(ErrorControl), findsNothing);
        final expanded = _headerBottom(tester, design);
        expect(_rect(tester, 'a0').top, expanded);

        // Dragging the body collapses the header first.
        await tester.drag(_key('a2'), const Offset(0, -80));
        await tester.pumpAndSettle();
        expect(_headerBottom(tester, design), lessThan(expanded));
        expect(_rect(tester, 'a0').top, _headerBottom(tester, design));

        await _scrollTo(tester, mount, -1);
        expect(_rect(tester, 'a0').top, _pinned(design));

        // Then the body scrolls under the pinned bar.
        await tester.drag(_key('a4'), const Offset(0, -300));
        await tester.pumpAndSettle();
        expect(_bar(tester).paintExtent, _pinned(design));
        expect(_top(tester, 'a0'), lessThan(_pinned(design)));
      });
    }

    testWidgets(
        '$name: a body that does not scroll sits below the pinned '
        'header', (tester) async {
      final mount = await mountWire(
          tester,
          design,
          _mail(
              body: _node('Column', {
            'spacing': 0,
            'controls': [_box('c0', 50), _box('c1', 50)]
          })));
      final expanded = _headerBottom(tester, design);
      expect(_rect(tester, 'c0').top, expanded);

      // Dragging it scrolls the header (the outer scroll).
      await tester.drag(_key('c1'), const Offset(0, -80));
      await tester.pumpAndSettle();
      expect(_headerBottom(tester, design), lessThan(expanded));
      expect(_rect(tester, 'c0').top, _headerBottom(tester, design));

      await _scrollTo(tester, mount, -1);
      expect(_bar(tester).paintExtent, _pinned(design));
      expect(_rect(tester, 'c0').top, _pinned(design));
    });

    testWidgets(
        '$name: tab pages that do not all scroll sit below the '
        'pinned header', (tester) async {
      final mount = await mountWire(
          tester,
          design,
          _mail(
              body: _node('TabBarView', {
            'controls': [
              _list('a'),
              _node('Column', {
                'spacing': 0,
                'controls': [_box('c0', 50)]
              }),
            ]
          })));
      final expanded = _headerBottom(tester, design);
      expect(_rect(tester, 'a0').top, expanded);

      // The list still drives the header.
      await tester.drag(_key('a2'), const Offset(0, -80));
      await tester.pumpAndSettle();
      expect(_headerBottom(tester, design), lessThan(expanded));
      expect(_rect(tester, 'a0').top, _headerBottom(tester, design));

      await _scrollTo(tester, mount, -1);
      expect(_rect(tester, 'a0').top, _pinned(design));
      await tester.tap(find.text('Sent'));
      await tester.pumpAndSettle();
      expect(_rect(tester, 'c0').top, _pinned(design));
    });

    testWidgets(
        '$name: header slivers given as block children, without a '
        'pinned bar', (tester) async {
      await mountWire(
          tester,
          design,
          _node('NestedScrollView', {
            'controls': [
              _node('SliverToBoxAdapter', {'content': _box('banner', 150)}),
            ],
            'body': _list('a'),
          }));
      expect(_rect(tester, 'banner'), const Rect.fromLTWH(0, 0, 800, 150));
      expect(_rect(tester, 'a0').top, 150);

      // Nothing pins: the banner scrolls away and the list reaches the top.
      await tester.drag(_key('a3'), const Offset(0, -500));
      await tester.pumpAndSettle();
      expect(_shown('banner'), isFalse);
      expect(_top(tester, 'a0'), lessThan(100));
    });

    testWidgets('$name: lists with a scrollbar survive a tab swipe',
        (tester) async {
      Map<String, dynamic> list(String prefix) =>
          _node('ListView', {'scroll': 'always', 'controls': _rows(prefix)});
      await mountWire(
          tester,
          design,
          _mail(
              body: _node('TabBarView', {
            'controls': [list('a'), list('b')]
          })));
      expect(find.byType(PlatformScrollbar), findsWidgets);
      await tester.drag(_key('a3'), const Offset(0, -300));
      await tester.pumpAndSettle();
      // Mid swipe both pages are attached to the inner controller.
      final gesture = await tester.startGesture(tester.getCenter(_key('a8')));
      await gesture.moveBy(const Offset(-300, 0));
      await tester.pump();
      await gesture.moveBy(const Offset(-100, 0));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.drag(find.byType(Scrollable).last, const Offset(0, -200));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('$name: floating header slivers come back first',
        (tester) async {
      await mountWire(
          tester,
          design,
          _node('NestedScrollView', {
            'float_header_slivers': true,
            'header_slivers': [
              _node('SliverAppBar',
                  {'title': _text('Float'), 'floating': true, 'pinned': false})
            ],
            'body': _list('a'),
          }));
      final barHeight = _bar(tester).paintExtent;
      expect(_rect(tester, 'a0').top, barHeight);
      await tester.drag(_key('a5'), const Offset(0, -900));
      await tester.pumpAndSettle();
      expect(_bar(tester).paintExtent, 0);
      expect(_shown('a0'), isFalse);

      // A short drag down floats the bar back while the list stays scrolled.
      await tester.dragFrom(const Offset(400, 400), const Offset(0, 120));
      await tester.pumpAndSettle();
      expect(_bar(tester).paintExtent, greaterThan(0));
      expect(_shown('a0'), isFalse);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        '$name: the status bar inset is not added again below the '
        'pinned bar', (tester) async {
      tester.view.padding =
          FakeViewPadding(top: 40 * tester.view.devicePixelRatio);
      addTearDown(tester.view.resetPadding);
      final mount = await mountWire(tester, design, _mail());

      await _scrollTo(tester, mount, -1);
      // The pinned bar includes the inset; the first row follows it directly.
      expect(_bar(tester).paintExtent, _pinned(design) + 40);
      expect(_rect(tester, 'a0').top, _pinned(design) + 40);
    });

    testWidgets('$name: a large title collapses into the pinned bar',
        (tester) async {
      // Portrait phone: iOS only shows large titles in portrait.
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);
      final mount = await mountWire(
          tester,
          design,
          _node('NestedScrollView', {
            'header_slivers': [
              _node(
                  'SliverAppBar', {'title': _text('Large'), 'variant': 'large'})
            ],
            'body': _list('a'),
          }),
          surface: const Size(400, 800));
      final expanded = _bar(tester).paintExtent;
      final pinned = _bar(tester).maxScrollObstructionExtent;
      expect(expanded, greaterThan(pinned));
      expect(pinned, greaterThan(0));
      expect(_rect(tester, 'a0').top, expanded);

      await _scrollTo(tester, mount, -1);
      expect(_bar(tester).paintExtent, pinned);
      expect(_rect(tester, 'a0').top, pinned);
    });

    testWidgets('$name: unbounded height shows an error', (tester) async {
      await mountWire(
          tester,
          design,
          _node('Column', {
            'scroll': 'auto',
            'controls': [
              _node('NestedScrollView', {'body': _list('a')})
            ]
          }));
      expect(find.byType(ErrorControl), findsOneWidget);
      expect(find.textContaining('height is unbounded'), findsOneWidget);
    });
  }
}
