import 'package:ruflet/ruflet.dart';
import 'package:ruflet_webview/src/utils/webview.dart';
import 'package:flutter/widgets.dart';
import 'package:webview_flutter/webview_flutter.dart';

class WebviewMobileAndMac extends StatefulWidget {
  final Control control;

  const WebviewMobileAndMac({super.key, required this.control});

  @override
  State<WebviewMobileAndMac> createState() => _WebviewMobileAndMacState();
}

class _WebviewMobileAndMacState extends State<WebviewMobileAndMac> {
  late WebViewController controller;
  bool _scrollHandlerRegistered = false;
  bool _consoleHandlerRegistered = false;
  bool _alertHandlerRegistered = false;
  String? _loadedUrl;
  String? _loadedMethod;

  /// The urls this view reported to Ruby (`page_started`, `page_ended`,
  /// `url_change`) since it last loaded the control's `url`.
  final Set<String> _reportedUrls = {};

  bool _shouldPreventNavigation(String url) {
    final links = widget.control.get<List>("prevent_links");
    if (links == null || links.isEmpty) return false;
    return links.any((link) => link is String && url.startsWith(link));
  }

  void _setOptionalEventHandlers() {
    // macOS currently does not surface scroll callbacks via webview_flutter.
    if (!isMacOSDesktop() &&
        !_scrollHandlerRegistered &&
        widget.control.hasEventHandler("scroll")) {
      try {
        controller.setOnScrollPositionChange((ScrollPositionChange position) {
          widget.control
              .triggerEvent("scroll", {"x": position.x, "y": position.y});
        });
        _scrollHandlerRegistered = true;
      } catch (e) {
        debugPrint("WebView.on_scroll is not available on this platform: $e");
      }
    }

    if (!_consoleHandlerRegistered &&
        widget.control.hasEventHandler("console_message")) {
      try {
        controller.setOnConsoleMessage((JavaScriptConsoleMessage message) {
          widget.control.triggerEvent("console_message", {
            "message": message.message,
            "severity_level": message.level.name,
          });
        });
        _consoleHandlerRegistered = true;
      } catch (e) {
        debugPrint(
            "WebView.on_console_message is not available on this platform: $e");
      }
    }

    if (!_alertHandlerRegistered &&
        widget.control.hasEventHandler("javascript_alert_dialog")) {
      try {
        controller.setOnJavaScriptAlertDialog(
            (JavaScriptAlertDialogRequest request) async {
          widget.control.triggerEvent(
            "javascript_alert_dialog",
            {"message": request.message, "url": request.url},
          );
        });
        _alertHandlerRegistered = true;
      } catch (e) {
        debugPrint(
            "WebView.on_javascript_alert_dialog is not available on this platform: $e");
      }
    }
  }

  @override
  void initState() {
    super.initState();
    widget.control.addInvokeMethodListener(_invokeMethod);

    var params = const PlatformWebViewControllerCreationParams();
    controller = WebViewController.fromPlatformCreationParams(params);

    controller.setNavigationDelegate(
      NavigationDelegate(
        onProgress: (int progress) {
          widget.control.triggerEvent("progress", progress);
        },
        onUrlChange: (UrlChange url) {
          _reportUrl("url_change", url.url);
        },
        onPageStarted: (String url) {
          _reportUrl("page_started", url);
        },
        onPageFinished: (String url) {
          _reportUrl("page_ended", url);
        },
        onWebResourceError: (WebResourceError error) {
          widget.control.triggerEvent("web_resource_error", error.description);
        },
        onNavigationRequest: (NavigationRequest request) {
          return _shouldPreventNavigation(request.url)
              ? NavigationDecision.prevent
              : NavigationDecision.navigate;
        },
      ),
    );

    _loadUrlIfChanged();
    _setOptionalEventHandlers();
  }

  @override
  void didUpdateWidget(covariant WebviewMobileAndMac oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.control, widget.control)) {
      // A parent that does not key its children by id (Stack, Column, Row,
      // Container content) keeps this state for a new WebView control Ruby
      // puts in the same slot, so Ruby's invokes on it must reach this view.
      // Its url follows the same rule as a url update: the page the user is
      // on is kept unless the url or method is one this view has not had.
      oldWidget.control.removeInvokeMethodListener(_invokeMethod);
      widget.control.addInvokeMethodListener(_invokeMethod);
    }
    _loadUrlIfChanged();
  }

  /// Sends [eventName] with [url] to Ruby and, when Ruby subscribed to it,
  /// remembers that Ruby has been told about [url].
  void _reportUrl(String eventName, String? url) {
    widget.control.triggerEvent(eventName, url);
    if (url != null && widget.control.hasEventHandler(eventName)) {
      _reportedUrls.add(url);
    }
  }

  /// Loads the control's `url` with its `method` when either differs from
  /// the last request made for them, so a `url` Ruby changes after mounting
  /// is navigated to, while other updates keep the page the user is on.
  ///
  /// A `url` this view itself reported to Ruby since its last load is not
  /// loaded again: that is Ruby writing back a page the user navigated to
  /// (the ruflet_rails shell stores every reported url in `url`, and its next
  /// update sends it), and reloading it would drop the user's form input and
  /// scroll position, or replace a page a POST rendered with a GET.
  void _loadUrlIfChanged() {
    final url = widget.control.getString("url", "https://flet.dev")!;
    final method = widget.control.getString("method");
    if (url == _loadedUrl && method == _loadedMethod) return;
    final echoed = method == _loadedMethod && _reportedUrls.contains(url);
    _loadedUrl = url;
    _loadedMethod = method;
    if (echoed) return;
    _reportedUrls.clear();
    controller.loadRequest(Uri.parse(url),
        method: parseLoadRequestMethod(method, LoadRequestMethod.get)!);
  }

  Future<dynamic> _invokeMethod(String name, dynamic args) async {
    debugPrint("WebView.$name($args)");
    switch (name) {
      case "reload":
        await controller.reload();
        break;
      case "can_go_back":
        return controller.canGoBack();
      case "can_go_forward":
        return controller.canGoForward();
      case "go_back":
        if (await controller.canGoBack()) {
          await controller.goBack();
        }
        break;
      case "go_forward":
        if (await controller.canGoForward()) {
          await controller.goForward();
        }
        break;
      case "enable_zoom":
        await controller.enableZoom(true);
        break;
      case "disable_zoom":
        await controller.enableZoom(false);
        break;
      case "clear_cache":
        await controller.clearCache();
        break;
      case "clear_local_storage":
        await controller.clearLocalStorage();
        break;
      case "get_current_url":
        return await controller.currentUrl();
      case "get_title":
        return await controller.getTitle();
      case "get_user_agent":
        return await controller.getUserAgent();
      case "load_file":
        await controller.loadFile(
            requireInvokeArg(args, "path", "WebView.$name").toString());
        break;
      case "load_html":
        await controller.loadHtmlString(
            requireInvokeArg(args, "value", "WebView.$name").toString(),
            baseUrl: args["base_url"]?.toString());
        break;
      case "load_request":
        var url = args["url"];
        if (url != null) {
          await controller.loadRequest(Uri.parse(url.toString()),
              method: parseLoadRequestMethod(
                  args["method"], LoadRequestMethod.get)!);
        }
        break;
      case "run_javascript":
        var javascript = args["value"];
        if (javascript != null) {
          await controller.runJavaScript(javascript.toString());
        }
        break;
      case "scroll_to":
        var x = parseInt(args["x"]);
        var y = parseInt(args["y"]);
        if (x != null && y != null) {
          await controller.scrollTo(x, y);
        }
        break;
      case "scroll_by":
        var x = parseInt(args["x"]);
        var y = parseInt(args["y"]);
        if (x != null && y != null) {
          await controller.scrollBy(x, y);
        }
        break;
      case "set_javascript_mode":
        var mode = parseJavaScriptMode(args["mode"]);
        if (mode != null) {
          await controller.setJavaScriptMode(mode);
        }
        break;
      default:
        throw Exception("Unknown WebView method: $name");
    }
  }

  @override
  void dispose() {
    debugPrint("WebViewControl dispose: ${widget.control.id}");
    widget.control.removeInvokeMethodListener(_invokeMethod);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    debugPrint("WebViewControl build: ${widget.control.id}");

    _setOptionalEventHandlers();

    var bgcolor = widget.control.getColor("bgcolor", context);

    if (bgcolor != null) {
      controller.setBackgroundColor(bgcolor);
    }
    return WebViewWidget(controller: controller);
  }
}
