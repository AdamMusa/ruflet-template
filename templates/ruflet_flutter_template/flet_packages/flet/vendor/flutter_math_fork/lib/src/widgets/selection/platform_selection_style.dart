import 'package:flutter/widgets.dart';

import 'cupertino_selection_style.dart';
import 'material_selection_style.dart';
import 'selection_platform.dart';
import 'selection_style.dart';

MathSelectionStyle mathSelectionStyle(BuildContext context) =>
    MathSelectionPlatform.usesCupertino(context)
        ? cupertinoMathSelectionStyle(context)
        : materialMathSelectionStyle(context);

class PlatformMathSelectionError extends StatelessWidget {
  const PlatformMathSelectionError({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) =>
      MathSelectionPlatform.usesCupertino(context)
          ? CupertinoMathSelectionError(message: message)
          : MaterialMathSelectionError(message: message);
}
