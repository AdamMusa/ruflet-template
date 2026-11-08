import 'package:ruflet/ruflet.dart';
import 'package:ruflet/src/models/page_design.dart';
import 'package:ruflet/src/widgets/page_context.dart';
import 'package:ruflet/src/widgets/platform_app.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' as material;
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

const _statusBar = 54.0;

Future<void> _pumpPage(WidgetTester tester, PageDesign design,
    Map<String, dynamic> appBarProps) async {
  final backend = RufletBackend(
      pageUri: Uri.parse('ruflet://large-app-bar-test'),
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
      'title': {'_c': 'Text', '_i': 103, 'value': 'Inbox'},
      'actions': [
        {'_c': 'Text', '_i': 104, 'value': 'Edit'}
      ],
      ...appBarProps,
    },
    'controls': [
      {'_c': 'Text', '_i': 102, 'value': 'First message'}
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
                padding: EdgeInsets.only(top: _statusBar, bottom: 34)),
            child: ControlWidget(control: view),
          ),
        ),
      ),
    ),
  ));
  await tester.pumpAndSettle();
}

TextStyle? _titleStyle(WidgetTester tester, String text) => tester
    .widget<RichText>(
        find.descendant(of: find.text(text), matching: find.byType(RichText)))
    .text
    .style;

void main() {
  group('Material AppBar(large: true)', () {
    testWidgets('renders the M3 large top app bar in its expanded state',
        (tester) async {
      await _pumpPage(tester, PageDesign.material, {'large': true});

      final bar = tester.widget<material.AppBar>(find.byType(material.AppBar));
      expect(bar.toolbarHeight, 64);
      expect(bar.title, isNull);
      expect(bar.bottom?.preferredSize.height, 88);
      expect(tester.getSize(find.byType(material.AppBar)).height,
          _statusBar + 152);
      expect(tester.getTopLeft(find.text('First message')).dy,
          _statusBar + 152);

      // The title sits in the 88 dp area below the toolbar, inset 16/28 dp.
      final title = find.text('Inbox');
      final titleRect = tester.getRect(title);
      expect(titleRect.top, greaterThanOrEqualTo(_statusBar + 64));
      expect(titleRect.bottom, moreOrLessEquals(_statusBar + 152 - 28));
      expect(titleRect.left, 16);
      // Actions stay in the 64 dp toolbar row.
      final actionRect = tester.getRect(find.text('Edit'));
      expect(actionRect.center.dy, moreOrLessEquals(_statusBar + 32));

      final theme = material.Theme.of(tester.element(title));
      final style = _titleStyle(tester, 'Inbox');
      expect(style?.fontSize, theme.textTheme.headlineMedium?.fontSize);
      expect(style?.color, theme.colorScheme.onSurface);
      expect(tester.takeException(), isNull);
    });

    testWidgets('honors toolbar_height for the toolbar part', (tester) async {
      await _pumpPage(
          tester, PageDesign.material, {'large': true, 'toolbar_height': 72});

      final bar = tester.widget<material.AppBar>(find.byType(material.AppBar));
      expect(bar.toolbarHeight, 72);
      expect(tester.getSize(find.byType(material.AppBar)).height,
          _statusBar + 72 + 88);
      expect(tester.getTopLeft(find.text('First message')).dy,
          _statusBar + 72 + 88);
    });

    testWidgets('applies color and title_text_style to the large title',
        (tester) async {
      await _pumpPage(tester, PageDesign.material, {
        'large': true,
        'color': '#112233',
      });
      expect(_titleStyle(tester, 'Inbox')?.color, const Color(0xFF112233));

      await _pumpPage(tester, PageDesign.material, {
        'large': true,
        'title_text_style': {'size': 40},
      });
      expect(_titleStyle(tester, 'Inbox')?.fontSize, 40);
    });

    testWidgets('large: false keeps the standard toolbar', (tester) async {
      await _pumpPage(tester, PageDesign.material, {});

      final bar = tester.widget<material.AppBar>(find.byType(material.AppBar));
      expect(bar.title, isNotNull);
      expect(bar.bottom, isNull);
      expect(bar.toolbarHeight, material.kToolbarHeight);
      expect(tester.getSize(find.byType(material.AppBar)).height,
          _statusBar + material.kToolbarHeight);
      expect(tester.getRect(find.text('Inbox')).center.dy,
          moreOrLessEquals(_statusBar + material.kToolbarHeight / 2));
    });
  });

  testWidgets('Cupertino AppBar(large: true) is unchanged', (tester) async {
    await _pumpPage(tester, PageDesign.cupertino, {'large': true});

    final expected = const CupertinoNavigationBar.large(largeTitle: Text('t'))
        .preferredSize
        .height;
    expect(find.byType(material.AppBar), findsNothing);
    expect(find.byType(material.Theme), findsNothing);
    expect(find.byType(CupertinoNavigationBar), findsOneWidget);
    expect(tester.getSize(find.byType(CupertinoNavigationBar)).height,
        _statusBar + expected);
    expect(
        tester.getTopLeft(find.text('First message')).dy, _statusBar + expected);
    expect(_titleStyle(tester, 'Inbox')?.fontSize, 34);
    expect(tester.takeException(), isNull);
  });
}
