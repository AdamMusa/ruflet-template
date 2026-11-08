import 'package:flutter/material.dart';

import '../utils/theme.dart' show parseVisualDensity;
import 'checkbox_core.dart';

/// Material skin of [CheckboxCore]: maps the core's values onto [Checkbox].
class MaterialCheckboxSkin extends StatelessWidget {
  const MaterialCheckboxSkin({super.key, required this.core});

  final CheckboxCore core;

  @override
  Widget build(BuildContext context) {
    final p = core.props;
    var labelStyle = p.labelStyle;
    if (core.disabled && labelStyle != null) {
      labelStyle = labelStyle.apply(color: Theme.of(context).disabledColor);
    }
    return core.labelled(
      Checkbox(
        value: core.value,
        tristate: p.tristate,
        onChanged: core.onChanged,
        focusNode: core.focusNode,
        autofocus: p.autofocus,
        isError: p.error,
        semanticLabel: p.semanticsLabel,
        shape: p.shape,
        side: p.borderSide,
        splashRadius: p.splashRadius,
        activeColor: p.activeColor,
        focusColor: p.focusColor,
        hoverColor: p.hoverColor,
        overlayColor: p.overlayColor,
        checkColor: p.checkColor,
        fillColor: p.fillColor,
        visualDensity: parseVisualDensity(p.visualDensity.string),
        mouseCursor: p.mouseCursor,
      ),
      labelStyle: labelStyle,
      defaultSpacing: 0,
    );
  }
}
