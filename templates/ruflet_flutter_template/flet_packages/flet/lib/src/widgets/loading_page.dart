import 'package:flutter/widgets.dart';

import '../models/page_design.dart';
import 'cupertino_runtime_chrome.dart';
import 'material_runtime_chrome.dart';
import 'platform_design.dart';

class LoadingPage extends StatelessWidget {
  final bool isLoading;
  final String message;

  const LoadingPage(
      {super.key, required this.isLoading, required this.message});

  @override
  Widget build(BuildContext context) => switch (effectivePageDesign(context)) {
        PageDesign.cupertino =>
          CupertinoLoadingPage(isLoading: isLoading, message: message),
        PageDesign.material =>
          MaterialLoadingPage(isLoading: isLoading, message: message),
      };
}
