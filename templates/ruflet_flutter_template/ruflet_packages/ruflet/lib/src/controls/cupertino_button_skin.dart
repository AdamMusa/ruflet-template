import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import '../utils/alignment.dart' show parseAlignment;
import '../utils/borders.dart'
    show parseBorderSide, parseWidgetStateOutlinedBorder;
import '../utils/colors.dart' show parseWidgetStateColor;
import '../utils/cupertino_enums.dart' show parseCupertinoButtonSize;
import '../utils/cupertino_theme.dart' show cupertinoStyleTheme;
import '../utils/edge_insets.dart' show parseWidgetStatePadding;
import '../utils/geometry.dart' show parseSize, parseWidgetStateSize;
import '../utils/mouse.dart' show parseWidgetStateMouseCursor;
import '../utils/numbers.dart' show parseBool, parseWidgetStateDouble;
import '../utils/text.dart' show parseWidgetStateTextStyle;
import '../utils/time.dart' show parseDuration;
import '../utils/widget_state.dart' show getWidgetStateProperty;
import '../widgets/constrained_default_padding.dart';
import 'button_core.dart';

/// Cupertino skin of [ButtonCore]: CupertinoButton (plain, filled or
/// tinted) with the Ruby `style` map resolved against the core's states.
class CupertinoButtonSkin extends StatelessWidget {
  const CupertinoButtonSkin({super.key, required this.core});

  final ButtonCore core;

  @override
  Widget build(BuildContext context) {
    final p = core.props;
    final theme = cupertinoStyleTheme(context);
    final rawStyle = p.style.value;
    final Map<Object?, Object?>? style =
        rawStyle is Map ? rawStyle.cast<Object?, Object?>() : null;
    final states = core.states;
    Color? styleColor(String key) =>
        parseWidgetStateColor(style?[key], theme)?.resolve(states);
    final iconColor = styleColor("icon_color") ?? p.iconColor;

    var icon = p.icon;
    if (icon != null && iconColor != null) {
      icon =
          IconTheme.merge(data: IconThemeData(color: iconColor), child: icon);
    }
    final content = p.content?.build();

    Widget child;
    if (icon != null) {
      child = content != null
          ? Row(mainAxisSize: MainAxisSize.min, children: [
              icon,
              const SizedBox(width: 8),
              Flexible(child: content)
            ])
          : icon;
    } else {
      child = content ?? const Text("");
    }

    final pressedOpacity = p.pressedOpacity ?? 0.4;
    final minSize =
        parseWidgetStateSize(style?["minimum_size"])?.resolve(states) ??
            parseSize(p.minSize.value);
    final mouseCursor =
        parseWidgetStateMouseCursor(style?["mouse_cursor"])?.resolve(states) ??
            p.mouseCursor;
    var bgColor = styleColor("bgcolor") ?? p.bgcolor;
    final sizeStyle = parseCupertinoButtonSize(
        p.sizeStyle.string, CupertinoButtonSize.large)!;
    final alignment =
        parseAlignment(style?["alignment"]) ?? p.alignment ?? Alignment.center;
    final borderRadius =
        p.borderRadius ?? const BorderRadius.all(Radius.circular(8.0));
    var padding = parseWidgetStatePadding(style?["padding"])?.resolve(states) ??
        p.padding;
    final variant = core.variant;
    final color = styleColor("color") ?? p.color;
    var disabledColor = (core.disabled ? styleColor("bgcolor") : null) ??
        p.disabledBgcolor ??
        CupertinoColors.tertiarySystemFill;
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
    final click = core.onClick;
    final longPress = core.onLongPress;
    final onPressed = click == null
        ? null
        : () {
            if (enableFeedback) HapticFeedback.selectionClick();
            click();
          };
    final onLongPressed = longPress == null
        ? null
        : () {
            if (enableFeedback) HapticFeedback.selectionClick();
            longPress();
          };

    final side = getWidgetStateProperty<BorderSide?>(
            style?["side"], (value) => parseBorderSide(value, theme))
        ?.resolve(states);
    var shape =
        parseWidgetStateOutlinedBorder(style?["shape"], theme)?.resolve(states);
    if (shape != null && side != null) shape = shape.copyWith(side: side);
    if (shape == null && (side != null || variant == ButtonVariant.outlined)) {
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
    if (padding == null) {
      // Keep the native size-style padding when it fits. A Ruby height/width
      // constraint must not make that implicit padding clip the label/icon.
      child = ConstrainedDefaultPadding(
        padding: kCupertinoButtonPadding[sizeStyle]!
            .resolve(Directionality.of(context)),
        child: child,
      );
      padding = EdgeInsets.zero;
    }
    Widget button = switch (variant) {
      ButtonVariant.filled => CupertinoButton.filled(
          onPressed: onPressed,
          disabledColor: disabledColor,
          color: bgColor,
          padding: padding,
          borderRadius: borderRadius,
          pressedOpacity: pressedOpacity,
          alignment: alignment,
          minimumSize: minSize,
          sizeStyle: sizeStyle,
          autofocus: p.autofocus,
          focusColor: p.focusColor,
          onLongPress: onLongPressed,
          focusNode: core.focusNode,
          mouseCursor: mouseCursor,
          child: child,
        ),
      ButtonVariant.tonal => CupertinoButton.tinted(
          onPressed: onPressed,
          disabledColor: disabledColor,
          color: bgColor,
          padding: padding,
          borderRadius: borderRadius,
          pressedOpacity: pressedOpacity,
          alignment: alignment,
          minimumSize: minSize,
          sizeStyle: sizeStyle,
          autofocus: p.autofocus,
          focusColor: p.focusColor,
          onLongPress: onLongPressed,
          focusNode: core.focusNode,
          mouseCursor: mouseCursor,
          child: child,
        ),
      _ => CupertinoButton(
          onPressed: onPressed,
          disabledColor: disabledColor,
          color: bgColor,
          padding: padding,
          borderRadius: borderRadius,
          pressedOpacity: pressedOpacity,
          alignment: alignment,
          minimumSize: minSize,
          sizeStyle: sizeStyle,
          autofocus: p.autofocus,
          focusColor: p.focusColor,
          onLongPress: onLongPressed,
          focusNode: core.focusNode,
          mouseCursor: mouseCursor,
          child: child,
        ),
    };

    final elevation =
        parseWidgetStateDouble(style?["elevation"])?.resolve(states) ??
            p.elevation ??
            0;
    final shadowColor = styleColor("shadow_color") ?? const Color(0x33000000);
    final overlayColor = styleColor("overlay_color");
    if (shape != null || elevation > 0 || overlayColor != null) {
      final effectiveShape =
          shape ?? RoundedRectangleBorder(borderRadius: borderRadius);
      final primary = CupertinoTheme.of(context).primaryColor;
      final shapeBackground = core.disabled
          ? nativeDisabledBackground
          : nativeBackground ??
              (variant == ButtonVariant.filled ? primary : null) ??
              (variant == ButtonVariant.tonal
                  ? primary.withValues(alpha: 0.15)
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
            clipper: ShapeBorderClipper(shape: effectiveShape),
            clipBehavior: p.clipBehavior,
            child: button),
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
    // CupertinoButton reports no enabled state; assistive technology gets
    // the same enabled/disabled flag as on Material.
    return Semantics(enabled: core.enabled, child: button);
  }
}
