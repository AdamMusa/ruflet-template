import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../extensions/control.dart';
import '../models/control.dart';
import '../widgets/error.dart';
import 'base_controls.dart';

class MaterialSelectionAreaControl extends StatelessWidget {
  final Control control;

  const MaterialSelectionAreaControl({super.key, required this.control});

  @override
  Widget build(BuildContext context) {
    final content = control.buildWidget("content");
    if (content == null) {
      return const ErrorControl(
          "SelectionArea.content must be provided and visible");
    }
    return BaseControl(
      control: control,
      child: SelectionArea(
        onSelectionChanged: (SelectedContent? selection) {
          control.triggerEvent("change", selection?.plainText);
        },
        child: content,
      ),
    );
  }
}
