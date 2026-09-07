import '../utils/material_enums.dart';
import '../utils/material_style_theme.dart';
import 'package:flutter/material.dart';

import '../extensions/control.dart';
import '../models/control.dart';
import '../utils/borders.dart';
import '../utils/colors.dart';
import '../utils/edge_insets.dart';
import '../utils/numbers.dart';
import '../utils/time.dart';
import 'base_controls.dart';

class MaterialNavigationBarControl extends StatefulWidget {
  final Control control;

  MaterialNavigationBarControl({Key? key, required this.control})
      : super(key: key ?? ValueKey("control_${control.id}"));

  @override
  State<MaterialNavigationBarControl> createState() =>
      _NavigationBarControlState();
}

class _NavigationBarControlState extends State<MaterialNavigationBarControl> {
  int _selectedIndex = 0;

  void _destinationChanged(int index) {
    _selectedIndex = index;
    widget.control
        .updateProperties({"selected_index": _selectedIndex}, notify: true);
    widget.control.triggerEvent("change", _selectedIndex);
  }

  @override
  Widget build(BuildContext context) {
    debugPrint("NavigationBarControl build: ${widget.control.id}");

    var selectedIndex = widget.control.getInt("selected_index", 0)!;

    if (_selectedIndex != selectedIndex) {
      _selectedIndex = selectedIndex;
    }
    var navBar = NavigationBar(
        labelBehavior: widget.control
            .getNavigationDestinationLabelBehavior("label_behavior"),
        height: widget.control.getDouble("height"),
        animationDuration: widget.control.getDuration("animation_duration"),
        elevation: widget.control.getDouble("elevation"),
        labelPadding: widget.control.getPadding("label_padding"),
        shadowColor: widget.control.getColor("shadow_color", context),
        overlayColor: widget.control
            .getWidgetStateColor("overlay_color", materialStyleTheme(Theme.of(context))),
        indicatorColor: widget.control.getColor("indicator_color", context),
        indicatorShape:
            widget.control.getShape("indicator_shape", materialStyleTheme(Theme.of(context))),
        backgroundColor: widget.control.getColor("bgcolor", context),
        selectedIndex: _selectedIndex,
        onDestinationSelected:
            widget.control.disabled ? null : _destinationChanged,
        destinations: widget.control.buildWidgets("destinations"));

    return LayoutControl(control: widget.control, child: navBar);
  }
}
