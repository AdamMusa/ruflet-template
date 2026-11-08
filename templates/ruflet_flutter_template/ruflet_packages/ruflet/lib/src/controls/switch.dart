import 'package:flutter/material.dart';

import 'switch_core.dart';

/// Material skin of [SwitchCore]: maps the core's values onto [Switch].
class MaterialSwitchSkin extends StatelessWidget {
  const MaterialSwitchSkin({super.key, required this.core});

  final SwitchCore core;

  @override
  Widget build(BuildContext context) {
    final p = core.props;
    var labelStyle = p.labelTextStyle;
    if (core.disabled && labelStyle != null) {
      labelStyle = labelStyle.apply(color: Theme.of(context).disabledColor);
    }
    return core.labelled(
      Switch(
        value: core.value,
        onChanged: core.onChanged,
        focusNode: core.focusNode,
        autofocus: p.autofocus,
        activeThumbColor: p.activeColor,
        activeTrackColor: p.activeTrackColor,
        inactiveThumbColor: p.inactiveThumbColor,
        inactiveTrackColor: p.inactiveTrackColor,
        thumbColor: p.thumbColor,
        thumbIcon: p.thumbIcon,
        trackColor: p.trackColor,
        trackOutlineColor: p.trackOutlineColor,
        trackOutlineWidth: p.trackOutlineWidth,
        focusColor: p.focusColor,
        hoverColor: p.hoverColor,
        overlayColor: p.overlayColor,
        splashRadius: p.splashRadius,
        padding: p.padding,
        mouseCursor: p.mouseCursor,
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
