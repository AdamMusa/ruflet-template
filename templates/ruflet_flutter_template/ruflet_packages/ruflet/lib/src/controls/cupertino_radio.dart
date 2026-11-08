import 'package:flutter/cupertino.dart';

import '../utils/cupertino_theme.dart' show cupertinoStyleTheme;
import 'radio_core.dart';

/// Cupertino skin of [RadioCore]: maps the core's values onto
/// [CupertinoRadio].
class CupertinoRadioSkin extends StatelessWidget {
  const CupertinoRadioSkin({super.key, required this.core});

  final RadioCore core;

  @override
  Widget build(BuildContext context) {
    final p = core.props;
    var labelStyle = p.labelStyle;
    if (core.disabled) {
      labelStyle = (labelStyle ?? const TextStyle())
          .copyWith(color: cupertinoStyleTheme(context).color('disabled'));
    }
    return core.labelled(
      CupertinoRadio<String>(
        value: p.value,
        enabled: core.enabled,
        toggleable: p.toggleable,
        focusNode: core.focusNode,
        autofocus: p.autofocus,
        mouseCursor: p.mouseCursor,
        activeColor: p.activeColor ?? CupertinoTheme.of(context).primaryColor,
        inactiveColor: p.inactiveColor,
        fillColor: p.fillColor?.resolve(core.states),
        focusColor: p.focusColor,
        useCheckmarkStyle: p.useCheckmarkStyle,
      ),
      labelStyle: labelStyle,
    );
  }
}
