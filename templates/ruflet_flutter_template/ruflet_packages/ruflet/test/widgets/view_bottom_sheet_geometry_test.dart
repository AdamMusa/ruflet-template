import 'package:ruflet/ruflet.dart';
import 'package:ruflet/src/models/page_design.dart';
import 'package:ruflet/src/widgets/page_context.dart';
import 'package:ruflet/src/widgets/platform_app.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'control_renderer_matrix_test.dart' show materialOnly;

const _bottomInset = 34.0;

Map<String, dynamic> _text(int id, String value) =>
    {'_c': 'Text', '_i': id, 'value': value};

/// A View with the persistent `bottom_sheet` slot (ruflet #27) and,
/// optionally, a `navigation_bar`.
Future<void> _showView(WidgetTester tester, PageDesign design,
    {required bool navigationBar}) async {
  final backend = RufletBackend(
      pageUri: Uri.parse('ruflet://view-bottom-sheet'),
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
    'controls': [
      {
        '_c': 'Container',
        '_i': 101,
        'key': 'body',
        'expand': true,
        'content': _text(102, 'Cart items'),
      }
    ],
    'bottom_sheet': {
      '_c': 'Container',
      '_i': 110,
      'key': 'sheet',
      'height': 64,
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
                padding: EdgeInsets.only(top: 54, bottom: _bottomInset),
                viewPadding: EdgeInsets.only(top: 54, bottom: _bottomInset)),
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

void main() {
  for (final design in PageDesign.values) {
    final ios = design == PageDesign.cupertino;

    testWidgets('$design View bottom_sheet sits on top of the navigation_bar',
        (tester) async {
      await _showView(tester, design, navigationBar: true);

      final sheet = _rect(tester, 'sheet');
      final nav = _rect(tester, 'nav');
      expect(sheet.height, 64);
      expect(nav.height, greaterThan(0));
      expect(sheet.bottom, nav.top,
          reason: 'the sheet stands on the bar instead of covering it');
      expect(find.text('Shop'), findsOneWidget);
      expect(tester.getRect(find.text('Shop')).top,
          greaterThanOrEqualTo(sheet.bottom));
      // The bar (not the sheet) owns the home-indicator inset.
      expect(tester.getRect(find.text('Shop')).bottom,
          lessThanOrEqualTo(600 - _bottomInset));
      // Like Scaffold.bottomSheet, the sheet floats over the body area.
      expect(tester.getRect(find.text('Cart items')).top, lessThan(sheet.top));
      if (ios) {
        expect(find.byWidgetPredicate(materialOnly), findsNothing);
      } else {
        expect(find.byType(CupertinoPageScaffold), findsNothing);
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('$design View bottom_sheet respects the bottom safe area',
        (tester) async {
      await _showView(tester, design, navigationBar: false);

      final sheet = _rect(tester, 'sheet');
      expect(sheet.height, 64);
      if (ios) {
        // Above the home indicator.
        expect(sheet.bottom, 600 - _bottomInset);
        expect(tester.getRect(find.text('Checkout')).bottom,
            lessThanOrEqualTo(600 - _bottomInset));
        expect(find.byWidgetPredicate(materialOnly), findsNothing);
      } else {
        // Material reference (unchanged by this fix): Scaffold.bottomSheet
        // runs to the screen edge; Flutter does not inset its content.
        expect(sheet.bottom, 600);
      }
      expect(tester.takeException(), isNull);
    });
  }
}
