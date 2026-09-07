import 'package:flutter/widgets.dart';

import '../models/page_design.dart';
import 'cupertino_runtime_chrome.dart';
import 'material_runtime_chrome.dart';
import 'platform_design.dart';

class ErrorControl extends StatelessWidget {
  final String message;
  final String? description;

  const ErrorControl(this.message, {super.key, this.description});

  @override
  Widget build(BuildContext context) => switch (effectivePageDesign(context)) {
        PageDesign.cupertino =>
          CupertinoErrorControl(message, description: description),
        PageDesign.material =>
          MaterialErrorControl(message, description: description),
      };
}
