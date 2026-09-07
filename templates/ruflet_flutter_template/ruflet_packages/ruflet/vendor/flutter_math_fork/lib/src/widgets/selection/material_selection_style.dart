import 'package:flutter/material.dart';

import 'selection_style.dart';

MathSelectionStyle materialMathSelectionStyle(BuildContext context) {
  final theme = Theme.of(context);
  final selection = TextSelectionTheme.of(context);
  return MathSelectionStyle(
    cursorColor: selection.cursorColor ?? theme.colorScheme.primary,
    selectionColor: selection.selectionColor ?? theme.colorScheme.primary,
    controls: materialTextSelectionControls,
  );
}

class MaterialMathSelectionError extends StatelessWidget {
  const MaterialMathSelectionError({super.key, required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => SelectableText(message);
}
