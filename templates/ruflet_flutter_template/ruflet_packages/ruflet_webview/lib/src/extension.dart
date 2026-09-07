import 'package:ruflet/ruflet.dart';
import 'package:flutter/cupertino.dart';

import 'webview.dart';

class Extension extends RufletExtension {
  @override
  Widget? createWidget(Key? key, Control control) {
    switch (control.type) {
      case "WebView":
        return WebViewControl(control: control);
      default:
        return null;
    }
  }
}
