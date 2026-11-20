// A Dart fake of webview_flutter's platform interface: the native web view
// cannot render in widget tests, so the fake records what the WebView control
// hands the plugin and lets tests fire the plugin's callbacks.
import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

class FakeWebViewPlatform extends WebViewPlatform {
  final List<FakeWebViewController> controllers = [];
  final List<FakeNavigationDelegate> delegates = [];

  FakeWebViewController get controller => controllers.single;

  @override
  PlatformWebViewController createPlatformWebViewController(
      PlatformWebViewControllerCreationParams params) {
    final controller = FakeWebViewController(params);
    controllers.add(controller);
    return controller;
  }

  @override
  PlatformNavigationDelegate createPlatformNavigationDelegate(
      PlatformNavigationDelegateCreationParams params) {
    final delegate = FakeNavigationDelegate(params);
    delegates.add(delegate);
    return delegate;
  }

  @override
  PlatformWebViewWidget createPlatformWebViewWidget(
          PlatformWebViewWidgetCreationParams params) =>
      FakeWebViewWidget(params);
}

/// Stands in for the native view: fills the space the control gives it.
class FakeWebViewWidget extends PlatformWebViewWidget {
  FakeWebViewWidget(super.params) : super.implementation();

  static const viewKey = ValueKey('fake-native-webview');

  @override
  Widget build(BuildContext context) => const SizedBox.expand(key: viewKey);
}

class FakeNavigationDelegate extends PlatformNavigationDelegate {
  FakeNavigationDelegate(super.params) : super.implementation();

  NavigationRequestCallback? onNavigationRequest;
  PageEventCallback? onPageStarted;
  PageEventCallback? onPageFinished;
  ProgressCallback? onProgress;
  WebResourceErrorCallback? onWebResourceError;
  UrlChangeCallback? onUrlChange;

  @override
  Future<void> setOnNavigationRequest(
      NavigationRequestCallback onNavigationRequest) async {
    this.onNavigationRequest = onNavigationRequest;
  }

  @override
  Future<void> setOnPageStarted(PageEventCallback onPageStarted) async {
    this.onPageStarted = onPageStarted;
  }

  @override
  Future<void> setOnPageFinished(PageEventCallback onPageFinished) async {
    this.onPageFinished = onPageFinished;
  }

  @override
  Future<void> setOnProgress(ProgressCallback onProgress) async {
    this.onProgress = onProgress;
  }

  @override
  Future<void> setOnWebResourceError(
      WebResourceErrorCallback onWebResourceError) async {
    this.onWebResourceError = onWebResourceError;
  }

  @override
  Future<void> setOnUrlChange(UrlChangeCallback onUrlChange) async {
    this.onUrlChange = onUrlChange;
  }

  @override
  Future<void> setOnHttpError(HttpResponseErrorCallback onHttpError) async {}

  @override
  Future<void> setOnHttpAuthRequest(
      HttpAuthRequestCallback onHttpAuthRequest) async {}

  @override
  Future<void> setOnSSlAuthError(SslAuthErrorCallback onSslAuthError) async {}
}

class FakeWebViewController extends PlatformWebViewController {
  FakeWebViewController(super.params) : super.implementation();

  /// Every plugin call, as `name` or `name(args)`, in order.
  final List<String> calls = [];
  final List<LoadRequestParams> requests = [];
  PlatformNavigationDelegate? navigationDelegate;
  Color? backgroundColor;

  bool canGoBackValue = false;
  bool canGoForwardValue = false;
  String? currentUrlValue = 'https://ruflet.test/current';
  String? titleValue = 'Ruflet test page';
  String? userAgentValue = 'RufletTestAgent/1.0';

  void Function(ScrollPositionChange change)? onScrollPositionChange;
  void Function(JavaScriptConsoleMessage message)? onConsoleMessage;
  Future<void> Function(JavaScriptAlertDialogRequest request)? onAlertDialog;

  FakeNavigationDelegate get delegate =>
      navigationDelegate! as FakeNavigationDelegate;

  Future<T> _record<T>(String call, T value) async {
    calls.add(call);
    return value;
  }

  @override
  Future<void> loadRequest(LoadRequestParams params) {
    requests.add(params);
    return _record('loadRequest(${params.method.name} ${params.uri})', null);
  }

  @override
  Future<void> loadFile(String absoluteFilePath) =>
      _record('loadFile($absoluteFilePath)', null);

  @override
  Future<void> loadHtmlString(String html, {String? baseUrl}) =>
      _record('loadHtmlString($html, baseUrl: $baseUrl)', null);

  @override
  Future<void> setPlatformNavigationDelegate(
      PlatformNavigationDelegate handler) {
    navigationDelegate = handler;
    return _record('setPlatformNavigationDelegate', null);
  }

  @override
  Future<String?> currentUrl() => _record('currentUrl', currentUrlValue);

  @override
  Future<bool> canGoBack() => _record('canGoBack', canGoBackValue);

  @override
  Future<bool> canGoForward() => _record('canGoForward', canGoForwardValue);

  @override
  Future<void> goBack() => _record('goBack', null);

  @override
  Future<void> goForward() => _record('goForward', null);

  @override
  Future<void> reload() => _record('reload', null);

  @override
  Future<void> clearCache() => _record('clearCache', null);

  @override
  Future<void> clearLocalStorage() => _record('clearLocalStorage', null);

  @override
  Future<void> runJavaScript(String javaScript) =>
      _record('runJavaScript($javaScript)', null);

  @override
  Future<String?> getTitle() => _record('getTitle', titleValue);

  @override
  Future<void> scrollTo(int x, int y) => _record('scrollTo($x, $y)', null);

  @override
  Future<void> scrollBy(int x, int y) => _record('scrollBy($x, $y)', null);

  @override
  Future<void> enableZoom(bool enabled) =>
      _record('enableZoom($enabled)', null);

  @override
  Future<void> setBackgroundColor(Color color) {
    backgroundColor = color;
    return _record('setBackgroundColor', null);
  }

  @override
  Future<void> setJavaScriptMode(JavaScriptMode javaScriptMode) =>
      _record('setJavaScriptMode(${javaScriptMode.name})', null);

  @override
  Future<String?> getUserAgent() => _record('getUserAgent', userAgentValue);

  @override
  Future<void> setOnConsoleMessage(
      void Function(JavaScriptConsoleMessage consoleMessage) onConsoleMessage) {
    this.onConsoleMessage = onConsoleMessage;
    return _record('setOnConsoleMessage', null);
  }

  @override
  Future<void> setOnScrollPositionChange(
      void Function(ScrollPositionChange scrollPositionChange)?
          onScrollPositionChange) {
    this.onScrollPositionChange = onScrollPositionChange;
    return _record('setOnScrollPositionChange', null);
  }

  @override
  Future<void> setOnJavaScriptAlertDialog(
      Future<void> Function(JavaScriptAlertDialogRequest request)
          onJavaScriptAlertDialog) {
    onAlertDialog = onJavaScriptAlertDialog;
    return _record('setOnJavaScriptAlertDialog', null);
  }
}
