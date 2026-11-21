// ruflet-coverage: WebView
//
// The ruflet_rails native shell's root navigation (drawer, bottom nav),
// applied to a real View under the page: the View keys its children by id, so
// the new WebView gets a fresh web view that loads its url and handles its
// invokes. 0.0.16 and 0.0.24 send this patch to the View (id 100).
// ignore_for_file: implementation_imports
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:ruflet/ruflet.dart';
import 'package:ruflet/src/models/page_design.dart';
import 'package:ruflet/src/widgets/page_context.dart';
import 'package:ruflet/src/widgets/platform_app.dart';
import 'package:ruflet_webview/ruflet_webview.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

import 'support/fake_webview_platform.dart';
import 'support/harness.dart';

/// The shell's body: a Stack holding the WebView and its loading overlay.
Map<String, dynamic> _body(int stackId, int webViewId, String url) => {
      '_c': 'Stack',
      '_i': stackId,
      '_internals': {'host_positioned': true},
      'fit': 'expand',
      'expand': true,
      'controls': [
        {
          '_c': 'WebView',
          '_i': webViewId,
          'url': url,
          'method': 'get',
          'expand': true,
          'enable_javascript': true,
          'on_page_started': true,
          'on_page_ended': true,
          'on_url_change': true,
        },
        {'_c': 'Container', '_i': stackId + 50, 'visible': false},
      ],
    };

void main() {
  testWidgets(
      'root navigation in the ruflet_rails shell mounts a fresh web view '
      'for the new WebView', (tester) async {
    final platform = FakeWebViewPlatform();
    WebViewPlatform.instance = platform;
    final design = defaultTargetPlatform == TargetPlatform.iOS
        ? PageDesign.cupertino
        : PageDesign.material;
    final backend =
        HarnessBackend(defaultTargetPlatform, extensions: [Extension()]);
    backend.isLoading = false;
    final view = Control.fromMap({
      '_c': 'View',
      '_i': 100,
      'route': '/',
      '_internals': {'host_expanded': true},
      'controls': [_body(101, 102, 'https://myapp.com')],
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
              child: ControlWidget(control: view)),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    List<String> requests() => [
          for (final c in platform.controllers)
            for (final r in c.requests) '${r.method.name} ${r.uri}'
        ];

    // The user follows a link; the bottom nav goes to another root page.
    platform.controllers.single.delegate
        .onPageStarted!('https://myapp.com/company/dashboard');
    view.applyPatch([
      [0],
      [
        0,
        0,
        'controls',
        [_body(119, 120, 'https://myapp.com/company/sms_campaigns')]
      ]
    ], backend);
    await tester.pumpAndSettle();
    expect(platform.controllers, hasLength(2));
    expect(requests(), [
      'get https://myapp.com',
      'get https://myapp.com/company/sms_campaigns',
    ]);

    Object? title;
    unawaited(backend.controlsIndex
        .get(120)!
        .invokeMethod('get_title', null, const Duration(seconds: 2))
        .then((value) => title = value));
    await tester.pump();
    expect(title, 'Ruflet test page');
    expect(platform.controllers.last.calls, contains('getTitle'));
    await unmount(tester);
  }, variant: bothDesigns);
}
