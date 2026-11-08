import 'package:flutter/material.dart';

import '../utils/theme.dart' show parseVisualDensity;
import 'radio_core.dart';

/// Material skin of [RadioCore]: maps the core's values onto [Radio].
class MaterialRadioSkin extends StatelessWidget {
  const MaterialRadioSkin({super.key, required this.core});

  final RadioCore core;

  @override
  Widget build(BuildContext context) {
    final p = core.props;
    var labelStyle = p.labelStyle;
    if (core.disabled && labelStyle != null) {
      labelStyle = labelStyle.apply(color: Theme.of(context).disabledColor);
    }
    return core.labelled(
      Radio<String>(
        value: p.value,
        enabled: core.enabled,
        toggleable: p.toggleable,
        focusNode: core.focusNode,
        autofocus: p.autofocus,
        mouseCursor: p.mouseCursor,
        activeColor: p.activeColor,
        fillColor: p.fillColor,
        focusColor: p.focusColor,
        hoverColor: p.hoverColor,
        overlayColor: p.overlayColor,
        splashRadius: p.splashRadius,
        visualDensity: parseVisualDensity(p.visualDensity.string),
      ),
      labelStyle: labelStyle,
    );
  }
}
