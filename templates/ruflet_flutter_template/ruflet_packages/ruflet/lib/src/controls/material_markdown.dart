import '../utils/material_style_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

import '../models/control.dart';
import '../utils/numbers.dart';
import 'base_controls.dart';
import 'platform_markdown_body.dart';

class MaterialMarkdownControl extends StatelessWidget {
  final Control control;

  const MaterialMarkdownControl({super.key, required this.control});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget body = PlatformMarkdownBody(
      control: control,
      parserTheme: materialStyleTheme(theme),
      baseStyleSheet: MarkdownStyleSheet.fromTheme(theme),
      baseTheme: MarkdownStyleSheetBaseTheme.material,
    );
    if (control.getBool("selectable", false)!) {
      body = SelectionArea(
        onSelectionChanged: (selection) =>
            triggerMarkdownSelection(control, selection?.plainText ?? ""),
        child: body,
      );
    }
    return LayoutControl(control: control, child: body);
  }
}
