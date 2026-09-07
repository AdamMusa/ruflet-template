import 'package:flutter/widgets.dart';

import '../models/page_design.dart';
import 'cupertino_runtime_chrome.dart';
import 'material_runtime_chrome.dart';
import 'platform_design.dart';

/// The startup screen used before an embedded runtime can create a Ruflet app.
class PlatformStartupApp extends StatelessWidget {
  final String title;
  final bool isLoading;
  final String message;

  const PlatformStartupApp(
      {super.key,
      this.title = 'Ruflet',
      this.isLoading = true,
      this.message = ''});

  @override
  Widget build(BuildContext context) => switch (effectivePageDesign(context)) {
        PageDesign.cupertino => CupertinoStartupApp(
            title: title, isLoading: isLoading, message: message),
        PageDesign.material => MaterialStartupApp(
            title: title, isLoading: isLoading, message: message),
      };
}
