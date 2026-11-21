import 'package:flutter/cupertino.dart';

import '../utils/cupertino_theme.dart' show cupertinoStyleTheme;
import 'checkbox_core.dart';

/// Cupertino skin of [CheckboxCore]: maps the core's values onto
/// [CupertinoCheckbox].
class CupertinoCheckboxSkin extends StatelessWidget {
  const CupertinoCheckboxSkin({super.key, required this.core});

  final CheckboxCore core;

  @override
  Widget build(BuildContext context) {
    final p = core.props;
    var labelStyle = p.labelStyle;
    if (core.disabled) {
      labelStyle =
          (labelStyle ?? CupertinoTheme.of(context).textTheme.textStyle)
              .copyWith(color: cupertinoStyleTheme(context).color('disabled'));
    }
    return core.labelled(
      CupertinoCheckbox(
        value: core.value,
        tristate: p.tristate,
        onChanged: core.onChanged,
        focusNode: core.focusNode,
        autofocus: p.autofocus,
        semanticLabel: p.semanticsLabel,
        shape: p.shape,
        side: p.borderSide,
        activeColor: p.activeColor,
        focusColor: p.focusColor,
        checkColor: p.checkColor,
        fillColor: p.fillColor,
        mouseCursor: p.mouseCursor,
      ),
      labelStyle: labelStyle,
      defaultSpacing: 10,
    );
  }
}
