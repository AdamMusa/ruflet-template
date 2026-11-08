import 'dart:math' as math;

import 'package:ruflet/ruflet.dart';
import 'package:ruflet/src/models/page_design.dart';
import 'package:ruflet/src/widgets/page_context.dart';
import 'package:ruflet/src/widgets/platform_app.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'control_renderer_matrix_test.dart' show materialOnly;

const _topInset = 54.0;
const _bottomInset = 34.0;

/// Flutter's kFloatingActionButtonMargin (Material Scaffold).
const _margin = 16.0;

Map<String, dynamic> _text(int id, String value) =>
    {'_c': 'Text', '_i': id, 'value': value};

/// A Ruby-shaped View with a floating_action_button and, optionally, a
/// navigation_bar and the persistent bottom_sheet slot.
Future<void> _showView(WidgetTester tester, PageDesign design,
    {String? location,
    bool navigationBar = true,
    bool bottomSheet = false,
    double sheetHeight = 64}) async {
  final backend = RufletBackend(
      pageUri: Uri.parse('ruflet://view-fab'),
      assetsDir: '',
      multiView: false,
      extensions: []);
  backend.isLoading = false;
  backend.platform = design == PageDesign.cupertino
      ? TargetPlatform.iOS
      : TargetPlatform.android;
  final view = Control.fromMap({
    '_c': 'View',
    '_i': 100,
    'padding': 0,
    'controls': [_text(101, 'Body')],
    'floating_action_button': {
      '_c': 'FloatingActionButton',
      '_i': 130,
      'key': 'fab',
      'content': _text(131, '+'),
    },
    if (location != null) 'floating_action_button_location': location,
    if (bottomSheet)
      'bottom_sheet': {
        '_c': 'Container',
        '_i': 110,
        'key': 'sheet',
        'height': sheetHeight,
        'bgcolor': '#123456',
        'content': _text(111, 'Checkout'),
      },
    if (navigationBar)
      'navigation_bar': {
        '_c': 'NavigationBar',
        '_i': 120,
        'key': 'nav',
        'destinations': [
          {
            '_c': 'NavigationBarDestination',
            '_i': 121,
            'label': 'Shop',
            'icon': _text(122, 'S'),
          },
          {
            '_c': 'NavigationBarDestination',
            '_i': 123,
            'label': 'Cart',
            'icon': _text(124, 'C'),
          },
        ],
      },
  }, backend, parent: backend.page);
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
          child: MediaQuery(
            data: const MediaQueryData(
                size: Size(800, 600),
                padding: EdgeInsets.only(top: _topInset, bottom: _bottomInset),
                viewPadding:
                    EdgeInsets.only(top: _topInset, bottom: _bottomInset)),
            child: ControlWidget(control: view),
          ),
        ),
      ),
    ),
  ));
  await tester.pumpAndSettle();
}

/// Ruby `key:` becomes a `ValueKey<dynamic>` on the control's widget.
Rect _rect(WidgetTester tester, String key) => tester.getRect(find
    .byWidgetPredicate(
        (w) => w.key is ValueKey && (w.key as ValueKey).value == key)
    .first);

bool _overlaps(Rect a, Rect b) => a.intersect(b).height > 0.01;

/// Every location spelling the Cupertino scaffold recognises: default (end,
/// bottom) plus start/center/end x Float/Docked/Top.
const _locations = <String?>[
  null,
  'endFloat',
  'centerFloat',
  'startFloat',
  'endDocked',
  'centerDocked',
  'startDocked',
  'endTop',
  'centerTop',
  'startTop',
];

bool _isTop(String? location) => location?.endsWith('Top') ?? false;

void _expectHorizontal(Rect fab, String? location) {
  final name = location ?? 'end';
  if (name.startsWith('start')) {
    expect(fab.left, closeTo(_margin, 0.01), reason: '$location left margin');
  } else if (name.startsWith('center')) {
    expect(fab.center.dx, closeTo(400, 0.01), reason: '$location centered');
  } else {
    expect(fab.right, closeTo(800 - _margin, 0.01),
        reason: '$location right margin');
  }
}

void main() {
  for (final location in _locations) {
    final top = _isTop(location);

    testWidgets('iOS FAB $location keeps clear of the navigation_bar',
        (tester) async {
      await _showView(tester, PageDesign.cupertino, location: location);
      final fab = _rect(tester, 'fab');
      final nav = _rect(tester, 'nav');

      expect(fab.height, greaterThan(0));
      expect(_overlaps(fab, nav), isFalse,
          reason: 'FAB $fab must not cover the tab bar $nav');
      _expectHorizontal(fab, location);
      if (top) {
        expect(fab.top, _topInset + _margin);
      } else {
        // Docked is treated as float: CupertinoTabBar has no notch.
        expect(fab.bottom, nav.top - _margin);
      }
      expect(find.byWidgetPredicate(materialOnly), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('iOS FAB $location clears the persistent bottom_sheet',
        (tester) async {
      await _showView(tester, PageDesign.cupertino,
          location: location, bottomSheet: true);
      final fab = _rect(tester, 'fab');
      final nav = _rect(tester, 'nav');
      final sheet = _rect(tester, 'sheet');

      expect(sheet.bottom, nav.top);
      expect(_overlaps(fab, nav), isFalse);
      _expectHorizontal(fab, location);
      if (top) {
        expect(fab.top, _topInset + _margin);
        expect(_overlaps(fab, sheet), isFalse);
      } else {
        // Material's FabFloatOffsetY: min(margin above the bar, centred on
        // the sheet's top edge).
        final expectedTop = math.min(
            nav.top - _margin - fab.height, sheet.top - fab.height / 2);
        expect(fab.top, closeTo(expectedTop, 0.01));
        expect(fab.center.dy, lessThanOrEqualTo(sheet.top + 0.01),
            reason: 'at most the upper half of the FAB rests on the sheet');
      }
      expect(tester.takeException(), isNull);
    });
  }

  for (final location in [null, 'startFloat', 'centerTop']) {
    testWidgets('iOS FAB $location respects the bottom safe area',
        (tester) async {
      await _showView(tester, PageDesign.cupertino,
          location: location, navigationBar: false);
      final fab = _rect(tester, 'fab');
      _expectHorizontal(fab, location);
      if (_isTop(location)) {
        expect(fab.top, _topInset + _margin);
      } else {
        expect(fab.bottom, 600 - _bottomInset - _margin);
      }
      expect(tester.takeException(), isNull);
    });
  }

  // The other side of FabFloatOffsetY: a sheet shorter than
  // margin + fabHeight / 2 does not lift the FAB, which keeps its standard
  // margin above the bar (the FAB then overlaps the top of the thin sheet,
  // exactly like Material's Scaffold).
  for (final design in PageDesign.values) {
    for (final location in [null, 'centerFloat', 'startDocked']) {
      if (design == PageDesign.material && location == 'startDocked') {
        continue; // Material docks on the bar by design.
      }
      testWidgets(
          '$design FAB $location keeps its margin above a short bottom_sheet',
          (tester) async {
        await _showView(tester, design,
            location: location, bottomSheet: true, sheetHeight: 20);
        final fab = _rect(tester, 'fab');
        final nav = _rect(tester, 'nav');
        final sheet = _rect(tester, 'sheet');

        expect(sheet.height, 20);
        expect(sheet.bottom, nav.top);
        // margin + fabHeight / 2 > 20: the sheet does not lift the FAB.
        expect(_margin + fab.height / 2, greaterThan(sheet.height));
        expect(fab.bottom, closeTo(nav.top - _margin, 0.01));
        expect(
            fab.top,
            closeTo(
                math.min(
                    nav.top - _margin - fab.height, sheet.top - fab.height / 2),
                0.01));
        expect(_overlaps(fab, nav), isFalse);
        _expectHorizontal(fab, location);
        if (design == PageDesign.cupertino) {
          expect(find.byWidgetPredicate(materialOnly), findsNothing);
        }
        expect(tester.takeException(), isNull);
      });
    }
  }

  // The Material Scaffold is the reference the iOS layout follows.
  for (final location in [null, 'centerFloat', 'startFloat']) {
    testWidgets('Material reference FAB $location sits above bar and sheet',
        (tester) async {
      await _showView(tester, PageDesign.material, location: location);
      var fab = _rect(tester, 'fab');
      var nav = _rect(tester, 'nav');
      expect(fab.bottom, nav.top - _margin);
      _expectHorizontal(fab, location);

      await _showView(tester, PageDesign.material,
          location: location, bottomSheet: true);
      fab = _rect(tester, 'fab');
      nav = _rect(tester, 'nav');
      final sheet = _rect(tester, 'sheet');
      expect(fab.top,
          math.min(nav.top - _margin - fab.height, sheet.top - fab.height / 2));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Material reference FAB respects the bottom safe area',
      (tester) async {
    await _showView(tester, PageDesign.material, navigationBar: false);
    expect(_rect(tester, 'fab').bottom, 600 - _bottomInset - _margin);
    expect(tester.takeException(), isNull);
  });
}
