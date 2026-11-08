import 'dart:async';

import 'package:ruflet/ruflet.dart';
import 'package:ruflet/src/controls/refresh_coordinator.dart';
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
            pageUri: Uri.parse('inprocess://refresh-test'),
            assetsDir: '',
            extensions: [],
            multiView: false) {
    platform = target;
  }

  Iterable<(String, dynamic)> named(String name) =>
      events.where((event) => event.$1 == name);

  @override
  void triggerControlEvent(Control control, String name, [dynamic data]) {
    if (control.get("on_$name") == true) events.add((name, data));
  }

  @override
  void updateControl(int id, Map<String, dynamic> props,
          {bool dart = true, bool python = true, bool notify = false}) =>
      super.updateControl(id, props, dart: dart, python: false, notify: notify);
}

bool _materialOnly(Widget widget) =>
    widget is material.Material ||
    widget is material.Theme ||
    widget is material.Scaffold ||
    widget is material.Scrollbar ||
    widget is material.InkResponse ||
    widget is material.RefreshIndicator ||
    widget is material.ProgressIndicator;

const _viewport = Size(300, 400);

Widget _host(RufletBackend backend, Widget child, {EdgeInsets? mediaPadding}) {
  Widget body = Align(
      alignment: Alignment.topLeft,
      child: SizedBox.fromSize(size: _viewport, child: child));
  if (mediaPadding != null) {
    final inner = body;
    body = Builder(
        builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(padding: mediaPadding),
            child: inner));
  }
  return ChangeNotifierProvider<RufletBackend>.value(
    value: backend,
    child: backend.platform == TargetPlatform.iOS
        ? CupertinoApp(home: body)
        : material.MaterialApp(home: material.Scaffold(body: body)),
  );
}

List<Map<String, dynamic>> _items(int count) => [
      for (var i = 0; i < count; i++)
        {
          '_c': 'Container',
          '_i': 1000 + i,
          'height': 50,
          'content': {'_c': 'Text', '_i': 2000 + i, 'value': 'Item $i'},
        }
    ];

Map<String, dynamic> _list(String type,
        {int count = 30, Map<String, dynamic> props = const {}}) =>
    {
      '_c': type,
      '_i': 1,
      'controls': _items(count),
      if (type == 'GridView') 'runs_count': 2,
      if (type == 'GridView') 'child_aspect_ratio': 3,
      ...props,
    };

Future<void> _pullToRefresh(WidgetTester tester, TargetPlatform platform,
    {String from = 'Item 0'}) async {
  if (platform == TargetPlatform.iOS) {
    final gesture =
        await tester.startGesture(tester.getCenter(find.text(from)));
    // Bouncing friction grows with the overscroll, so drag well past the
    // 100 px trigger distance (a shrink-wrapped list has more friction).
    for (var i = 0; i < 10; i++) {
      await gesture.moveBy(const Offset(0, 40));
      await tester.pump();
    }
    await gesture.up();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  } else {
    await tester.fling(find.text(from), const Offset(0, 300), 1000);
    await tester.pump();
    // Finish the drag snap, then the "refresh" show animation.
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
  }
}

// The idle refresh sliver has no paint extent, so it counts as offstage.
final _cupertinoRefresh =
    find.byType(CupertinoSliverRefreshControl, skipOffstage: false);

Finder _indicator(TargetPlatform platform) => platform == TargetPlatform.iOS
    ? find.byType(CupertinoActivityIndicator)
    : find.byType(material.RefreshProgressIndicator);

Future<void> _endRefresh(WidgetTester tester, Control control) async {
  var done = false;
  Object? error;
  control
      .invokeMethod('end_refresh', null, const Duration(seconds: 1))
      .then((_) => done = true, onError: (Object e) {
    error = e;
    done = true;
  });
  for (var i = 0; i < 20 && !done; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
  expect(error, isNull, reason: 'end_refresh must have a renderer listener');
  expect(done, isTrue);
}

void main() {
  group('RefreshCoordinator', () {
    Control control(_Backend backend,
            [Map<String, dynamic> props = const {}]) =>
        Control.fromMap(
            {'_c': 'ListView', '_i': 7, 'on_refresh': true, ...props}, backend);

    test('joins a pending refresh and completes on end_refresh', () async {
      final backend = _Backend(TargetPlatform.android);
      final list = control(backend);
      final coordinator = RefreshCoordinator(list);
      final first = coordinator.refresh();
      final second = coordinator.refresh();
      expect(identical(first, second), isTrue);
      expect(coordinator.isRefreshing, isTrue);
      expect(backend.named('refresh'), hasLength(1));

      // Listeners for other methods (ScrollableControl's scroll_to) share the
      // control: unrelated names are ignored and answer null.
      expect(
          await list.invokeMethod('scroll_to', {}, const Duration(seconds: 1)),
          isNull);
      expect(coordinator.isRefreshing, isTrue);

      await list.invokeMethod('end_refresh', null, const Duration(seconds: 1));
      await first;
      expect(coordinator.isRefreshing, isFalse);

      // A stray acknowledgement without a pending refresh is harmless, and the
      // next pull refreshes again.
      await list.invokeMethod('end_refresh', null, const Duration(seconds: 1));
      final third = coordinator.refresh();
      expect(identical(third, first), isFalse);
      expect(backend.named('refresh'), hasLength(2));
      coordinator.dispose();
      await third;
    });

    test('refresh_timeout completes a refresh Ruby never acknowledges',
        () async {
      final backend = _Backend(TargetPlatform.iOS);
      final coordinator =
          RefreshCoordinator(control(backend, {'refresh_timeout': 20}));
      final stopwatch = Stopwatch()..start();
      await coordinator.refresh();
      expect(stopwatch.elapsedMilliseconds, greaterThanOrEqualTo(15));
      expect(coordinator.isRefreshing, isFalse);
      coordinator.dispose();
    });

    test('dispose stops listening and completes a pending refresh', () async {
      final backend = _Backend(TargetPlatform.android);
      final list = control(backend);
      final coordinator = RefreshCoordinator(list);
      final pending = coordinator.refresh();
      coordinator.dispose();
      await pending;
      await expectLater(list.invokeMethod('end_refresh', null, Duration.zero),
          throwsA(isA<TimeoutException>()));
    });
  });

  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    final variant = TargetPlatformVariant.only(platform);
    final cupertino = platform == TargetPlatform.iOS;

    for (final type in ['ListView', 'GridView', 'Column']) {
      testWidgets(
          '${platform.name}: $type pull fires one refresh and ends on end_refresh',
          (tester) async {
        final backend = _Backend(platform);
        final control =
            Control.fromMap(_list(type, props: {'on_refresh': true}), backend);
        await tester
            .pumpWidget(_host(backend, ControlWidget(control: control)));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.byType(ErrorControl), findsNothing);

        if (cupertino) {
          expect(_cupertinoRefresh, findsOneWidget);
          expect(find.byWidgetPredicate(_materialOnly), findsNothing);
        } else {
          expect(find.byType(material.RefreshIndicator), findsOneWidget);
          expect(_cupertinoRefresh, findsNothing);
        }
        expect(_indicator(platform), findsNothing);

        await _pullToRefresh(tester, platform);
        expect(backend.named('refresh').toList(), [('refresh', null)]);
        expect(_indicator(platform), findsOneWidget);
        if (cupertino) {
          expect(find.byWidgetPredicate(_materialOnly), findsNothing);
        }

        // Without Ruby's acknowledgement the spinner keeps spinning.
        await tester.pump(const Duration(seconds: 2));
        expect(_indicator(platform), findsOneWidget,
            reason: 'spinner stays until Ruby acknowledges');
        expect(backend.named('refresh'), hasLength(1));

        await _endRefresh(tester, control);
        await tester.pumpAndSettle();
        expect(_indicator(platform), findsNothing);
        expect(tester.getTopLeft(find.text('Item 0')).dy, lessThanOrEqualTo(1),
            reason: 'list settles back to the top');

        // A second pull after the acknowledgement refreshes again.
        await _pullToRefresh(tester, platform);
        expect(backend.named('refresh'), hasLength(2));
        await _endRefresh(tester, control);
        await tester.pumpAndSettle();
        expect(_indicator(platform), findsNothing);
        expect(tester.takeException(), isNull);
      }, variant: variant);
    }

    for (final type in ['ListView', 'GridView']) {
      testWidgets('${platform.name}: $type geometry is unchanged by on_refresh',
          (tester) async {
        final props = {
          'padding': {'left': 12, 'top': 16, 'right': 8, 'bottom': 4},
          'spacing': 6,
          if (type == 'GridView') 'run_spacing': 10,
        };
        Future<List<Rect>> rects(bool refresh) async {
          final backend = _Backend(platform);
          final control = Control.fromMap(
              _list(type, props: {...props, if (refresh) 'on_refresh': true}),
              backend);
          await tester
              .pumpWidget(_host(backend, ControlWidget(control: control)));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          return [
            for (final label in ['Item 0', 'Item 1', 'Item 2'])
              tester.getRect(find
                  .ancestor(
                      of: find.text(label),
                      matching: find.byType(ControlWidget))
                  .first)
          ];
        }

        final plain = await rects(false);
        await tester.pumpWidget(const SizedBox());
        final refreshable = await rects(true);
        expect(refreshable, plain);
        expect(plain.first.topLeft, const Offset(12, 16));
      }, variant: variant);
    }

    testWidgets('${platform.name}: ListView without padding keeps media insets',
        (tester) async {
      Future<Offset> topLeft(bool refresh) async {
        final backend = _Backend(platform);
        final control = Control.fromMap(
            _list('ListView', props: {if (refresh) 'on_refresh': true}),
            backend);
        await tester.pumpWidget(_host(backend, ControlWidget(control: control),
            mediaPadding: const EdgeInsets.only(top: 24, left: 10)));
        await tester.pumpAndSettle();
        return tester.getTopLeft(find.text('Item 0'));
      }

      final plain = await topLeft(false);
      expect(plain, const Offset(0, 24),
          reason: 'BoxScrollView consumes the main-axis media padding');
      await tester.pumpWidget(const SizedBox());
      expect(await topLeft(true), plain);
    }, variant: variant);

    testWidgets(
        '${platform.name}: Column alignment and spacing survive on_refresh',
        (tester) async {
      Future<List<Offset>> offsets(bool refresh) async {
        final backend = _Backend(platform);
        final control = Control.fromMap(
            _list('Column', count: 3, props: {
              'alignment': 'center',
              'horizontal_alignment': 'center',
              'spacing': 8,
              if (refresh) 'on_refresh': true,
            }),
            backend);
        await tester
            .pumpWidget(_host(backend, ControlWidget(control: control)));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        return [
          for (final label in ['Item 0', 'Item 2'])
            tester.getTopLeft(find.text(label))
        ];
      }

      final plain = await offsets(false);
      await tester.pumpWidget(const SizedBox());
      expect(await offsets(true), plain);
      // 3 x 50 + 2 x 8 = 166 tall, centered in 400.
      expect(plain.first.dy, closeTo((400 - 166) / 2, 0.01));
    }, variant: variant);

    testWidgets(
        '${platform.name}: Column expand children still flex under on_refresh',
        (tester) async {
      Future<Rect> bodyRect(bool refresh) async {
        final backend = _Backend(platform);
        final control = Control.fromMap({
          '_c': 'Column',
          '_i': 1,
          '_internals': {'host_expanded': true},
          if (refresh) 'on_refresh': true,
          'controls': [
            {
              '_c': 'Container',
              '_i': 10,
              'height': 50,
              'content': {'_c': 'Text', '_i': 11, 'value': 'Header'},
            },
            {
              '_c': 'Container',
              '_i': 12,
              'expand': true,
              'content': {'_c': 'Text', '_i': 13, 'value': 'Body'},
            },
          ],
        }, backend);
        await tester
            .pumpWidget(_host(backend, ControlWidget(control: control)));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        if (refresh) {
          await _pullToRefresh(tester, platform, from: 'Header');
          expect(backend.named('refresh'), hasLength(1));
          await _endRefresh(tester, control);
          await tester.pumpAndSettle();
        }
        return tester.getRect(find.byWidgetPredicate(
            (widget) => widget is ControlWidget && widget.control.id == 12));
      }

      final plain = await bodyRect(false);
      // 400 - 50 header - 10 default spacing.
      expect(plain.height, 340);
      await tester.pumpWidget(const SizedBox());
      expect(await bodyRect(true), plain);
    }, variant: variant);

    testWidgets(
        '${platform.name}: refresh_timeout ends the spinner without Ruby',
        (tester) async {
      final backend = _Backend(platform);
      final control = Control.fromMap(
          _list('ListView',
              props: {'on_refresh': true, 'refresh_timeout': 100}),
          backend);
      await tester.pumpWidget(_host(backend, ControlWidget(control: control)));
      await tester.pumpAndSettle();
      await _pullToRefresh(tester, platform);
      expect(backend.named('refresh'), hasLength(1));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpAndSettle();
      expect(_indicator(platform), findsNothing);
      // The late acknowledgement is harmless.
      await _endRefresh(tester, control);
      expect(tester.takeException(), isNull);
    }, variant: variant);

    testWidgets('${platform.name}: a short list can still be pulled',
        (tester) async {
      final backend = _Backend(platform);
      final control = Control.fromMap(
          _list('ListView', count: 2, props: {'on_refresh': true}), backend);
      await tester.pumpWidget(_host(backend, ControlWidget(control: control)));
      await tester.pumpAndSettle();
      await _pullToRefresh(tester, platform);
      expect(backend.named('refresh'), hasLength(1));
      await _endRefresh(tester, control);
      await tester.pumpAndSettle();
      expect(_indicator(platform), findsNothing);
    }, variant: variant);

    testWidgets(
        '${platform.name}: an unbounded list shrink-wraps and still refreshes',
        (tester) async {
      final backend = _Backend(platform);
      final control = Control.fromMap({
        '_c': 'Column',
        '_i': 9,
        'controls': [
          _list('ListView', count: 3, props: {'on_refresh': true})
        ],
      }, backend);
      await tester.pumpWidget(_host(backend, ControlWidget(control: control)));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(ErrorControl), findsNothing);
      await _pullToRefresh(tester, platform);
      expect(backend.named('refresh'), hasLength(1));
    }, variant: variant);

    testWidgets(
        '${platform.name}: refresh colors and distances reach the indicator',
        (tester) async {
      final backend = _Backend(platform);
      final control = Control.fromMap(
          _list('ListView', props: {
            'on_refresh': true,
            'refresh_color': '#ff0000',
            'refresh_bgcolor': '#00ff00',
            'refresh_displacement': 64,
            'refresh_trigger_distance': 140,
          }),
          backend);
      await tester.pumpWidget(_host(backend, ControlWidget(control: control)));
      await tester.pumpAndSettle();
      if (cupertino) {
        final refresh =
            tester.widget<CupertinoSliverRefreshControl>(_cupertinoRefresh);
        expect(refresh.refreshTriggerPullDistance, 140);
        expect(refresh.refreshIndicatorExtent, 60);
        await _pullToRefresh(tester, platform);
        final spinner = tester.widget<CupertinoActivityIndicator>(
            find.byType(CupertinoActivityIndicator));
        expect(spinner.color, const Color(0xffff0000));
      } else {
        final refresh = tester.widget<material.RefreshIndicator>(
            find.byType(material.RefreshIndicator));
        expect(refresh.color, const Color(0xffff0000));
        expect(refresh.backgroundColor, const Color(0xff00ff00));
        expect(refresh.displacement, 64);
      }
    }, variant: variant);

    for (final props in [
      {'horizontal': true, 'height': 100},
      {'reverse': true}
    ]) {
      testWidgets('${platform.name}: ListView $props ignores on_refresh',
          (tester) async {
        final backend = _Backend(platform);
        final control = Control.fromMap(
            _list('ListView', props: {'on_refresh': true, ...props}), backend);
        await tester
            .pumpWidget(_host(backend, ControlWidget(control: control)));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(_cupertinoRefresh, findsNothing);
        expect(find.byType(material.RefreshIndicator), findsNothing);
      }, variant: variant);
    }

    testWidgets('${platform.name}: refreshable ListView keeps scroll_to',
        (tester) async {
      final backend = _Backend(platform);
      final control = Control.fromMap(
          _list('ListView', props: {'on_refresh': true}), backend);
      await tester.pumpWidget(_host(backend, ControlWidget(control: control)));
      await tester.pumpAndSettle();
      final position =
          tester.state<ScrollableState>(find.byType(Scrollable).first).position;
      var done = false;
      control
          .invokeMethod('scroll_to', {'offset': -1}, const Duration(seconds: 1))
          .then((_) => done = true);
      for (var i = 0; i < 10 && !done; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(done, isTrue);
      expect(position.pixels, position.maxScrollExtent);
      expect(position.maxScrollExtent, greaterThan(0));
    }, variant: variant);
  }
}
