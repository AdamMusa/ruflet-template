import 'package:ruflet/ruflet.dart';
import 'package:ruflet/src/models/page_design.dart';
import 'package:ruflet/src/widgets/page_context.dart';
import 'package:ruflet/src/widgets/platform_app.dart';
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
            pageUri: Uri.parse('ruflet://view-refresh-test'),
            assetsDir: '',
            multiView: false,
            extensions: []) {
    platform = target;
    isLoading = false;
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

bool _materialOnly(Widget widget) =>
    widget is material.Material ||
    widget is material.Theme ||
    widget is material.Scaffold ||
    widget is material.InkResponse ||
    widget is material.RefreshIndicator ||
    widget is material.ProgressIndicator;

Map<String, dynamic> _view(Map<String, dynamic> props,
        {List<Map<String, dynamic>>? controls}) =>
    {
      '_c': 'View',
      '_i': 100,
      // Ruby marks View/Row/Column as flex hosts for `expand` children.
      '_internals': {'host_expanded': true},
      'padding': 0,
      'appbar': {
        '_c': 'AppBar',
        '_i': 101,
        'title': {'_c': 'Text', '_i': 102, 'value': 'Inbox'},
      },
      'floating_action_button': {
        '_c': 'FloatingActionButton',
        '_i': 103,
        'content': {'_c': 'Text', '_i': 104, 'value': 'Add'},
      },
      'controls': controls ??
          [
            {'_c': 'Text', '_i': 110, 'value': 'First'},
            {'_c': 'Text', '_i': 111, 'value': 'Second'},
          ],
      ...props,
    };

Future<(_Backend, Control)> _pumpView(
    WidgetTester tester, PageDesign design, Map<String, dynamic> props,
    {List<Map<String, dynamic>>? controls}) async {
  final backend = _Backend(design == PageDesign.cupertino
      ? TargetPlatform.iOS
      : TargetPlatform.android);
  final view = Control.fromMap(_view(props, controls: controls), backend,
      parent: backend.page);
  backend.page.update({
    'views': [view]
  }, shouldNotify: false);
  await tester.pumpWidget(ChangeNotifierProvider<RufletBackend>.value(
    value: backend,
    child: PlatformApp(
      design: design,
      config: PlatformAppConfig(
        title: 'test',
        showSemanticsDebugger: false,
        themeMode: RufletThemeMode.light,
        routerDelegate: null,
        routeInformationParser: null,
        routeInformationProvider: null,
        localizationsDelegates: const [],
        supportedLocales: const [Locale('en')],
        locale: const Locale('en'),
        home: PageContext(
          widgetsDesign: design,
          themeMode: RufletThemeMode.light,
          brightness: Brightness.light,
          child: ControlWidget(control: view),
        ),
      ),
    ),
  ));
  await tester.pumpAndSettle();
  return (backend, view);
}

Finder _appBar(PageDesign design) => design == PageDesign.cupertino
    ? find.byType(CupertinoNavigationBar)
    : find.byType(material.AppBar);

Finder _spinner(PageDesign design) => design == PageDesign.cupertino
    ? find.byType(CupertinoActivityIndicator)
    : find.byType(material.RefreshProgressIndicator);

Future<void> _pull(WidgetTester tester, PageDesign design) async {
  if (design == PageDesign.cupertino) {
    final gesture =
        await tester.startGesture(tester.getCenter(find.text('First')));
    for (var i = 0; i < 10; i++) {
      await gesture.moveBy(const Offset(0, 40));
      await tester.pump();
    }
    await gesture.up();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  } else {
    await tester.fling(find.text('First'), const Offset(0, 300), 1000);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
  }
}

Future<void> _endRefresh(WidgetTester tester, Control view) async {
  var done = false;
  view
      .invokeMethod('end_refresh', null, const Duration(seconds: 1))
      .then((_) => done = true);
  for (var i = 0; i < 20 && !done; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
  expect(done, isTrue, reason: 'the View answers end_refresh');
}

void main() {
  for (final design in PageDesign.values) {
    final platform = design == PageDesign.cupertino
        ? TargetPlatform.iOS
        : TargetPlatform.android;
    final variant = TargetPlatformVariant.only(platform);

    testWidgets('$design View on_refresh keeps the page chrome geometry',
        (tester) async {
      Future<List<Rect>> rects(bool refresh) async {
        await _pumpView(tester, design, {if (refresh) 'on_refresh': true});
        expect(tester.takeException(), isNull);
        return [
          tester.getRect(_appBar(design)),
          tester.getRect(find.text('First')),
          tester.getRect(find.text('Second')),
          tester.getRect(find.text('Add')),
        ];
      }

      final plain = await rects(false);
      await tester.pumpWidget(const SizedBox());
      expect(await rects(true), plain);
    }, variant: variant);

    testWidgets('$design View pull fires refresh and settles on end_refresh',
        (tester) async {
      final (backend, view) =
          await _pumpView(tester, design, {'on_refresh': true});
      if (design == PageDesign.cupertino) {
        expect(find.byType(CupertinoSliverRefreshControl, skipOffstage: false),
            findsOneWidget);
        expect(find.byWidgetPredicate(_materialOnly), findsNothing);
      } else {
        expect(find.byType(material.RefreshIndicator), findsOneWidget);
      }
      final firstTop = tester.getTopLeft(find.text('First'));

      await _pull(tester, design);
      expect(backend.named('refresh'), [null]);
      expect(_spinner(design), findsOneWidget);
      if (design == PageDesign.cupertino) {
        expect(find.byWidgetPredicate(_materialOnly), findsNothing);
      }

      await _endRefresh(tester, view);
      await tester.pumpAndSettle();
      expect(_spinner(design), findsNothing);
      expect(tester.getTopLeft(find.text('First')), firstTop);
      expect(tester.takeException(), isNull);
    }, variant: variant);

    for (final scrolling in [
      {'scroll': 'auto'},
      {'on_refresh': true}
    ]) {
      testWidgets('$design $scrolling View on_end_reached reports a short page',
          (tester) async {
        final (backend, _) = await _pumpView(
            tester, design, {...scrolling, 'on_end_reached': true});
        expect(backend.named('end_reached'), hasLength(1));
        expect(backend.named('end_reached').single['max_scroll_extent'], 0.0);
      }, variant: variant);
    }

    testWidgets('$design refreshable View keeps expand children flexing',
        (tester) async {
      await _pumpView(tester, design, {
        'on_refresh': true
      }, controls: [
        {'_c': 'Text', '_i': 110, 'value': 'First'},
        {
          '_c': 'Container',
          '_i': 120,
          'expand': true,
          'content': {'_c': 'Text', '_i': 121, 'value': 'Fill'},
        },
      ]);
      expect(tester.takeException(), isNull);
      final fill = tester.getRect(find.byWidgetPredicate(
          (widget) => widget is ControlWidget && widget.control.id == 120));
      final bar = tester.getRect(_appBar(design));
      expect(fill.height, greaterThan(300),
          reason: 'the expand child fills the rest of the page');
      expect(fill.top, greaterThan(bar.bottom));
    }, variant: variant);
  }
}
