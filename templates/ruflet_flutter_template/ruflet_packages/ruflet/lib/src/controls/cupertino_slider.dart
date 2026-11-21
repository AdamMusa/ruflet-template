import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import '../ruflet_backend.dart';
import '../models/control.dart';
import '../utils/colors.dart';
import '../utils/numbers.dart';
import 'base_controls.dart';

class CupertinoSliderControl extends StatefulWidget {
  final Control control;

  CupertinoSliderControl({Key? key, required this.control})
      : super(key: key ?? ValueKey("control_${control.id}"));

  @override
  State<CupertinoSliderControl> createState() => _CupertinoSliderControlState();
}

class _CupertinoSliderControlState extends State<CupertinoSliderControl> {
  double _value = 0;
  late RufletBackend backend;
  // CupertinoSlider has no focus support of its own; this makes it a focus
  // target (iOS Full Keyboard Access, macOS) like the Material slider.
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void onChange(double value) {
    _value = value;
    var props = {"value": value};
    widget.control.updateProperties(props, notify: true);
    widget.control.triggerEvent("change");
  }

  /// Arrow keys step a focused slider by one division, or a tenth of the
  /// range, as Flutter's Material slider does on Apple platforms.
  KeyEventResult _onKeyEvent(
      FocusNode node, KeyEvent event, double min, double max) {
    if (widget.control.disabled || event is KeyUpEvent) {
      return KeyEventResult.ignored;
    }
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final key = event.logicalKey;
    final double direction;
    if (key == LogicalKeyboardKey.arrowUp ||
        key ==
            (rtl
                ? LogicalKeyboardKey.arrowLeft
                : LogicalKeyboardKey.arrowRight)) {
      direction = 1;
    } else if (key == LogicalKeyboardKey.arrowDown ||
        key ==
            (rtl
                ? LogicalKeyboardKey.arrowRight
                : LogicalKeyboardKey.arrowLeft)) {
      direction = -1;
    } else {
      return KeyEventResult.ignored;
    }
    final divisions = widget.control.getInt("divisions");
    final step = (max - min) * (divisions != null ? 1 / divisions : 0.1);
    final value = (_value + direction * step).clamp(min, max).toDouble();
    widget.control.triggerEvent("change_start", _value);
    setState(() => onChange(value));
    widget.control.triggerEvent("change_end", value);
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    debugPrint("CupertinoSliderControl build: ${widget.control.id}");

    double min = widget.control.getDouble("min", 0.0)!;
    double max = widget.control.getDouble("max", 1.0)!;

    double value = widget.control.getDouble("value", min)!;
    if (_value != value) {
      // verify limits
      if (value < min) {
        _value = min;
      } else if (value > max) {
        _value = max;
      } else {
        _value = value;
      }
    }

    var cupertinoSlider = CupertinoSlider(
        value: _value,
        min: min,
        max: max,
        divisions: widget.control.getInt("divisions"),
        activeColor: widget.control.getColor("active_color", context),
        thumbColor: widget.control
            .getColor("thumb_color", context, CupertinoColors.white)!,
        onChanged:
            !widget.control.disabled ? (double value) => onChange(value) : null,
        onChangeStart: !widget.control.disabled
            ? (double value) {
                widget.control.triggerEvent("change_start", value);
              }
            : null,
        onChangeEnd: !widget.control.disabled
            ? (double value) {
                widget.control.triggerEvent("change_end", value);
              }
            : null);

    return LayoutControl(
        control: widget.control,
        child: Focus(
            focusNode: _focusNode,
            autofocus: widget.control.getBool("autofocus", false)!,
            canRequestFocus: !widget.control.disabled,
            onFocusChange: (focused) =>
                widget.control.triggerEvent(focused ? "focus" : "blur"),
            onKeyEvent: (node, event) => _onKeyEvent(node, event, min, max),
            child: cupertinoSlider));
  }
}
