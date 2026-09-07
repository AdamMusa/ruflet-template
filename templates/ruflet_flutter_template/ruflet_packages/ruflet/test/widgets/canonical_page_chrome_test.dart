import 'package:ruflet/ruflet.dart';
import 'package:ruflet/src/models/page_design.dart';
import 'package:ruflet/src/widgets/page_context.dart';
import 'package:ruflet/src/widgets/platform_app.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' as material;
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  for (final design in PageDesign.values) {
    testWidgets('canonical $design AppBar preserves renderer size metadata',
        (tester) async {
      final backend = RufletBackend(
          pageUri: Uri.parse('ruflet://test'),
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
        'appbar': {
          '_c': 'AppBar',
          '_i': 101,
          'title': {'_c': 'Text', '_i': 103, 'value': 'Canonical navigation'},
          'large': true,
          'toolbar_height': 88,
        },
        'controls': [
          {'_c': 'Text', '_i': 102, 'value': 'First visible control'}
        ],
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
                    padding: EdgeInsets.only(top: 54, bottom: 34)),
                child: ControlWidget(control: view),
              ),
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      final expectedBarHeight = design == PageDesign.cupertino
          ? const CupertinoNavigationBar.large(largeTitle: Text('title'))
              .preferredSize
              .height
          : 88;
      expect(tester.getTopLeft(find.text('First visible control')).dy,
          54 + expectedBarHeight);
      if (design == PageDesign.cupertino) {
        expect(find.byType(material.Theme), findsNothing);
        expect(tester.getSize(find.byType(CupertinoNavigationBar)).height,
            54 + expectedBarHeight);
        final titleText = tester.widget<RichText>(find.descendant(
            of: find.text('Canonical navigation'),
            matching: find.byType(RichText)));
        expect(titleText.text.style?.fontSize, 34);
        expect(titleText.text.style?.fontWeight, FontWeight.w700);
      } else {
        expect(tester.getSize(find.byType(material.AppBar)).height,
            54 + expectedBarHeight);
      }
      expect(tester.takeException(), isNull);
    });
  }
}
