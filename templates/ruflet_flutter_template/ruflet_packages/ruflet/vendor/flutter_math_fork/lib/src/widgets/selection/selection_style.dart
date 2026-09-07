import 'package:flutter/widgets.dart';

class MathSelectionStyle {
  const MathSelectionStyle({
    required this.cursorColor,
    required this.selectionColor,
    required this.controls,
    this.cursorOffset,
    this.cursorRadius,
    this.paintCursorAboveText = false,
    this.cursorOpacityAnimates = false,
    this.forcePressEnabled = false,
  });

  final Color cursorColor, selectionColor;
  final TextSelectionControls controls;
  final Offset? cursorOffset;
  final Radius? cursorRadius;
  final bool paintCursorAboveText, cursorOpacityAnimates, forcePressEnabled;
}
