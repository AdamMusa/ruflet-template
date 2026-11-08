import 'package:ruflet/ruflet.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' as material;
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

/// Records the events the renderer would send to Ruby, honoring the same
/// `on_<event>` subscription check as the real backend.
class _Backend extends RufletBackend {
  final events = <(String, dynamic)>[];

  _Backend(TargetPlatform target)
      : super(
            pageUri: Uri.parse('inprocess://end-reached-test'),
            assetsDir: '',
            extensions: [],
            multiView: false) {
    platform = target;
  }

  List<dynamic> named(String name) => [
        for (final e in events)
          if (e.$1 == name) e.$2
      ];

  @override
  void triggerControlEvent(Control control, String name, [dynamic data]) {
    if (control.get("on_$name") == true) events.add((name, data));
  }

  @override
  void updateControl(int id, Map<String, dynamic> props,
          {bool dart = true, bool python = true, bool notify = false}) =>
      super.updateControl(id, props, dart: dart, python: false, notify: notify);
}

const _viewport = Size(300, 400);

Widget _host(RufletBackend backend, Widget child) {
  final body = Align(
      alignment: Alignment.topLeft,
      child: SizedBox.fromSize(size: _viewport, child: child));
  return ChangeNotifierProvider<RufletBackend>.value(
    value: backend,
    child: backend.platform == TargetPlatform.iOS
        ? CupertinoApp(home: body)
        : material.MaterialApp(home: material.Scaffold(body: body)),
  );
}

List<Map<String, dynamic>> _items(int count, {int from = 0}) => [
      for (var i = from; i < from + count; i++)
        {
          '_c': 'Container',
          '_i': 1000 + i,
          'height': 50,
          'width': 50,
          'content': {'_c': 'Text', '_i': 2000 + i, 'value': 'Item $i'},
        }
    ];

Map<String, dynamic> _scrollable(String type,
        {int count = 20, Map<String, dynamic> props = const {}}) =>
    {
      '_c': type,
      '_i': 1,
      'controls': _items(count),
      if (type == 'Column' || type == 'Row') 'scroll': 'auto',
      if (type == 'Column' || type == 'Row') 'spacing': 0,
      if (type == 'GridView') 'runs_count': 1,
      if (type == 'GridView') 'child_aspect_ratio': 6,
      if (type == 'GridView') 'spacing': 0,
      'on_end_reached': true,
      'end_reached_threshold': 100,
      ...props,
    };

ScrollPosition _position(WidgetTester tester) =>
    tester.state<ScrollableState>(find.byType(Scrollable).first).position;

Future<void> _scrollTo(WidgetTester tester, double pixels) async {
  _position(tester).jumpTo(pixels);
  await tester.pump();
  await tester.pump();
}

void main() {
  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    final variant = TargetPlatformVariant.only(platform);

    for (final type in ['ListView', 'GridView', 'Column', 'Row']) {
      testWidgets('${platform.name}: $type fires end_reached once per end',
          (tester) async {
        final backend = _Backend(platform);
        final control = Control.fromMap(_scrollable(type), backend);
        await tester
            .pumpWidget(_host(backend, ControlWidget(control: control)));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final position = _position(tester);
        final viewport = type == 'Row' ? _viewport.width : _viewport.height;
        // 20 x 50 px of content.
        expect(position.maxScrollExtent, 1000 - viewport);
        expect(backend.named('end_reached'), isEmpty,
            reason: 'the top of a long list is not its end');

        await _scrollTo(tester, position.maxScrollExtent - 150);
        expect(backend.named('end_reached'), isEmpty,
            reason: '150 px from the end is outside the 100 px threshold');

        await _scrollTo(tester, position.maxScrollExtent - 80);
        expect(backend.named('end_reached'), [
          {
            'pixels': position.maxScrollExtent - 80,
            'max_scroll_extent': 1000 - viewport,
            'viewport_dimension': viewport,
          }
        ]);

        // Moving around near the end without new items does not re-fire.
        await _scrollTo(tester, position.maxScrollExtent);
        await _scrollTo(tester, position.maxScrollExtent - 180);
        await _scrollTo(tester, position.maxScrollExtent);
        expect(backend.named('end_reached'), hasLength(1));

        // Ruby appends a page of items: the end moves, so the next arrival
        // fires again.
        control.applyPatch([
          [0],
          [
            0,
            0,
            'controls',
            [..._items(20), ..._items(20, from: 20)]
          ]
        ], backend);
        await tester.pumpAndSettle();
        expect(position.maxScrollExtent, 2000 - viewport);
        expect(backend.named('end_reached'), hasLength(1),
            reason: 'the new end is far away');
        await _scrollTo(tester, position.maxScrollExtent);
        expect(backend.named('end_reached'), hasLength(2));
        expect(backend.named('end_reached').last['max_scroll_extent'],
            2000 - viewport);

        // Scrolling far back (more than twice the threshold) re-arms too,
        // so a failed page load can be retried.
        await _scrollTo(tester, 0);
        await _scrollTo(tester, position.maxScrollExtent);
        expect(backend.named('end_reached'), hasLength(3));
        expect(tester.takeException(), isNull);
      }, variant: variant);
    }

    testWidgets('${platform.name}: a short list reports its end once',
        (tester) async {
      final backend = _Backend(platform);
      final control =
          Control.fromMap(_scrollable('ListView', count: 3), backend);
      await tester.pumpWidget(_host(backend, ControlWidget(control: control)));
      await tester.pumpAndSettle();
      expect(backend.named('end_reached'), [
        {'pixels': 0.0, 'max_scroll_extent': 0.0, 'viewport_dimension': 400.0}
      ]);
      await tester.pump(const Duration(seconds: 1));
      expect(backend.named('end_reached'), hasLength(1));
    }, variant: variant);

    testWidgets('${platform.name}: dragging a ListView to its end fires',
        (tester) async {
      final backend = _Backend(platform);
      final control = Control.fromMap(_scrollable('ListView'), backend);
      await tester.pumpWidget(_host(backend, ControlWidget(control: control)));
      await tester.pumpAndSettle();
      await tester.fling(find.text('Item 2'), const Offset(0, -2000), 3000);
      await tester.pumpAndSettle();
      expect(backend.named('end_reached'), hasLength(1));
    }, variant: variant);

    testWidgets('${platform.name}: a reversed chat list ends at the top',
        (tester) async {
      final backend = _Backend(platform);
      final control = Control.fromMap(
          _scrollable('ListView', props: {'reverse': true}), backend);
      await tester.pumpWidget(_host(backend, ControlWidget(control: control)));
      await tester.pumpAndSettle();
      expect(backend.named('end_reached'), isEmpty);
      // Item 0 sits at the visual bottom; older items are above.
      expect(tester.getBottomLeft(find.text('Item 0')).dy,
          greaterThan(_viewport.height - 60));
      await _scrollTo(tester, _position(tester).maxScrollExtent);
      expect(backend.named('end_reached'), hasLength(1));
      expect(tester.getTopLeft(find.text('Item 19')).dy, closeTo(0, 0.01));
    }, variant: variant);

    testWidgets('${platform.name}: end_reached works with on_refresh',
        (tester) async {
      final backend = _Backend(platform);
      final control = Control.fromMap(
          _scrollable('ListView', props: {'on_refresh': true}), backend);
      await tester.pumpWidget(_host(backend, ControlWidget(control: control)));
      await tester.pumpAndSettle();
      expect(find.byType(CustomScrollView), findsOneWidget);
      await _scrollTo(tester, _position(tester).maxScrollExtent);
      expect(backend.named('end_reached'), hasLength(1));
    }, variant: variant);

    testWidgets('${platform.name}: without on_end_reached nothing is sent',
        (tester) async {
      final backend = _Backend(platform);
      final control = Control.fromMap(
          _scrollable('ListView', count: 3, props: {'on_end_reached': null}),
          backend);
      await tester.pumpWidget(_host(backend, ControlWidget(control: control)));
      await tester.pumpAndSettle();
      expect(backend.events, isEmpty);
    }, variant: variant);
  }
}
