import 'package:ruflet/ruflet.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' as material;
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class _Backend extends RufletBackend {
  _Backend(TargetPlatform target)
      : super(
            pageUri: Uri.parse('inprocess://animated-list-test'),
            assetsDir: '',
            extensions: [],
            multiView: false) {
    platform = target;
  }

  @override
  void triggerControlEvent(Control control, String name, [dynamic data]) {}

  @override
  void updateControl(int id, Map<String, dynamic> props,
          {bool dart = true, bool python = true, bool notify = false}) =>
      super.updateControl(id, props, dart: dart, python: false, notify: notify);
}

Widget _host(RufletBackend backend, Widget child) {
  final body = Align(
      alignment: Alignment.topLeft,
      child: SizedBox(width: 300, height: 400, child: child));
  return ChangeNotifierProvider<RufletBackend>.value(
    value: backend,
    child: backend.platform == TargetPlatform.iOS
        ? CupertinoApp(home: body)
        : material.MaterialApp(home: material.Scaffold(body: body)),
  );
}

Map<String, dynamic> _item(int i) => {
      '_c': 'Container',
      '_i': 1000 + i,
      'height': 40,
      'content': {'_c': 'Text', '_i': 2000 + i, 'value': 'Item $i'},
    };

Map<String, dynamic> _hostControl(String type, List<int> items,
        {Map<String, dynamic> props = const {}}) =>
    {
      '_c': type == 'RefreshListView' ? 'ListView' : type,
      '_i': 1,
      'animate_changes': true,
      if (type == 'RefreshListView') 'on_refresh': true,
      'controls': [for (final i in items) _item(i)],
      ...props,
    };

void _setItems(Control control, RufletBackend backend, List<int> items) {
  control.applyPatch([
    [0],
    [
      0,
      0,
      'controls',
      [for (final i in items) _item(i)]
    ]
  ], backend);
}

Finder _keyed<T extends Widget>(int id) =>
    find.byWidgetPredicate((w) => w is T && w.key == ValueKey(1000 + id));

double _opacity(WidgetTester tester, int id) => tester
    .widget<FadeTransition>(find
        .descendant(
            of: _keyed<SizeTransition>(id),
            matching: find.byType(FadeTransition))
        .first)
    .opacity
    .value;

double _size(WidgetTester tester, int id) =>
    tester.widget<SizeTransition>(_keyed<SizeTransition>(id)).sizeFactor.value;

void main() {
  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    final variant = TargetPlatformVariant.only(platform);

    for (final type in ['ListView', 'RefreshListView', 'Column']) {
      testWidgets(
          '${platform.name}: $type animate_changes animates inserts '
          'and removals', (tester) async {
        final backend = _Backend(platform);
        final control =
            Control.fromMap(_hostControl(type, [0, 1, 2, 3]), backend);
        await tester
            .pumpWidget(_host(backend, ControlWidget(control: control)));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        // The first build shows everything without animating.
        for (final id in [0, 1, 2, 3]) {
          expect(_opacity(tester, id), 1.0);
          expect(_size(tester, id), 1.0);
        }

        // Insert: item 9 lands at index 2 and grows/fades in (250 ms).
        _setItems(control, backend, [0, 1, 9, 2, 3]);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 125));
        expect(_opacity(tester, 9), inExclusiveRange(0.0, 1.0));
        expect(_size(tester, 9), inExclusiveRange(0.0, 1.0));
        expect(_opacity(tester, 0), 1.0, reason: 'others do not animate');
        final y1 = tester.getTopLeft(find.text('Item 1')).dy;
        final y9 = tester.getTopLeft(find.text('Item 9')).dy;
        expect(y9, greaterThan(y1), reason: 'inserted at its Ruby index');
        await tester.pumpAndSettle();
        expect(_opacity(tester, 9), 1.0);
        expect(_size(tester, 9), 1.0);

        // Remove: item 1 stays in place while it shrinks/fades out.
        final itemTwoBefore = tester.getTopLeft(find.text('Item 2')).dy;
        _setItems(control, backend, [0, 9, 2, 3]);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 125));
        expect(find.text('Item 1'), findsOneWidget);
        expect(_opacity(tester, 1), inExclusiveRange(0.0, 1.0));
        expect(tester.getTopLeft(find.text('Item 1')).dy, lessThan(y9),
            reason: 'the leaving item keeps its position');
        await tester.pumpAndSettle();
        expect(find.text('Item 1'), findsNothing);
        expect(
            tester.getTopLeft(find.text('Item 2')).dy, lessThan(itemTwoBefore),
            reason: 'the gap closes once the item is gone');

        // Reorder: same ids, no animation.
        _setItems(control, backend, [3, 2, 9, 0]);
        await tester.pump();
        for (final id in [3, 2, 9, 0]) {
          expect(_opacity(tester, id), 1.0);
        }
        expect(tester.getTopLeft(find.text('Item 3')).dy,
            lessThan(tester.getTopLeft(find.text('Item 0')).dy));
        expect(tester.takeException(), isNull);
      }, variant: variant);
    }

    testWidgets('${platform.name}: item_animation types and timing',
        (tester) async {
      for (final (type, transition) in [
        ('fade', FadeTransition),
        ('size', SizeTransition),
        ('slide', SlideTransition),
        ('fade_size', SizeTransition),
      ]) {
        final backend = _Backend(platform);
        final control = Control.fromMap(
            _hostControl('ListView', [
              0
            ], props: {
              'item_animation': {
                'type': type,
                'duration': 400,
                'curve': 'linear'
              }
            }),
            backend);
        await tester
            .pumpWidget(_host(backend, ControlWidget(control: control)));
        await tester.pumpAndSettle();
        _setItems(control, backend, [0, 1]);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));
        final keyed = find.byWidgetPredicate((w) =>
            w.runtimeType == transition && w.key == const ValueKey(1001));
        expect(keyed, findsOneWidget, reason: type);
        final animation = switch (tester.widget(keyed)) {
          FadeTransition w => w.opacity,
          SizeTransition w => w.sizeFactor,
          SlideTransition w => w.position,
          _ => throw StateError(type),
        };
        if (animation is Animation<double>) {
          expect(animation.value, closeTo(0.5, 0.01), reason: type);
        } else {
          expect((animation as Animation<Offset>).value.dx, closeTo(0.5, 0.01),
              reason: '$type slides in from the side');
        }
        await tester.pumpAndSettle();
        await tester.pumpWidget(const SizedBox());
      }
    }, variant: variant);

    testWidgets(
        '${platform.name}: without animate_changes items do not animate',
        (tester) async {
      final backend = _Backend(platform);
      final control = Control.fromMap(
          _hostControl('ListView', [0, 1], props: {'animate_changes': null}),
          backend);
      await tester.pumpWidget(_host(backend, ControlWidget(control: control)));
      await tester.pumpAndSettle();
      _setItems(control, backend, [0, 1, 2]);
      await tester.pump();
      expect(_keyed<SizeTransition>(2), findsNothing);
      expect(find.text('Item 2'), findsOneWidget);
      _setItems(control, backend, [0, 2]);
      await tester.pump();
      expect(find.text('Item 1'), findsNothing,
          reason: 'removed immediately without animate_changes');
    }, variant: variant);

    testWidgets('${platform.name}: Column expand children are not wrapped',
        (tester) async {
      final backend = _Backend(platform);
      final control = Control.fromMap({
        '_c': 'Column',
        '_i': 1,
        '_internals': {'host_expanded': true},
        'animate_changes': true,
        'controls': [
          _item(0),
          {
            '_c': 'Container',
            '_i': 1005,
            'expand': true,
            'content': {'_c': 'Text', '_i': 2005, 'value': 'Fill'},
          },
        ],
      }, backend);
      await tester.pumpWidget(_host(backend, ControlWidget(control: control)));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final fill = tester.getRect(find.byWidgetPredicate(
          (w) => w is ControlWidget && w.control.id == 1005));
      expect(fill.height, 400 - 40 - 10);
    }, variant: variant);
  }
}
