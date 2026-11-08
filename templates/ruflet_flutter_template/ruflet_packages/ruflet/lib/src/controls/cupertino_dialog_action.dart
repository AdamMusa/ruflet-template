import 'package:flutter/cupertino.dart';

import '../widgets/error.dart';
import 'button_core.dart';

/// Cupertino skin of [ButtonCore] for a button inside an AlertDialog:
/// the native CupertinoDialogAction with its default/destructive roles.
class CupertinoDialogActionSkin extends StatelessWidget {
  const CupertinoDialogActionSkin({super.key, required this.core});

  final ButtonCore core;

  @override
  Widget build(BuildContext context) {
    final p = core.props;
    final content = p.content?.build();
    if (content == null) {
      return const ErrorControl(
          "CupertinoDialogAction.content must be a string or visible Control");
    }
    return CupertinoDialogAction(
      isDefaultAction: p.isDefault,
      isDestructiveAction: p.isDestructive,
      textStyle: p.textStyle,
      onPressed: core.onClick,
      child: content,
    );
  }
}
