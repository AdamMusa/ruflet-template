import 'package:ruflet/ruflet.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_code_editor/flutter_code_editor.dart'
    show CodeField, GutterStyle;

import 'utils/ruflet_code_controller.dart';

class MaterialCodeEditorRenderer extends StatelessWidget {
  final Control control;
  final RufletCodeController controller;
  final FocusNode focusNode;
  final GutterStyle? gutterStyle;

  const MaterialCodeEditorRenderer(
      {super.key,
      required this.control,
      required this.controller,
      required this.focusNode,
      this.gutterStyle});

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        child: CodeField(
          controller: controller,
          focusNode: focusNode,
          readOnly: control.getBool('read_only', false)!,
          textStyle:
              control.getTextStyle('text_style', RufletStyleTheme.of(context)),
          gutterStyle: gutterStyle,
          padding: control.getEdgeInsets('padding', EdgeInsets.zero)!,
          enabled: !control.disabled,
        ),
      );
}
