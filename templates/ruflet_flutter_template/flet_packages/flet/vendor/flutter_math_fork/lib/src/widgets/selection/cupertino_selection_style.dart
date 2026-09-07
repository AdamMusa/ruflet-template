import 'package:flutter/cupertino.dart';

import 'selection_platform.dart';
import 'selection_style.dart';

MathSelectionStyle cupertinoMathSelectionStyle(BuildContext context) {
  final theme = CupertinoTheme.of(context);
  final selection = DefaultSelectionStyle.of(context);
  return MathSelectionStyle(
    cursorColor: selection.cursorColor ?? theme.primaryColor,
    selectionColor: selection.selectionColor ?? theme.primaryColor,
    controls: MathSelectionPlatform.of(context) == TargetPlatform.macOS
        ? cupertinoDesktopTextSelectionControls
        : cupertinoTextSelectionControls,
    cursorOffset: Offset(-2 / MediaQuery.devicePixelRatioOf(context), 0),
    cursorRadius: const Radius.circular(2),
    paintCursorAboveText: true,
    cursorOpacityAnimates: true,
    forcePressEnabled: true,
  );
}

class CupertinoMathSelectionError extends StatefulWidget {
  const CupertinoMathSelectionError({super.key, required this.message});
  final String message;

  @override
  State<CupertinoMathSelectionError> createState() =>
      _CupertinoMathSelectionErrorState();
}

class _CupertinoMathSelectionErrorState
    extends State<CupertinoMathSelectionError> {
  final FocusNode _focus = FocusNode();

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SelectableRegion(
        focusNode: _focus,
        selectionControls: cupertinoTextSelectionHandleControls,
        contextMenuBuilder: (context, state) =>
            CupertinoAdaptiveTextSelectionToolbar.buttonItems(
          anchors: state.contextMenuAnchors,
          buttonItems: state.contextMenuButtonItems,
        ),
        child: Text(widget.message),
      );
}
