import '../utils/material_style_theme.dart';
import 'package:flutter/material.dart';

import '../extensions/control.dart';
import '../models/control.dart';
import '../utils/alignment.dart';
import '../utils/animations.dart';
import '../utils/borders.dart';
import '../utils/box.dart';
import '../utils/colors.dart';
import '../utils/edge_insets.dart';
import '../utils/events.dart';
import '../utils/gradient.dart';
import '../utils/images.dart';
import '../utils/launch_url.dart';
import '../utils/misc.dart';
import '../utils/numbers.dart';
import '../widgets/ruflet_store_mixin.dart';
import 'base_controls.dart';

class MaterialContainerControl extends StatelessWidget with RufletStoreMixin {
  final Control control;

  const MaterialContainerControl({super.key, required this.control});

  @override
  Widget build(BuildContext context) {
    debugPrint("Material Container build: ${control.id}");

    var bgColor = control.getColor("bgcolor", context);
    var content = control.buildWidget("content");
    var ink = control.getBool("ink", false)!;
    var onClick = control.getBool("on_click", false)!;
    var onTapDown = control.getBool("on_tap_down", false)!;
    var url = control.getUrl("url");
    var onLongPress = control.getBool("on_long_press", false)!;
    var onHover = control.getBool("on_hover", false)!;
    var ignoreInteractions = control.getBool("ignore_interactions", false)!;
    var animation = control.getAnimation("animate");
    var blur = control.getBlur("blur");
    var colorFilter = control.getColorFilter(
        "color_filter", materialStyleTheme(Theme.of(context)));
    final ownsSize = control.getAnimation("animate_size") == null;
    final ownsMargin = control.getAnimation("animate_margin") == null;
    var width = ownsSize ? control.getDouble("width") : null;
    var height = ownsSize ? control.getDouble("height") : null;
    var padding = control.getPadding("padding");
    var margin = ownsMargin ? control.getMargin("margin") : null;
    var alignment = control.getAlignment("alignment");
    var borderRadius = control.getBorderRadius("border_radius");
    var clipBehavior = control.getClipBehavior(
        "clip_behavior", borderRadius != null ? Clip.antiAlias : Clip.none)!;
    var decorationImage = control.getDecorationImage("image", context);
    var theme = Theme.of(context);
    var boxDecoration = boxDecorationFromDetails(
      shape: control.getBoxShape("shape", BoxShape.rectangle)!,
      color: bgColor,
      gradient:
          parseGradient(control.get("gradient"), materialStyleTheme(theme)),
      borderRadius: borderRadius,
      border: control.getBorder("border", materialStyleTheme(theme),
          defaultSideColor: theme.colorScheme.primary),
      boxShadow: control.getBoxShadows("shadow", materialStyleTheme(theme)),
      blendMode: control.getBlendMode("blend_mode"),
      image: decorationImage,
    );
    var boxForegroundDecoration =
        parseBoxDecoration(control.get("foreground_decoration"), context);
    Widget? container;

    var onAnimationEnd = control.getBool("on_animation_end", false)!
        ? () => control.triggerEvent("animation_end", "container")
        : null;
    if ((onClick || url != null || onLongPress || onHover || onTapDown) &&
        ink &&
        !control.disabled) {
      var inkWidget = Material(
          color: Colors.transparent,
          borderRadius: boxDecoration!.borderRadius,
          child: InkWell(
            onTap: onClick || url != null || onTapDown
                ? () {
                    if (url != null) openWebBrowser(url);
                    if (onClick) control.triggerEvent("click");
                  }
                : null,
            onTapDown: onTapDown
                ? (TapDownDetails details) {
                    control.triggerEvent("tap_down", details.toMap());
                  }
                : null,
            onLongPress:
                onLongPress ? () => control.triggerEvent("long_press") : null,
            onHover: onHover
                ? (value) => control.triggerEvent("hover", value)
                : null,
            borderRadius: borderRadius,
            splashColor: control.getColor("ink_color", context),
            child: Container(
              padding: animation == null ? padding : null,
              alignment: animation == null ? alignment : null,
              clipBehavior: Clip.none,
              child: content,
            ),
          ));

      container = animation == null
          ? Container(
              width: width,
              height: height,
              margin: margin,
              clipBehavior: clipBehavior,
              decoration: boxDecoration,
              foregroundDecoration: boxForegroundDecoration,
              child: inkWidget,
            )
          : AnimatedContainer(
              duration: animation.duration,
              curve: animation.curve,
              width: width,
              height: height,
              margin: margin,
              alignment: alignment,
              padding: padding,
              decoration: boxDecoration,
              foregroundDecoration: boxForegroundDecoration,
              clipBehavior: clipBehavior,
              onEnd: onAnimationEnd,
              child: inkWidget);
    } else {
      container = animation == null
          ? Container(
              width: width,
              height: height,
              margin: margin,
              padding: padding,
              alignment: alignment,
              decoration: boxDecoration,
              foregroundDecoration: boxForegroundDecoration,
              clipBehavior: clipBehavior,
              child: content)
          : AnimatedContainer(
              duration: animation.duration,
              curve: animation.curve,
              width: width,
              height: height,
              margin: margin,
              padding: padding,
              alignment: alignment,
              decoration: boxDecoration,
              foregroundDecoration: boxForegroundDecoration,
              clipBehavior: clipBehavior,
              onEnd: onAnimationEnd,
              child: content);

      if ((onClick || onLongPress || onHover || onTapDown || url != null) &&
          !control.disabled) {
        container = MouseRegion(
          cursor: onClick || onTapDown || url != null
              ? SystemMouseCursors.click
              : MouseCursor.defer,
          onEnter: onHover ? (_) => control.triggerEvent("hover", true) : null,
          onExit: onHover ? (_) => control.triggerEvent("hover", false) : null,
          child: GestureDetector(
            onTap: onClick || url != null
                ? () {
                    if (url != null) openWebBrowser(url);
                    if (onClick) control.triggerEvent("click");
                  }
                : null,
            onTapDown: onTapDown
                ? (TapDownDetails details) {
                    control.triggerEvent("tap_down", details.toMap());
                  }
                : null,
            onLongPress:
                onLongPress ? () => control.triggerEvent("long_press") : null,
            child: container,
          ),
        );
      }
    }

    if (blur != null) {
      container = borderRadius != null
          ? ClipRRect(
              borderRadius: borderRadius,
              child: BackdropFilter(filter: blur, child: container))
          : ClipRect(child: BackdropFilter(filter: blur, child: container));
    }
    if (colorFilter != null) {
      container = ColorFiltered(colorFilter: colorFilter, child: container);
    }
    if (ignoreInteractions) container = IgnorePointer(child: container);

    return LayoutControl(
      control: control,
      skipProperties: {
        if (ownsSize) ...{'width', 'height'},
        if (ownsMargin) 'margin',
      },
      child: container,
    );
  }
}
