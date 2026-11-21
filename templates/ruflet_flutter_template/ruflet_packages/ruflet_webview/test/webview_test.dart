// ruflet-coverage: WebView
//
// The WebView control mounted from the protocol map Ruby sends, on the
// Cupertino (TargetPlatform.iOS) and Material (TargetPlatform.android) hosts.
// The native view cannot render in widget tests, so webview_flutter's
// platform interface is faked: the tests assert what the control hands the
// plugin, the values invokes return to Ruby and the events Ruby receives.
import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ruflet/ruflet.dart';
import 'package:ruflet_webview/ruflet_webview.dart';
import 'package:ruflet_webview/src/webview.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

import 'support/fake_webview_platform.dart';
import 'support/harness.dart';

const _timeout = Duration(seconds: 2);

Map<String, dynamic> _wire([Map<String, dynamic> props = const {}]) => {
      '_c': 'WebView',
      '_i': 7,
      'url': 'https://ruflet.test/start',
      ...props,
    };

void main() {
  late FakeWebViewPlatform platform;

  setUp(() {
    platform = FakeWebViewPlatform();
    WebViewPlatform.instance = platform;
  });

  /// Runs [name] the way the backend does for a Ruby `page.invoke`, letting
  /// the plugin's futures complete.
  Future<({Object? value, Object? error})> invoke(
      WidgetTester tester, Control control, String name,
      [Object? args]) async {
    ({Object? value, Object? error})? outcome;
    unawaited(control.invokeMethod(name, args, _timeout).then(
        (value) => outcome = (value: value, error: null),
        onError: (Object error) => outcome = (value: null, error: error)));
    await tester.pump();
    return outcome!;
  }

  test('the extension creates WebView for its wire type only', () {
    final backend = HarnessBackend(TargetPlatform.android, extensions: []);
    Control control(String type) =>
        Control(id: 1, type: type, properties: {}, backend: backend);

    expect(Extension().createWidget(null, control('WebView')),
        isA<WebViewControl>());
    expect(Extension().createWidget(null, control('Text')), isNull);
  });

  testWidgets('loads url with GET and fills the size Ruby gives it',
      (tester) async {
    final mounted = await mountWire(
        tester, _wire({'width': 320, 'height': 240}), Extension());

    expect(tester.takeException(), isNull);
    final controller = platform.controller;
    expect(controller.requests, hasLength(1));
    expect(
        controller.requests.single.uri, Uri.parse('https://ruflet.test/start'));
    expect(controller.requests.single.method, LoadRequestMethod.get);
    expect(controller.navigationDelegate, same(platform.delegates.single));
    expect(tester.getSize(find.byKey(FakeWebViewWidget.viewKey)),
        const Size(320, 240));
    expect(
        tester.getTopLeft(find.byKey(FakeWebViewWidget.viewKey)), Offset.zero);
    // Nothing was subscribed, so no optional plugin handler is installed.
    expect(
        controller.calls,
        isNot(anyOf(
            contains('setOnScrollPositionChange'),
            contains('setOnConsoleMessage'),
            contains('setOnJavaScriptAlertDialog'))));
    expect(mounted.backend.events, isEmpty);
    await unmount(tester);
  }, variant: bothDesigns);

  testWidgets('loads url with the request method Ruby sends', (tester) async {
    await mountWire(tester, _wire({'method': 'post'}), Extension());

    expect(tester.takeException(), isNull);
    expect(platform.controller.requests.single.method, LoadRequestMethod.post);
    await unmount(tester);
  }, variant: bothDesigns);

  testWidgets('bgcolor sets the plugin background color', (tester) async {
    await mountWire(tester, _wire({'bgcolor': '#336699'}), Extension());

    expect(platform.controller.backgroundColor, const Color(0xff336699));
    await unmount(tester);
  }, variant: bothDesigns);

  testWidgets('navigation callbacks reach Ruby only when it subscribed',
      (tester) async {
    final subscribed = await mountWire(
        tester,
        _wire({
          'on_page_started': true,
          'on_page_ended': true,
          'on_progress': true,
          'on_url_change': true,
          'on_web_resource_error': true,
        }),
        Extension());
    final delegate = platform.controller.delegate;

    delegate.onPageStarted!('https://ruflet.test/a');
    delegate.onProgress!(42);
    delegate.onUrlChange!(const UrlChange(url: 'https://ruflet.test/b'));
    delegate.onPageFinished!('https://ruflet.test/b');
    delegate.onWebResourceError!(
        const WebResourceError(errorCode: -2, description: 'host not found'));

    expect(subscribed.backend.events, [
      [7, 'page_started', 'https://ruflet.test/a'],
      [7, 'progress', 42],
      [7, 'url_change', 'https://ruflet.test/b'],
      [7, 'page_ended', 'https://ruflet.test/b'],
      [7, 'web_resource_error', 'host not found'],
    ]);
    await unmount(tester);

    final unsubscribed = await mountWire(tester, _wire(), Extension());
    final quiet = platform.controllers.last.delegate;
    quiet.onPageStarted!('https://ruflet.test/a');
    quiet.onProgress!(10);
    quiet.onPageFinished!('https://ruflet.test/a');
    expect(unsubscribed.backend.events, isEmpty);
    await unmount(tester);
  }, variant: bothDesigns);

  testWidgets('prevent_links blocks navigations to those prefixes only',
      (tester) async {
    await mountWire(
        tester,
        _wire({
          'prevent_links': ['https://blocked.test/', 'mailto:']
        }),
        Extension());
    final decide = platform.controller.delegate.onNavigationRequest!;

    NavigationDecision decision(String url) =>
        decide(NavigationRequest(url: url, isMainFrame: true))
            as NavigationDecision;

    expect(decision('https://blocked.test/page'), NavigationDecision.prevent);
    expect(decision('mailto:someone@ruflet.test'), NavigationDecision.prevent);
    expect(decision('https://ruflet.test/page'), NavigationDecision.navigate);
    // A prefix, not a substring: a link that only mentions a blocked url.
    expect(decision('https://ruflet.test/?next=https://blocked.test/'),
        NavigationDecision.navigate);
    await unmount(tester);

    await mountWire(tester, _wire(), Extension());
    final open = platform.controllers.last.delegate.onNavigationRequest!;
    expect(
        open(const NavigationRequest(
            url: 'https://blocked.test/page', isMainFrame: true)),
        NavigationDecision.navigate);
    await unmount(tester);
  }, variant: bothDesigns);

  testWidgets(
      'scroll, console and alert handlers install when Ruby subscribes '
      'and send their payloads', (tester) async {
    final mounted = await mountWire(
        tester,
        _wire({
          'on_scroll': true,
          'on_console_message': true,
          'on_javascript_alert_dialog': true,
        }),
        Extension());
    final controller = platform.controller;

    controller.onScrollPositionChange!(const ScrollPositionChange(12, 340));
    controller.onConsoleMessage!(const JavaScriptConsoleMessage(
        level: JavaScriptLogLevel.warning, message: 'careful'));
    await controller.onAlertDialog!(const JavaScriptAlertDialogRequest(
        message: 'Hello from JS', url: 'https://ruflet.test/start'));

    expect(mounted.backend.events, [
      [
        7,
        'scroll',
        {'x': 12.0, 'y': 340.0}
      ],
      [
        7,
        'console_message',
        {'message': 'careful', 'severity_level': 'warning'}
      ],
      [
        7,
        'javascript_alert_dialog',
        {'message': 'Hello from JS', 'url': 'https://ruflet.test/start'}
      ],
    ]);
    await unmount(tester);
  }, variant: bothDesigns);

  testWidgets('a handler Ruby subscribes after mounting is installed once',
      (tester) async {
    final mounted = await mountWire(tester, _wire(), Extension());
    final controller = platform.controller;
    expect(controller.calls, isNot(contains('setOnConsoleMessage')));

    mounted.control.update({'on_console_message': true}, shouldNotify: true);
    await tester.pump();
    mounted.control.update({'width': 200}, shouldNotify: true);
    await tester.pump();

    expect(controller.calls.where((c) => c == 'setOnConsoleMessage'),
        hasLength(1));
    controller.onConsoleMessage!(const JavaScriptConsoleMessage(
        level: JavaScriptLogLevel.log, message: 'late'));
    expect(mounted.backend.eventData('console_message'), [
      {'message': 'late', 'severity_level': 'log'}
    ]);
    await unmount(tester);
  }, variant: bothDesigns);

  testWidgets('invoke methods drive the plugin and return its values to Ruby',
      (tester) async {
    final mounted = await mountWire(tester, _wire(), Extension());
    final control = mounted.control;
    final controller = platform.controller;
    controller.calls.clear();

    // (method, args, plugin calls, value returned to Ruby)
    final cases = <(String, Map<String, dynamic>?, List<String>, Object?)>[
      ('reload', null, ['reload'], null),
      ('can_go_back', null, ['canGoBack'], false),
      ('can_go_forward', null, ['canGoForward'], false),
      // Nothing to go back or forward to: only the check reaches the plugin.
      ('go_back', null, ['canGoBack'], null),
      ('go_forward', null, ['canGoForward'], null),
      ('enable_zoom', null, ['enableZoom(true)'], null),
      ('disable_zoom', null, ['enableZoom(false)'], null),
      ('clear_cache', null, ['clearCache'], null),
      ('clear_local_storage', null, ['clearLocalStorage'], null),
      ('get_current_url', null, ['currentUrl'], 'https://ruflet.test/current'),
      ('get_title', null, ['getTitle'], 'Ruflet test page'),
      ('get_user_agent', null, ['getUserAgent'], 'RufletTestAgent/1.0'),
      (
        'load_file',
        {'path': '/data/page.html'},
        ['loadFile(/data/page.html)'],
        null
      ),
      (
        'load_html',
        {'value': '<p>Hi</p>', 'base_url': 'https://ruflet.test/'},
        ['loadHtmlString(<p>Hi</p>, baseUrl: https://ruflet.test/)'],
        null
      ),
      (
        'load_html',
        {'value': '<p>Bare</p>'},
        ['loadHtmlString(<p>Bare</p>, baseUrl: null)'],
        null
      ),
      (
        'load_request',
        {'url': 'https://ruflet.test/next', 'method': 'get'},
        ['loadRequest(get https://ruflet.test/next)'],
        null
      ),
      (
        'load_request',
        {'url': 'https://ruflet.test/form', 'method': 'post'},
        ['loadRequest(post https://ruflet.test/form)'],
        null
      ),
      (
        'run_javascript',
        {'value': "document.title = 'x'"},
        ["runJavaScript(document.title = 'x')"],
        null
      ),
      ('scroll_to', {'x': 10, 'y': 20}, ['scrollTo(10, 20)'], null),
      ('scroll_by', {'x': -5, 'y': 15}, ['scrollBy(-5, 15)'], null),
      (
        'set_javascript_mode',
        {'mode': 'unrestricted'},
        ['setJavaScriptMode(unrestricted)'],
        null
      ),
      (
        'set_javascript_mode',
        {'mode': 'disabled'},
        ['setJavaScriptMode(disabled)'],
        null
      ),
    ];

    for (final (method, args, calls, value) in cases) {
      controller.calls.clear();
      final outcome = await invoke(tester, control, method, args);
      expect(outcome.error, isNull, reason: method);
      expect(outcome.value, value, reason: method);
      expect(controller.calls, calls, reason: '$method($args)');
    }

    // With history, go_back/go_forward navigate and the checks report it.
    controller
      ..canGoBackValue = true
      ..canGoForwardValue = true
      ..calls.clear();
    expect((await invoke(tester, control, 'can_go_back')).value, isTrue);
    expect((await invoke(tester, control, 'can_go_forward')).value, isTrue);
    await invoke(tester, control, 'go_back');
    await invoke(tester, control, 'go_forward');
    expect(controller.calls, [
      'canGoBack',
      'canGoForward',
      'canGoBack',
      'goBack',
      'canGoForward',
      'goForward'
    ]);
    await unmount(tester);
  }, variant: bothDesigns);

  testWidgets('invokes missing a required argument fail back to Ruby',
      (tester) async {
    final mounted = await mountWire(tester, _wire(), Extension());
    final controller = platform.controller..calls.clear();

    final noPath = await invoke(tester, mounted.control, 'load_file', {});
    expect(noPath.error, isA<ArgumentError>());
    expect('${noPath.error}', contains('"path"'));

    final noValue = await invoke(tester, mounted.control, 'load_html');
    expect(noValue.error, isA<ArgumentError>());
    expect('${noValue.error}', contains('"value"'));

    final unknown = await invoke(tester, mounted.control, 'print_page');
    expect('${unknown.error}', contains('Unknown WebView method: print_page'));

    expect(controller.calls, isEmpty);
    await unmount(tester);
  }, variant: bothDesigns);

  testWidgets('disposing stops handling Ruby invokes', (tester) async {
    final mounted = await mountWire(tester, _wire(), Extension());
    await unmount(tester);
    final controller = platform.controller..calls.clear();

    // The control is no longer rendered, so the invoke waits for a listener
    // that never comes and times out (on the test's fake clock).
    Object? error;
    unawaited(mounted.control
        .invokeMethod('reload', null, const Duration(milliseconds: 10))
        .catchError((Object e) => error = e));
    await tester.pump(const Duration(milliseconds: 20));

    expect(error, isA<TimeoutException>());
    expect(controller.calls, isEmpty);
  }, variant: bothDesigns);

  testWidgets('a url or method Ruby changes after mounting is loaded',
      (tester) async {
    final mounted = await mountWire(
        tester, _wire({'width': 320, 'height': 240}), Extension());
    final controller = platform.controller;

    // Ruby: webview.url = "..."; page.update
    mounted.control
        .update({'url': 'https://ruflet.test/second'}, shouldNotify: true);
    await tester.pump();
    // Other changes do not reload the page the user may have navigated on.
    mounted.control
        .update({'width': 300, 'bgcolor': '#112233'}, shouldNotify: true);
    await tester.pump();
    mounted.control.update({'method': 'post'}, shouldNotify: true);
    await tester.pump();

    expect([
      for (final r in controller.requests) '${r.method.name} ${r.uri}'
    ], [
      'get https://ruflet.test/start',
      'get https://ruflet.test/second',
      'post https://ruflet.test/second',
    ]);
    expect(platform.controllers, hasLength(1));
    await unmount(tester);
  }, variant: bothDesigns);

  testWidgets(
      'a url the view reported, written back by Ruby, does not reload the page',
      (tester) async {
    // The ruflet_rails native shell subscribes to these events and stores
    // each url in the WebView's `url`; its next bare page.update (opening a
    // native menu or sheet) sends that url back.
    final mounted = await mountWire(
        tester,
        _wire({
          '_i': 102,
          'url': 'https://myapp.com',
          'method': 'get',
          'expand': true,
          'on_page_started': true,
          'on_page_ended': true,
          'on_url_change': true,
        }),
        Extension());
    final controller = platform.controller;
    final delegate = controller.delegate;
    List<String> requests() =>
        [for (final r in controller.requests) '${r.method.name} ${r.uri}'];

    // The user follows a link inside the page (a Turbo visit).
    delegate.onUrlChange!(const UrlChange(url: 'https://myapp.com/posts/new'));
    // The exact patch ruflet_rails 0.0.23 sends when the menu opens.
    mounted.control.applyPatch([
      [0],
      [0, 0, 'url', 'https://myapp.com/posts/new']
    ], mounted.backend);
    await tester.pump();
    expect(requests(), ['get https://myapp.com']);

    // A form POST re-rendered at /posts, then a later url: Ruby writing
    // back either one (even the older one, if its update was sent before it
    // saw the newer url) does not replace the page with a GET.
    delegate.onPageStarted!('https://myapp.com/posts');
    delegate.onPageFinished!('https://myapp.com/posts');
    delegate.onUrlChange!(const UrlChange(url: 'https://myapp.com/posts#form'));
    for (final echo in [
      'https://myapp.com/posts',
      'https://myapp.com/posts#form',
    ]) {
      mounted.control.applyPatch([
        [0],
        [0, 0, 'url', echo]
      ], mounted.backend);
      await tester.pump();
    }
    expect(requests(), ['get https://myapp.com']);

    // A url the view never reported is a navigation Ruby asks for.
    mounted.control
        .update({'url': 'https://myapp.com/posts/1'}, shouldNotify: true);
    await tester.pump();
    expect(
        requests(), ['get https://myapp.com', 'get https://myapp.com/posts/1']);
    await unmount(tester);
  }, variant: bothDesigns);

  testWidgets(
      'only urls Ruby was told about count as written back, '
      'and a load starts a new count', (tester) async {
    final mounted = await mountWire(
        tester,
        _wire({'width': 320, 'height': 240, 'on_url_change': true}),
        Extension());
    final controller = platform.controller;
    final delegate = controller.delegate;
    List<String> requests() =>
        [for (final r in controller.requests) '${r.method.name} ${r.uri}'];

    // Ruby is not subscribed to page_started, so it cannot be echoing it.
    delegate.onPageStarted!('https://ruflet.test/a');
    mounted.control
        .update({'url': 'https://ruflet.test/a'}, shouldNotify: true);
    await tester.pump();
    // Ruby was told about b, so b coming back is not loaded.
    delegate.onUrlChange!(const UrlChange(url: 'https://ruflet.test/b'));
    mounted.control
        .update({'url': 'https://ruflet.test/b'}, shouldNotify: true);
    await tester.pump();
    expect(requests(), [
      'get https://ruflet.test/start',
      'get https://ruflet.test/a',
    ]);

    // After Ruby loads another url, b is a navigation again.
    for (final url in ['https://ruflet.test/c', 'https://ruflet.test/b']) {
      mounted.control.update({'url': url}, shouldNotify: true);
      await tester.pump();
    }
    // To load a page the view reported since its last load, Ruby calls
    // load_request.
    delegate.onUrlChange!(const UrlChange(url: 'https://ruflet.test/d'));
    mounted.control
        .update({'url': 'https://ruflet.test/d'}, shouldNotify: true);
    await tester.pump();
    await invoke(tester, mounted.control, 'load_request',
        {'url': 'https://ruflet.test/d', 'method': 'get'});
    expect(requests(), [
      'get https://ruflet.test/start',
      'get https://ruflet.test/a',
      'get https://ruflet.test/c',
      'get https://ruflet.test/b',
      'get https://ruflet.test/d',
    ]);
    await unmount(tester);
  }, variant: bothDesigns);

  testWidgets(
      'a url Ruby echoes moves the last load, and a method change '
      'with a reported url is loaded', (tester) async {
    final mounted = await mountWire(
        tester,
        _wire({'width': 320, 'height': 240, 'on_url_change': true}),
        Extension());
    final controller = platform.controller;
    final delegate = controller.delegate;
    List<String> requests() =>
        [for (final r in controller.requests) '${r.method.name} ${r.uri}'];

    // The user goes to b and Ruby writes it back; Ruby then sets the url it
    // mounted with, which the view is no longer on, so it is loaded.
    delegate.onUrlChange!(const UrlChange(url: 'https://ruflet.test/b'));
    mounted.control
        .update({'url': 'https://ruflet.test/b'}, shouldNotify: true);
    await tester.pump();
    mounted.control
        .update({'url': 'https://ruflet.test/start'}, shouldNotify: true);
    await tester.pump();
    expect(requests(), [
      'get https://ruflet.test/start',
      'get https://ruflet.test/start',
    ]);

    // A reported url sent with another method is a request Ruby asks for.
    delegate.onUrlChange!(const UrlChange(url: 'https://ruflet.test/form'));
    mounted.control.update(
        {'url': 'https://ruflet.test/form', 'method': 'post'},
        shouldNotify: true);
    await tester.pump();
    expect(requests(), [
      'get https://ruflet.test/start',
      'get https://ruflet.test/start',
      'post https://ruflet.test/form',
    ]);
    await unmount(tester);
  }, variant: bothDesigns);

  testWidgets(
      'a WebView Ruby puts in place of another in a parent that does not key '
      'its children handles its invokes and follows the url rule',
      (tester) async {
    // A Column (like a Stack, Row or Container content) does not key its
    // children by id, so Flutter keeps the web view state for a new WebView
    // control in the same slot. (A View keys its children, so the ruflet_rails
    // shell's root navigation mounts a fresh web view, see
    // webview_in_view_test.dart.)
    List<Map<String, dynamic>> controls(int id, String url) => [
          {'_c': 'Text', '_i': id, 'value': 'Count $id'},
          {
            '_c': 'WebView',
            '_i': id + 1,
            'url': url,
            'method': 'get',
            'width': 300,
            'height': 200,
            'on_url_change': true,
          },
        ];
    final mounted = await mountWire(
        tester,
        {
          '_c': 'Column',
          '_i': 1,
          'controls': controls(10, 'https://docs.test/'),
        },
        Extension());
    final controller = platform.controller;
    List<String> requests() =>
        [for (final r in controller.requests) '${r.method.name} ${r.uri}'];
    Control webView(int id) => mounted.backend.controlsIndex.get(id)!;
    Future<void> rerender(int id, String url) async {
      mounted.control.applyPatch([
        [0],
        [0, 0, 'controls', controls(id, url)]
      ], mounted.backend);
      await tester.pumpAndSettle();
    }

    // The user follows a link; Ruby re-renders the Column (new ids) with the
    // same url. The page the user is on is kept, as on a url update.
    controller.delegate
        .onUrlChange!(const UrlChange(url: 'https://docs.test/guide#install'));
    await rerender(20, 'https://docs.test/');
    expect(requests(), ['get https://docs.test/']);
    expect(platform.controllers, hasLength(1));

    // Invokes on the new control reach the plugin; the old one's do not.
    controller.calls.clear();
    expect((await invoke(tester, webView(21), 'get_title')).value,
        'Ruflet test page');
    unawaited(webView(11)
        .invokeMethod('reload', null, const Duration(milliseconds: 10))
        .catchError((Object _) {}));
    await tester.pump(const Duration(milliseconds: 20));
    expect(controller.calls, ['getTitle']);

    // A url the view has not had is loaded.
    await rerender(30, 'https://docs.test/api');
    expect(requests(), ['get https://docs.test/', 'get https://docs.test/api']);
    expect((await invoke(tester, webView(31), 'get_title')).value,
        'Ruflet test page');
    await unmount(tester);
  }, variant: bothDesigns);

  testWidgets(
      'macOS renders the native view but skips the scroll handler '
      'webview_flutter does not surface there', (tester) async {
    await mountWire(tester,
        _wire({'on_scroll': true, 'on_console_message': true}), Extension());

    final controller = platform.controller;
    expect(
        controller.requests.single.uri, Uri.parse('https://ruflet.test/start'));
    expect(controller.calls, contains('setOnConsoleMessage'));
    expect(controller.calls, isNot(contains('setOnScrollPositionChange')));
    expect(find.byKey(FakeWebViewWidget.viewKey), findsOneWidget);
    await unmount(tester);
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

  testWidgets('desktop hosts without a web view show an error, not a crash',
      (tester) async {
    await mountWire(tester, _wire(), Extension());

    expect(tester.takeException(), isNull);
    expect(platform.controllers, isEmpty);
    expect(find.textContaining('Webview is not yet supported'), findsOneWidget);
    await unmount(tester);
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));
}
