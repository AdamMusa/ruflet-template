import 'package:flutter/cupertino.dart';

import '../extensions/control.dart';
import '../models/control.dart';
import '../utils/edge_insets.dart';
import '../widgets/error.dart';
import 'base_controls.dart';

/// iOS form row: [CupertinoFormRow] with a leading label, an end-aligned
/// field, and optional helper and error lines below.
class CupertinoFormRowControl extends StatelessWidget {
  final Control control;

  const CupertinoFormRowControl({super.key, required this.control});

  @override
  Widget build(BuildContext context) {
    debugPrint("CupertinoFormRow build: ${control.id}");

    final content = control.buildWidget("content");
    if (content == null) {
      return const ErrorControl("FormRow.content must be provided and visible");
    }

    return LayoutControl(
      control: control,
      child: CupertinoFormRow(
        prefix: control.buildTextOrWidget("prefix"),
        helper: control.buildTextOrWidget("helper"),
        error: control.buildTextOrWidget("error"),
        padding: control.getPadding("padding"),
        child: content,
      ),
    );
  }
}
