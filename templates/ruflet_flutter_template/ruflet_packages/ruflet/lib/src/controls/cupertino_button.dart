import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import '../extensions/control.dart';
import '../models/control.dart';
import '../models/control_type.dart';
import '../utils/alignment.dart';
import '../utils/borders.dart';
import '../utils/cupertino_enums.dart';
import '../utils/cupertino_theme.dart';
import '../utils/colors.dart';
import '../utils/edge_insets.dart';
import '../utils/geometry.dart';
import '../utils/launch_url.dart';
import '../utils/mouse.dart';
import '../utils/numbers.dart';
import '../utils/text.dart';
import '../utils/time.dart';
import '../utils/widget_state.dart';
import 'base_controls.dart';

class CupertinoButtonControl extends StatefulWidget {
  final Control control;

  CupertinoButtonControl({Key? key, required this.control})
      : super(key: key ?? ValueKey("control_${control.id}"));

  @override
  State<CupertinoButtonControl> createState() => _CupertinoButtonControlState();
}

class _CupertinoButtonControlState extends State<CupertinoButtonControl> {
  late final FocusNode _focusNode;
  bool _hovered = false;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _focusNode.addListener(_onFocusChange);
    widget.control.addInvokeMethodListener(_invokeMethod);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    widget.control.removeInvokeMethodListener(_invokeMethod);
    super.dispose();
  }

  void _onFocusChange() {
    setState(() {});
    widget.control.triggerEvent(_focusNode.hasFocus ? "focus" : "blur");
  }

  Future<dynamic> _invokeMethod(String name, dynamic args) async {
    debugPrint("CupertinoButton.$name($args)");
    switch (name) {
      case "focus":
        _focusNode.requestFocus();
      default:
        throw Exception("Unknown CupertinoButton method: $name");
    }
  }

  @override
  Widget build(BuildContext context) {
    debugPrint("CupertinoButton build: ${widget.control.id}");
    final theme = cupertinoStyleTheme(context);
    final style =
        widget.control.internals?["style"] ?? widget.control.get("style");
    final states = <WidgetState>{
      if (widget.control.disabled) WidgetState.disabled,
      if (widget.control.getBool("selected", false)!) WidgetState.selected,
      if (_focusNode.hasFocus) WidgetState.focused,
      if (_hovered) WidgetState.hovered,
      if (_pressed) WidgetState.pressed,
    };
    Color? styleColor(String key) =>
        parseWidgetStateColor(style?[key], theme)?.resolve(states);
    Color? iconColor = styleColor("icon_color") ??
        widget.control.getColor("icon_color", context);

    Widget? icon = widget.control.buildIconOrWidget("icon", color: iconColor);
    Widget? content = widget.control.buildTextOrWidget("content");

    Widget child;
    if (icon != null) {
      if (content != null) {
        child = Row(
            mainAxisSize: MainAxisSize.min,
            children: [icon, const SizedBox(width: 8), content]);
      } else {
        child = icon;
      }
    } else {
      child = content ?? const Text("");
    }

    var pressedOpacity = widget.control.getDouble("opacity_on_click", 0.4)!;
    var minSize =
        parseWidgetStateSize(style?["minimum_size"])?.resolve(states) ??
            widget.control.getSize("min_size");
    var mouseCursor =
        parseWidgetStateMouseCursor(style?["mouse_cursor"])?.resolve(states) ??
            widget.control.getMouseCursor("mouse_cursor");
    var autofocus = widget.control.getBool("autofocus", false)!;
    var bgColor =
        styleColor("bgcolor") ?? widget.control.getColor("bgcolor", context);
    var focusColor = widget.control.getColor("focus_color", context);
    var size = widget.control
        .getCupertinoButtonSize("size", CupertinoButtonSize.large)!;

    var alignment = parseAlignment(style?["alignment"]) ??
        widget.control.getAlignment("alignment", Alignment.center)!;
    var borderRadius = widget.control.getBorderRadius(
        "border_radius", const BorderRadius.all(Radius.circular(8.0)))!;

    var padding = parseWidgetStatePadding(style?["padding"])?.resolve(states) ??
        widget.control.getPadding("padding");
    var variant = widget.control.canonicalType;
    bool isFilledButton = variant == "FilledButton";
    bool isTintedButton = variant == "FilledTonalButton";

    var color =
        styleColor("color") ?? widget.control.getColor("color", context);
    var disabledColor = (widget.control.disabled
            ? styleColor("bgcolor")
            : null) ??
        widget.control.getColor(
            "disabled_bgcolor", context, CupertinoColors.tertiarySystemFill)!;
    final textStyle =
        parseWidgetStateTextStyle(style?["text_style"], theme)?.resolve(states);
    if (color != null || textStyle != null) {
      child = DefaultTextStyle.merge(
          style: (textStyle ?? const TextStyle()).copyWith(color: color),
          child: child);
    }
    final iconSize =
        parseWidgetStateDouble(style?["icon_size"])?.resolve(states);
    if (iconColor != null || iconSize != null) {
      child = IconTheme.merge(
          data: IconThemeData(color: iconColor, size: iconSize), child: child);
    }
    final enableFeedback = parseBool(style?["enable_feedback"], false)!;
    var url = widget.control.getUrl("url");
    Function()? onPressed = !widget.control.disabled
        ? () {
            if (enableFeedback) HapticFeedback.selectionClick();
            if (url != null) {
              openWebBrowser(url);
            }
            widget.control.triggerEvent("click");
          }
        : null;
    Function()? onLongPressed = !widget.control.disabled
        ? () {
            if (enableFeedback) HapticFeedback.selectionClick();
            widget.control.triggerEvent("long_press");
          }
        : null;

    final side = getWidgetStateProperty<BorderSide?>(
            style?["side"], (value) => parseBorderSide(value, theme))
        ?.resolve(states);
    var shape =
        parseWidgetStateOutlinedBorder(style?["shape"], theme)?.resolve(states);
    if (shape != null && side != null) shape = shape.copyWith(side: side);
    if (shape == null && (side != null || variant == "OutlinedButton")) {
      shape = RoundedRectangleBorder(
        borderRadius: borderRadius,
        side: side ?? BorderSide(color: theme.color("outline")!),
      );
    }
    final nativeBackground = bgColor;
    final nativeDisabledBackground = disabledColor;
    if (shape != null) {
      bgColor = const Color(0x00000000);
      disabledColor = const Color(0x00000000);
    }
    Widget button;
    if (isFilledButton) {
      button = CupertinoButton.filled(
        onPressed: onPressed,
        disabledColor: disabledColor,
        color: bgColor,
        padding: padding,
        borderRadius: borderRadius,
        pressedOpacity: pressedOpacity,
        alignment: alignment,
        minimumSize: minSize,
        sizeStyle: size,
        autofocus: autofocus,
        focusColor: focusColor,
        onLongPress: onLongPressed,
        focusNode: _focusNode,
        mouseCursor: mouseCursor,
        child: child,
      );
    } else if (isTintedButton) {
      button = CupertinoButton.tinted(
        onPressed: onPressed,
        disabledColor: disabledColor,
        color: bgColor,
        padding: padding,
        borderRadius: borderRadius,
        pressedOpacity: pressedOpacity,
        alignment: alignment,
        minimumSize: minSize,
        sizeStyle: size,
        autofocus: autofocus,
        focusColor: focusColor,
        onLongPress: onLongPressed,
        focusNode: _focusNode,
        mouseCursor: mouseCursor,
        child: child,
      );
    } else {
      button = CupertinoButton(
        onPressed: onPressed,
        disabledColor: disabledColor,
        color: bgColor,
        padding: padding,
        borderRadius: borderRadius,
        pressedOpacity: pressedOpacity,
        alignment: alignment,
        minimumSize: minSize,
        sizeStyle: size,
        autofocus: autofocus,
        focusColor: focusColor,
        onLongPress: onLongPressed,
        focusNode: _focusNode,
        mouseCursor: mouseCursor,
        child: child,
      );
    }

    final elevation =
        parseWidgetStateDouble(style?["elevation"])?.resolve(states) ??
            widget.control.getDouble("elevation", 0)!;
    final shadowColor = styleColor("shadow_color") ?? const Color(0x33000000);
    final overlayColor = styleColor("overlay_color");
    if (shape != null || elevation > 0 || overlayColor != null) {
      final effectiveShape =
          shape ?? RoundedRectangleBorder(borderRadius: borderRadius);
      final shapeBackground = widget.control.disabled
          ? nativeDisabledBackground
          : nativeBackground ??
              (isFilledButton
                  ? CupertinoTheme.of(context).primaryColor
                  : null) ??
              (isTintedButton
                  ? CupertinoTheme.of(context)
                      .primaryColor
                      .withValues(alpha: 0.15)
                  : null);
      button = AnimatedContainer(
        duration: parseDuration(
            style?["animation_duration"], const Duration(milliseconds: 100))!,
        decoration: ShapeDecoration(
          color: shape == null ? null : shapeBackground,
          shape: effectiveShape,
          shadows: elevation > 0
              ? [
                  BoxShadow(
                      color: shadowColor,
                      blurRadius: elevation * 2,
                      offset: Offset(0, elevation))
                ]
              : null,
        ),
        foregroundDecoration: overlayColor == null
            ? null
            : ShapeDecoration(color: overlayColor, shape: effectiveShape),
        child: ClipPath(
            clipper: ShapeBorderClipper(shape: effectiveShape), child: button),
      );
    }
    final fixedSize =
        parseWidgetStateSize(style?["fixed_size"])?.resolve(states);
    final maximumSize =
        parseWidgetStateSize(style?["maximum_size"])?.resolve(states);
    if (fixedSize != null || maximumSize != null) {
      button = ConstrainedBox(
        constraints: BoxConstraints(
          minWidth: fixedSize?.width ?? minSize?.width ?? 0,
          minHeight: fixedSize?.height ?? minSize?.height ?? 0,
          maxWidth: fixedSize?.width ?? maximumSize?.width ?? double.infinity,
          maxHeight:
              fixedSize?.height ?? maximumSize?.height ?? double.infinity,
        ),
        child: button,
      );
    }
    button = MouseRegion(
      onEnter: widget.control.disabled
          ? null
          : (_) {
              setState(() => _hovered = true);
              widget.control.triggerEvent("hover", true);
            },
      onExit: widget.control.disabled
          ? null
          : (_) {
              setState(() => _hovered = false);
              widget.control.triggerEvent("hover", false);
            },
      child: Listener(
        onPointerDown: widget.control.disabled
            ? null
            : (_) => setState(() => _pressed = true),
        onPointerUp: (_) => setState(() => _pressed = false),
        onPointerCancel: (_) => setState(() => _pressed = false),
        child: button,
      ),
    );
    return LayoutControl(control: widget.control, child: button);
  }
}
