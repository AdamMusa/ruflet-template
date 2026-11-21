import 'package:flutter/material.dart';
import '../extensions/control.dart';
import '../models/control.dart';
import '../utils/numbers.dart';
import '../widgets/error.dart';
import 'base_controls.dart';

class MaterialActionSheetControl extends StatelessWidget {
  final Control control;

  const MaterialActionSheetControl({super.key, required this.control});

  @override
  Widget build(BuildContext context) {
    var actions = control.buildWidgets("actions");
    if (actions.isEmpty && control.buildWidget("cancel") == null) {
      return const ErrorControl(
          "ActionSheet requires an action or cancel button");
    }
    var theme = Theme.of(context);
    var title = control.buildTextOrWidget("title",
        textStyle: theme.textTheme.titleLarge);
    var message = control.buildTextOrWidget("message",
        textStyle: theme.textTheme.bodyMedium);
    var cancel = control.buildWidget("cancel");
    return LayoutControl(
      control: control,
      child: SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (title != null)
            Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                child: title),
          if (message != null)
            Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: message),
          ...actions,
          if (cancel != null) const Divider(height: 1),
          if (cancel != null) cancel,
        ]),
      ),
    );
  }
}

class MaterialActionSheetActionControl extends StatelessWidget {
  final Control control;

  const MaterialActionSheetActionControl({super.key, required this.control});

  @override
  Widget build(BuildContext context) {
    var theme = Theme.of(context);
    var destructive = control.getBool("destructive", false)!;
    var isDefault = control.getBool("default", false)!;
    var content = control.buildTextOrWidget(
      "content",
      textStyle: theme.textTheme.labelLarge?.copyWith(
        color: destructive ? theme.colorScheme.error : null,
        fontWeight: isDefault ? FontWeight.bold : null,
      ),
    );
    if (content == null) {
      return const ErrorControl("ActionSheetAction.content must be provided");
    }
    return ListTile(
      enabled: !control.disabled,
      title: content,
      onTap: control.disabled ? null : () => control.triggerEvent("click"),
    );
  }
}
