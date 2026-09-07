import 'package:flutter/cupertino.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

import '../models/control.dart';
import '../utils/cupertino_theme.dart';
import '../utils/numbers.dart';
import 'base_controls.dart';
import 'cupertino_selection_area.dart';
import 'platform_markdown_body.dart';

class CupertinoMarkdownControl extends StatelessWidget {
  final Control control;

  const CupertinoMarkdownControl({super.key, required this.control});

  @override
  Widget build(BuildContext context) {
    final cupertinoTheme = CupertinoTheme.of(context);
    Widget body = PlatformMarkdownBody(
      control: control,
      parserTheme: cupertinoStyleTheme(context),
      baseStyleSheet: MarkdownStyleSheet.fromCupertinoTheme(cupertinoTheme),
      baseTheme: MarkdownStyleSheetBaseTheme.cupertino,
    );
    if (control.getBool("selectable", false)!) {
      body = CupertinoSelectableRegion(
        onSelectionChanged: (selection) =>
            triggerMarkdownSelection(control, selection?.plainText ?? ""),
        child: body,
      );
    }
    return LayoutControl(control: control, child: body);
  }
}
