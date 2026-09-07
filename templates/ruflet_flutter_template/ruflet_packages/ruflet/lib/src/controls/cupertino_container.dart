import 'package:flutter/cupertino.dart';

import '../extensions/control.dart';
import '../models/control.dart';
import '../utils/alignment.dart';
import '../utils/animations.dart';
import '../utils/borders.dart';
import '../utils/box.dart';
import '../utils/colors.dart';
import '../utils/cupertino_theme.dart';
import '../utils/edge_insets.dart';
import '../utils/events.dart';
import '../utils/gradient.dart';
import '../utils/images.dart';
import '../utils/launch_url.dart';
import '../utils/misc.dart';
import '../utils/numbers.dart';
import 'base_controls.dart';

class CupertinoContainerControl extends StatelessWidget {
  final Control control;

  const CupertinoContainerControl({super.key, required this.control});

  @override
  Widget build(BuildContext context) {
    debugPrint("Cupertino Container build: ${control.id}");

    final content = control.buildWidget("content");
    final onClick = control.getBool("on_click", false)!;
    final onTapDown = control.getBool("on_tap_down", false)!;
    final onLongPress = control.getBool("on_long_press", false)!;
    final onHover = control.getBool("on_hover", false)!;
    final url = control.getUrl("url");
    final interactive =
        onClick || onTapDown || onLongPress || onHover || url != null;
    final animation = control.getAnimation("animate");
    final blur = control.getBlur("blur");
    final borderRadius = control.getBorderRadius("border_radius");
    final clipBehavior = control.getClipBehavior(
        "clip_behavior", borderRadius != null ? Clip.antiAlias : Clip.none)!;
    final theme = cupertinoStyleTheme(context);
    final decoration = boxDecorationFromDetails(
      shape: control.getBoxShape("shape", BoxShape.rectangle)!,
      color: control.getColor("bgcolor", context),
      gradient: parseGradient(control.get("gradient"), theme),
      borderRadius: borderRadius,
      border: control.getBorder("border", theme,
          defaultSideColor: CupertinoColors.activeBlue.resolveFrom(context)),
      boxShadow: control.getBoxShadows("shadow", theme),
      blendMode: control.getBlendMode("blend_mode"),
      image: control.getDecorationImage("image", context),
    );
    final foreground =
        parseBoxDecoration(control.get("foreground_decoration"), context);
    final onAnimationEnd = control.getBool("on_animation_end", false)!
        ? () => control.triggerEvent("animation_end", "container")
        : null;

    Widget result = animation == null
        ? Container(
            width: control.getDouble("width"),
            height: control.getDouble("height"),
            margin: control.getMargin("margin"),
            padding: control.getPadding("padding"),
            alignment: control.getAlignment("alignment"),
            decoration: decoration,
            foregroundDecoration: foreground,
            clipBehavior: clipBehavior,
            child: content,
          )
        : AnimatedContainer(
            duration: animation.duration,
            curve: animation.curve,
            width: control.getDouble("width"),
            height: control.getDouble("height"),
            margin: control.getMargin("margin"),
            padding: control.getPadding("padding"),
            alignment: control.getAlignment("alignment"),
            decoration: decoration,
            foregroundDecoration: foreground,
            clipBehavior: clipBehavior,
            onEnd: onAnimationEnd,
            child: content,
          );

    if (interactive && !control.disabled) {
      result = _CupertinoContainerInteraction(
        pressedOpacity: control.getBool("ink", false)!
            ? control.getDouble("opacity_on_click", 0.4)!
            : 1,
        cursor: onClick || onTapDown || url != null
            ? SystemMouseCursors.click
            : MouseCursor.defer,
        onHover:
            onHover ? (value) => control.triggerEvent("hover", value) : null,
        onTapDown: onTapDown
            ? (details) => control.triggerEvent("tap_down", details.toMap())
            : null,
        onLongPress:
            onLongPress ? () => control.triggerEvent("long_press") : null,
        onTap: onClick || url != null
            ? () {
                if (url != null) openWebBrowser(url);
                if (onClick) control.triggerEvent("click");
              }
            : null,
        child: result,
      );
    }

    if (blur != null) {
      result = borderRadius != null
          ? ClipRRect(
              borderRadius: borderRadius,
              child: BackdropFilter(filter: blur, child: result))
          : ClipRect(child: BackdropFilter(filter: blur, child: result));
    }
    final colorFilter = control.getColorFilter("color_filter", theme);
    if (colorFilter != null) {
      result = ColorFiltered(colorFilter: colorFilter, child: result);
    }
    if (control.getBool("ignore_interactions", false)!) {
      result = IgnorePointer(child: result);
    }
    return LayoutControl(control: control, child: result);
  }
}

class _CupertinoContainerInteraction extends StatefulWidget {
  final Widget child;
  final double pressedOpacity;
  final MouseCursor cursor;
  final ValueChanged<bool>? onHover;
  final GestureTapDownCallback? onTapDown;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const _CupertinoContainerInteraction({
    required this.child,
    required this.pressedOpacity,
    required this.cursor,
    this.onHover,
    this.onTapDown,
    this.onTap,
    this.onLongPress,
  });

  @override
  State<_CupertinoContainerInteraction> createState() =>
      _CupertinoContainerInteractionState();
}

class _CupertinoContainerInteractionState
    extends State<_CupertinoContainerInteraction> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) => MouseRegion(
        cursor: widget.cursor,
        onEnter: widget.onHover == null ? null : (_) => widget.onHover!(true),
        onExit: widget.onHover == null ? null : (_) => widget.onHover!(false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (details) {
            _setPressed(true);
            widget.onTapDown?.call(details);
          },
          onTapUp: (_) => _setPressed(false),
          onTapCancel: () => _setPressed(false),
          onTap: widget.onTap,
          onLongPress: widget.onLongPress,
          child: AnimatedOpacity(
            opacity: _pressed ? widget.pressedOpacity : 1,
            duration: const Duration(milliseconds: 100),
            child: widget.child,
          ),
        ),
      );
}
