import 'package:flutter/cupertino.dart';

import '../utils/cupertino_theme.dart' show cupertinoStyleTheme;
import 'switch_core.dart';

/// Cupertino skin of [SwitchCore]: maps the core's values onto
/// [CupertinoSwitch].
class CupertinoSwitchSkin extends StatelessWidget {
  const CupertinoSwitchSkin({super.key, required this.core});

  final SwitchCore core;

  @override
  Widget build(BuildContext context) {
    final p = core.props;
    var labelStyle = p.labelTextStyle;
    if (core.disabled) {
      labelStyle = (labelStyle ?? const TextStyle())
          .copyWith(color: cupertinoStyleTheme(context).color('disabled'));
    }
    final mouseCursor = p.mouseCursor;
    return core.labelled(
      CupertinoSwitch(
        value: core.value,
        onChanged: core.onChanged,
        focusNode: core.focusNode,
        autofocus: p.autofocus,
        activeTrackColor: p.activeTrackColor,
        inactiveTrackColor: p.inactiveTrackColor,
        thumbColor: p.thumbColor?.resolve(core.states),
        inactiveThumbColor: p.inactiveThumbColor,
        thumbIcon: p.thumbIcon,
        trackOutlineColor: p.trackOutlineColor,
        trackOutlineWidth: p.trackOutlineWidth,
        focusColor: p.focusColor,
        onLabelColor: p.onLabelColor,
        offLabelColor: p.offLabelColor,
        mouseCursor:
            mouseCursor == null ? null : WidgetStatePropertyAll(mouseCursor),
        activeThumbImage: p.activeThumbImage,
        onActiveThumbImageError:
            p.activeThumbImage == null ? null : core.onImageError,
        inactiveThumbImage: p.inactiveThumbImage,
        onInactiveThumbImageError:
            p.inactiveThumbImage == null ? null : core.onImageError,
      ),
      labelStyle: labelStyle,
    );
  }
}
