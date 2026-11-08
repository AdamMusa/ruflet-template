import 'package:ruflet/ruflet.dart';
import 'package:ruflet/src/controls/adaptive_sliver_app_bar.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' as material;
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'control_renderer_matrix_test.dart' show materialOnly;

class _Backend extends RufletBackend {
  _Backend(TargetPlatform target)
      : super(
            pageUri: Uri.parse('inprocess://sliver-app-bar-test'),
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
  void triggerControlEvent(Control control, String name, [dynamic data]) {}
}

int _ids = 2000;

Map<String, dynamic> _node(String type,
        [Map<String, dynamic> props = const {}]) =>
    {'_c': type, '_i': ++_ids, ...props};

Map<String, dynamic> _text(String value) => _node('Text', {'value': value});

Map<String, dynamic> _box(String key, double height) =>
    _node('Container', {'key': key, 'height': height, 'bgcolor': '#dddddd'});

/// A scroll view with the app bar on top of 40 rows of 50px.
Map<String, dynamic> _page(Map<String, dynamic> appBar) =>
    _node('CustomScrollView', {
      'slivers': [
        appBar,
        _node('SliverList', {
          'controls': [for (var i = 0; i < 40; i++) _box('row$i', 50)],
        }),
      ],
    });

Map<String, dynamic> _appBar([Map<String, dynamic> props = const {}]) =>
    _node('SliverAppBar', {
      'title': _text('Inbox'),
      'actions': [_text('Edit')],
      ...props,
    });

Future<Control> _pump(
    WidgetTester tester, TargetPlatform platform, Map<String, dynamic> tree,
    {double topInset = 0}) async {
  // Portrait phone: iOS only shows large titles in portrait.
  tester.view.physicalSize = const Size(1200, 2400);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
  final backend = _Backend(platform);
  final control = Control.fromMap(tree, backend);
  final body = Builder(
    builder: (context) => MediaQuery(
      data: MediaQuery.of(context)
          .copyWith(padding: EdgeInsets.only(top: topInset)),
      child: ControlWidget(control: control),
    ),
  );
  await tester.pumpWidget(ChangeNotifierProvider<RufletBackend>.value(
    value: backend,
    child: platform == TargetPlatform.iOS
        ? CupertinoApp(home: body)
        : material.MaterialApp(home: body),
  ));
  expect(tester.takeException(), isNull);
  expect(find.byType(ErrorControl), findsNothing);
  return control;
}

/// Visible height of the app bar sliver.
double _barExtent(WidgetTester tester) => tester
    .renderObject<RenderSliver>(
        find.byType(AdaptiveSliverAppBarControl, skipOffstage: false))
    .geometry!
    .paintExtent;

Future<void> _scrollTo(
    WidgetTester tester, Control control, double offset) async {
  await control.invokeMethod(
      'scroll_to', {'offset': offset}, const Duration(seconds: 1));
  await tester.pump();
}

// Ruby keys arrive as ValueKey<Object>.
Rect _rect(WidgetTester tester, String key) =>
    tester.getRect(find.byKey(ValueKey<Object>(key)).first);

/// Runs [body] and returns the `Warning:` lines it printed.
Future<List<String>> _warnings(Future<void> Function() body) async {
  final lines = <String>[];
  final original = debugPrint;
  debugPrint = (String? message, {int? wrapWidth}) {
    if (message != null && message.startsWith('Warning:')) lines.add(message);
  };
  try {
    await body();
  } finally {
    debugPrint = original;
  }
  return lines;
}

double _opacityAbove(WidgetTester tester, Element element) {
  double? opacity;
  element.visitAncestorElements((ancestor) {
    final widget = ancestor.widget;
    if (widget is AnimatedOpacity) {
      opacity = widget.opacity;
      return false;
    }
    return true;
  });
  return opacity ?? 1;
}

void main() {
  group('Cupertino', () {
    const ios = TargetPlatform.iOS;

    testWidgets('large title collapses into the pinned navigation bar',
        (tester) async {
      final control = await _pump(
          tester, ios, _page(_appBar({'variant': 'large'})),
          topInset: 20);
      expect(find.byType(CupertinoSliverNavigationBar), findsOneWidget);
      expect(find.byWidgetPredicate(materialOnly), findsNothing);
      expect(find.byType(material.FlexibleSpaceBar), findsNothing);
      expect(find.text('Edit'), findsOneWidget);

      // Expanded: status bar inset + 44pt bar + 52pt large title.
      expect(_barExtent(tester), 20 + 44 + 52);
      expect(_rect(tester, 'row0').top, 116);
      List<Element> titles() => find.text('Inbox').evaluate().toList()
        ..sort((a, b) => tester
            .getTopLeft(find.byElementPredicate((e) => e == a))
            .dy
            .compareTo(
                tester.getTopLeft(find.byElementPredicate((e) => e == b)).dy));
      // The inline middle title (top) is hidden, the large title shows.
      var both = titles();
      expect(both, hasLength(2));
      expect(_opacityAbove(tester, both.first), 0);
      expect(_opacityAbove(tester, both.last), 1);
      expect(
          tester.getTopLeft(find.byElementPredicate((e) => e == both.last)).dy,
          greaterThanOrEqualTo(64));

      // Scrolled: the large title is gone and the 44pt bar stays pinned.
      await _scrollTo(tester, control, 200);
      expect(_barExtent(tester), 20 + 44);
      both = titles();
      final middle = both.firstWhere((e) => _opacityAbove(tester, e) == 1);
      final middleRect =
          tester.getRect(find.byElementPredicate((e) => e == middle));
      expect(middleRect.top, greaterThanOrEqualTo(20));
      expect(middleRect.bottom, lessThanOrEqualTo(64));
      expect(both.where((e) => _opacityAbove(tester, e) == 1), hasLength(1));
      expect(tester.takeException(), isNull);
    });

    testWidgets('medium uses the same collapsing large title', (tester) async {
      final control =
          await _pump(tester, ios, _page(_appBar({'variant': 'medium'})));
      expect(find.byType(CupertinoSliverNavigationBar), findsOneWidget);
      expect(_barExtent(tester), 96);
      await _scrollTo(tester, control, 300);
      expect(_barExtent(tester), 44);
    });

    testWidgets('small bar scrolls away unless pinned', (tester) async {
      var control = await _pump(tester, ios, _page(_appBar()));
      expect(find.byType(CupertinoSliverNavigationBar), findsNothing);
      expect(find.byType(CupertinoNavigationBar), findsOneWidget);
      expect(_barExtent(tester), 44);
      await _scrollTo(tester, control, 300);
      expect(_barExtent(tester), 0);

      control = await _pump(tester, ios, _page(_appBar({'pinned': true})));
      await _scrollTo(tester, control, 300);
      expect(_barExtent(tester), 44);
      expect(find.byWidgetPredicate(materialOnly), findsNothing);
    });

    testWidgets('small floating bar reappears on reverse scroll',
        (tester) async {
      final control =
          await _pump(tester, ios, _page(_appBar({'floating': true})));
      expect(find.byType(SliverFloatingHeader), findsOneWidget);
      await _scrollTo(tester, control, 600);
      expect(_barExtent(tester), 0);

      final gesture =
          await tester.startGesture(tester.getCenter(find.byType(Scrollable)));
      await gesture.moveBy(const Offset(0, 20));
      await gesture.moveBy(const Offset(0, 20));
      await tester.pump();
      expect(_barExtent(tester), greaterThan(0));
      await gesture.up();
      await tester.pumpAndSettle();
      // SliverFloatingHeader snaps fully into view when the gesture ends.
      expect(_barExtent(tester), 44);
    });

    testWidgets('flexible_space is a plain box below the navigation bar',
        (tester) async {
      await _pump(
          tester,
          ios,
          _page(_appBar({
            'variant': 'large',
            'flexible_space': _box('hero', 120),
            'bottom': _box('tabs', 10),
            'bottom_height': 30,
          })));
      // 44 bar + 52 large title + 30 bottom, then the hero box, then rows.
      expect(_barExtent(tester), 126);
      expect(_rect(tester, 'hero'), const Rect.fromLTWH(0, 126, 400, 120));
      expect(_rect(tester, 'row0').top, 246);
      expect(find.byKey(const ValueKey<Object>('tabs')), findsWidgets);
      expect(find.byWidgetPredicate(materialOnly), findsNothing);
    });

    testWidgets('CupertinoSliverNavigationBar alias renders the canonical bar',
        (tester) async {
      await _pump(
          tester,
          ios,
          _page(_node('CupertinoSliverNavigationBar',
              {'title': _text('Inbox'), 'variant': 'large'})));
      expect(find.byType(CupertinoSliverNavigationBar), findsOneWidget);
    });
  });

  group('Material', () {
    const android = TargetPlatform.android;

    testWidgets('large app bar collapses from 152 to 64 when pinned',
        (tester) async {
      final control =
          await _pump(tester, android, _page(_appBar({'variant': 'large'})));
      expect(find.byType(material.SliverAppBar), findsOneWidget);
      expect(find.byType(CupertinoSliverNavigationBar), findsNothing);
      expect(find.text('Edit'), findsOneWidget);
      expect(_barExtent(tester), 152);
      expect(_rect(tester, 'row0').top, 152);

      await _scrollTo(tester, control, 200);
      expect(_barExtent(tester), 64);
      expect(tester.takeException(), isNull);
    });

    testWidgets('medium collapses from 112 and honors the status bar inset',
        (tester) async {
      final control = await _pump(
          tester, android, _page(_appBar({'variant': 'medium'})),
          topInset: 24);
      expect(_barExtent(tester), 24 + 112);
      await _scrollTo(tester, control, 300);
      expect(_barExtent(tester), 24 + 64);
    });

    testWidgets('small app bar is unpinned by default and pins on request',
        (tester) async {
      var control = await _pump(tester, android, _page(_appBar()));
      expect(_barExtent(tester), material.kToolbarHeight);
      await _scrollTo(tester, control, 300);
      expect(_barExtent(tester), 0);

      control = await _pump(
          tester,
          android,
          _page(_appBar({
            'pinned': true,
            'toolbar_height': 70,
            'expanded_height': 180,
          })));
      expect(_barExtent(tester), 180);
      await _scrollTo(tester, control, 400);
      expect(_barExtent(tester), 70);
    });

    testWidgets('small floating bar reappears on reverse scroll and snaps',
        (tester) async {
      final control = await _pump(
          tester, android, _page(_appBar({'floating': true, 'snap': true})));
      await _scrollTo(tester, control, 600);
      expect(_barExtent(tester), 0);

      final gesture =
          await tester.startGesture(tester.getCenter(find.byType(Scrollable)));
      await gesture.moveBy(const Offset(0, 20));
      await gesture.moveBy(const Offset(0, 20));
      await tester.pump();
      expect(_barExtent(tester), greaterThan(0));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(_barExtent(tester), material.kToolbarHeight);
    });

    testWidgets('flexible_space renders in a FlexibleSpaceBar, 200 tall',
        (tester) async {
      await _pump(
          tester,
          android,
          _page(_appBar({
            'flexible_space': _box('hero', 10),
            'bottom': _box('tabs', 10),
          })));
      expect(find.byType(material.FlexibleSpaceBar), findsOneWidget);
      // Default expanded height 200 plus the 48px bottom.
      expect(_barExtent(tester), 200 + 48);
      expect(_rect(tester, 'row0').top, 248);
      // The title moves into the flexible space bar (not duplicated).
      expect(find.text('Inbox'), findsOneWidget);
      expect(find.byKey(const ValueKey<Object>('hero')), findsWidgets);
      // On Material the iOS-only flexible box sliver stays empty.
      expect(find.byKey(const ValueKey<Object>('tabs')), findsWidgets);
    });

    testWidgets('invalid SDK combinations are corrected with a warning',
        (tester) async {
      final bar = _appBar({
        'snap': true, // without floating
        'toolbar_height': 60,
        'collapsed_height': 20, // below toolbar_height
        'pinned': true,
      });
      final warnings =
          await _warnings(() => _pump(tester, android, _page(bar)));
      expect(_barExtent(tester), 60);
      expect(
          warnings,
          containsAll([
            'Warning: SliverAppBar(${bar['_i']}) snap requires floating; '
                'ignoring snap.',
            'Warning: SliverAppBar(${bar['_i']}) collapsed_height 20.0 is '
                'below toolbar_height 60.0; using 60.0.',
          ]));
    });

    testWidgets('valid combinations log no warning', (tester) async {
      final warnings = await _warnings(() => _pump(
          tester,
          android,
          _page(_appBar({
            'floating': true,
            'snap': true,
            'toolbar_height': 60,
            'collapsed_height': 60,
          }))));
      expect(warnings, isEmpty);
    });
  });
}
