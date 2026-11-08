import 'package:ruflet/ruflet.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' as material;
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class _Backend extends RufletBackend {
  final events = <String>[];
  _Backend(TargetPlatform target)
      : super(
            pageUri: Uri.parse('inprocess://early-close-test'),
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

/// A dialog-like control and the text its route shows.
typedef _Case = ({
  String name,
  TargetPlatform platform,
  Map<String, dynamic> map,
  String body
});

final List<_Case> _cases = [
  (
    name: 'Cupertino AlertDialog',
    platform: TargetPlatform.iOS,
    map: {'_c': 'AlertDialog', '_i': 1, 'open': false, 'title': 'Dialog'},
    body: 'Dialog',
  ),
  (
    name: 'Material AlertDialog',
    platform: TargetPlatform.android,
    map: {'_c': 'AlertDialog', '_i': 1, 'open': false, 'title': 'Dialog'},
    body: 'Dialog',
  ),
  (
    name: 'Material BottomSheet',
    platform: TargetPlatform.android,
    map: {
      '_c': 'BottomSheet',
      '_i': 1,
      'open': false,
      'content': {'_c': 'Text', '_i': 2, 'value': 'Sheet'},
    },
    body: 'Sheet',
  ),
];

PageRoute<void> _page(TargetPlatform platform, Widget child) =>
    platform == TargetPlatform.iOS
        ? CupertinoPageRoute<void>(
            builder: (_) => CupertinoPageScaffold(child: Center(child: child)))
        : material.MaterialPageRoute<void>(
            builder: (_) => material.Scaffold(body: Center(child: child)));

/// Mounts [control] on the second page of a nested navigator, so popping the
/// wrong route is observable (the navigator could pop that page).
Future<NavigatorState> _host(
    WidgetTester tester, _Backend backend, Control control) async {
  final key = GlobalKey<NavigatorState>();
  final navigator = Navigator(
    key: key,
    onGenerateRoute: (_) => _page(backend.platform, const Text('First page')),
  );
  await tester.pumpWidget(ChangeNotifierProvider<RufletBackend>.value(
    value: backend,
    child: backend.platform == TargetPlatform.iOS
        ? CupertinoApp(home: navigator)
        : material.MaterialApp(home: navigator),
  ));
  key.currentState!.push(_page(
      backend.platform,
      Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('Second page'),
        ControlWidget(control: control),
      ])));
  await tester.pumpAndSettle();
  return key.currentState!;
}

void _set(Control control, bool open) =>
    control.updateProperties({'open': open}, python: false, notify: true);

Future<void> _expectReopens(
    WidgetTester tester, Control control, String body, _Backend backend) async {
  _set(control, true);
  await tester.pumpAndSettle();
  expect(find.text(body), findsOneWidget, reason: 'must reopen');
  _set(control, false);
  await tester.pumpAndSettle();
  expect(find.text(body), findsNothing);
  expect(backend.events.where((e) => e == 'dismiss'), hasLength(2));
}

void main() {
  for (final c in _cases) {
    group(c.name, () {
      late _Backend backend;
      late Control control;
      setUp(() {
        backend = _Backend(c.platform);
        control = Control.fromMap(c.map, backend);
      });

      testWidgets('open: false in the frame that opens it pops nothing',
          (tester) async {
        final navigator = await _host(tester, backend, control);

        _set(control, true);
        // Runs before the control's own post-frame presentation callback,
        // i.e. the close arrives before the route has been pushed.
        SchedulerBinding.instance
            .addPostFrameCallback((_) => _set(control, false));
        await tester.pump();
        await tester.pumpAndSettle();

        expect(find.text('Second page'), findsOneWidget);
        expect(navigator.canPop(), isTrue, reason: 'second page survives');
        expect(find.text(c.body), findsNothing);
        expect(control.get('open'), isFalse);
        expect(backend.events, ['dismiss']);
        expect(tester.takeException(), isNull);

        await _expectReopens(tester, control, c.body, backend);
        expect(find.text('Second page'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('open: false while the route animates in closes only it',
          (tester) async {
        final navigator = await _host(tester, backend, control);

        _set(control, true);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 16));
        _set(control, false);
        await tester.pumpAndSettle();

        expect(find.text('Second page'), findsOneWidget);
        expect(navigator.canPop(), isTrue, reason: 'second page survives');
        expect(find.text(c.body), findsNothing);
        expect(backend.events, ['dismiss']);
        expect(tester.takeException(), isNull);

        await _expectReopens(tester, control, c.body, backend);
        expect(tester.takeException(), isNull);
      });

      testWidgets('open: false under another route removes only the dialog',
          (tester) async {
        final navigator = await _host(tester, backend, control);
        _set(control, true);
        await tester.pumpAndSettle();
        expect(find.text(c.body), findsOneWidget);

        navigator.push(_page(c.platform, const Text('Above')));
        await tester.pumpAndSettle();
        _set(control, false);
        await tester.pumpAndSettle();
        // A rebuild while closing must not pop anything else.
        control
            .updateProperties({'data': 'rebuild'}, python: false, notify: true);
        await tester.pumpAndSettle();

        expect(find.text('Above'), findsOneWidget,
            reason: 'the route above the dialog is not popped');
        expect(backend.events, ['dismiss']);
        expect(tester.takeException(), isNull);
        navigator.pop();
        await tester.pumpAndSettle();
        expect(find.text('Second page'), findsOneWidget);
        expect(find.text(c.body), findsNothing);

        await _expectReopens(tester, control, c.body, backend);
        expect(tester.takeException(), isNull);
      });
    });
  }

  testWidgets('Material BottomSheet keeps the showModalBottomSheet route',
      (tester) async {
    final backend = _Backend(TargetPlatform.android);
    final control = Control.fromMap({
      '_c': 'BottomSheet',
      '_i': 1,
      'open': false,
      'bgcolor': '#123456',
      'barrier_color': '#80112233',
      'show_drag_handle': true,
      'draggable': true,
      'content': {'_c': 'Text', '_i': 2, 'value': 'Sheet'},
    }, backend);
    final navigator = await _host(tester, backend, control);
    _set(control, true);
    await tester.pumpAndSettle();

    final route = ModalRoute.of(tester.element(find.text('Sheet')));
    expect(route, isA<material.ModalBottomSheetRoute<void>>());
    expect(route!.navigator, same(navigator));
    final sheetRoute = route as material.ModalBottomSheetRoute<void>;
    expect(sheetRoute.barrierLabel, 'Scrim');
    expect(sheetRoute.isDismissible, isTrue);
    expect(sheetRoute.enableDrag, isTrue);
    expect(sheetRoute.useSafeArea, isTrue);
    final sheet =
        tester.widget<material.BottomSheet>(find.byType(material.BottomSheet));
    expect(sheet.backgroundColor, const Color(0xFF123456));
    expect(sheet.showDragHandle, isTrue);
    expect(sheetRoute.modalBarrierColor, const Color(0x80112233));

    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(find.text('Sheet'), findsNothing);
    expect(find.text('Second page'), findsOneWidget);
    expect(backend.events, ['dismiss']);
    expect(tester.takeException(), isNull);
  });
}
