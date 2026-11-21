import 'package:flutter/material.dart';
import '../extensions/control.dart';
import '../models/control.dart';
import '../widgets/error.dart';

class MaterialContextMenuActionControl extends StatelessWidget {
  final Control control;

  const MaterialContextMenuActionControl({super.key, required this.control});

  @override
  Widget build(BuildContext context) {
    var content = control.buildTextOrWidget("content");
    if (content == null) {
      return const ErrorControl("ContextMenuAction.content must be provided");
    }
    return MenuItemButton(
      leadingIcon: control.buildIconOrWidget("icon"),
      onPressed: control.disabled ? null : () => control.triggerEvent("click"),
      child: content,
    );
  }
}
