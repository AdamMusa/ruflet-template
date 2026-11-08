import 'package:ruflet/ruflet.dart';
import 'package:flutter/widgets.dart';

class WebviewDesktop extends StatelessWidget {
  const WebviewDesktop({super.key});

  @override
  Widget build(BuildContext context) {
    return const ErrorControl("Webview is not yet supported on this Platform.");
  }
}
