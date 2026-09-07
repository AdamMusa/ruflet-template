import 'package:flutter/cupertino.dart';

import '../extensions/control.dart';
import '../models/control.dart';
import '../utils/borders.dart';
import '../utils/colors.dart';
import '../utils/edge_insets.dart';
import '../utils/images.dart';
import '../utils/launch_url.dart';
import '../utils/misc.dart';
import '../utils/numbers.dart';
import '../widgets/error.dart';
import 'base_controls.dart';
import 'control_widget.dart';

class CupertinoCardControl extends StatelessWidget {
  final Control control;

  const CupertinoCardControl({super.key, required this.control});

  @override
  Widget build(BuildContext context) {
    final content = control.child("content");
    final variant = control.getString("variant", "elevated")!.toLowerCase();
    final elevation = control.getDouble("elevation", 1)!;
    final radius = control.getBorderRadius("border_radius") ??
        const BorderRadius.all(Radius.circular(12));
    final color = control.getColor("bgcolor", context) ??
        CupertinoColors.secondarySystemGroupedBackground.resolveFrom(context);
    final borderColor = CupertinoColors.separator.resolveFrom(context);

    Widget result = Container(
      margin: control.getMargin("margin", const EdgeInsets.all(4)),
      clipBehavior: control.getClipBehavior("clip_behavior", Clip.antiAlias)!,
      decoration: BoxDecoration(
        color: color,
        borderRadius: radius,
        border: variant == "outlined" ? Border.all(color: borderColor) : null,
        boxShadow: variant == "elevated" && elevation > 0
            ? [
                BoxShadow(
                  color: control.getColor("shadow_color", context) ??
                      const Color(0x26000000),
                  blurRadius: elevation * 2,
                  offset: Offset(0, elevation),
                )
              ]
            : null,
      ),
      child: content == null ? null : ControlWidget(control: content),
    );
    if (control.getBool("semantic_container", true)!) {
      result = Semantics(container: true, child: result);
    }
    return LayoutControl(control: control, child: result);
  }
}

class CupertinoCircleAvatarControl extends StatelessWidget {
  final Control control;

  const CupertinoCircleAvatarControl({super.key, required this.control});

  @override
  Widget build(BuildContext context) {
    final foreground =
        control.getImageProvider("foreground_image_src", context);
    final background =
        control.getImageProvider("background_image_src", context);
    final radius = control.getDouble("radius", 20)!;
    final minRadius = control.getDouble("min_radius", radius)!;
    final maxRadius = control.getDouble("max_radius", radius)!;
    final diameter = radius * 2;

    Widget layer(ImageProvider image, String source) => Positioned.fill(
          child: Image(
            image: image,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) {
              control.triggerEvent("image_error", source);
              return const SizedBox.shrink();
            },
          ),
        );

    final avatar = ConstrainedBox(
      constraints: BoxConstraints(
        minWidth: minRadius * 2,
        minHeight: minRadius * 2,
        maxWidth: maxRadius * 2,
        maxHeight: maxRadius * 2,
      ),
      child: SizedBox.square(
        dimension: diameter,
        child: ClipOval(
          child: ColoredBox(
            color: control.getColor("bgcolor", context) ??
                CupertinoColors.systemGrey5.resolveFrom(context),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (background != null) layer(background, "background"),
                Center(
                  child: DefaultTextStyle.merge(
                    style: TextStyle(color: control.getColor("color", context)),
                    child: control.buildTextOrWidget("content") ??
                        const SizedBox.shrink(),
                  ),
                ),
                if (foreground != null) layer(foreground, "foreground"),
              ],
            ),
          ),
        ),
      ),
    );
    return LayoutControl(control: control, child: avatar);
  }
}

class CupertinoDividerControl extends StatelessWidget {
  final Control control;

  const CupertinoDividerControl({super.key, required this.control});

  @override
  Widget build(BuildContext context) {
    final height = control.getDouble("height", 1)!;
    final thickness = control.getDouble("thickness", 0.5)!;
    final leading = control.getDouble("leading_indent", 0)!;
    final trailing = control.getDouble("trailing_indent", 0)!;
    return BaseControl(
      control: control,
      child: SizedBox(
        height: height,
        child: Padding(
          padding: EdgeInsetsDirectional.only(start: leading, end: trailing),
          child: Center(
            child: Container(
              height: thickness,
              decoration: BoxDecoration(
                color: control.getColor("color", context) ??
                    CupertinoColors.separator.resolveFrom(context),
                borderRadius: control.getBorderRadius("radius"),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class CupertinoVerticalDividerControl extends StatelessWidget {
  final Control control;

  const CupertinoVerticalDividerControl({super.key, required this.control});

  @override
  Widget build(BuildContext context) {
    final width = control.getDouble("width", 1)!;
    final thickness = control.getDouble("thickness", 0.5)!;
    final leading = control.getDouble("leading_indent", 0)!;
    final trailing = control.getDouble("trailing_indent", 0)!;
    return BaseControl(
      control: control,
      child: SizedBox(
        width: width,
        child: Padding(
          padding: EdgeInsets.only(top: leading, bottom: trailing),
          child: Center(
            child: Container(
              width: thickness,
              decoration: BoxDecoration(
                color: control.getColor("color", context) ??
                    CupertinoColors.separator.resolveFrom(context),
                borderRadius: control.getBorderRadius("radius"),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class CupertinoProgressBarControl extends StatelessWidget {
  final Control control;

  const CupertinoProgressBarControl({super.key, required this.control});

  @override
  Widget build(BuildContext context) {
    final value = control.getDouble("value");
    final height = control.getDouble("bar_height", 3)!;
    final radius = control.getBorderRadius("border_radius") ??
        BorderRadius.circular(height / 2);
    final color = control.getColor("color", context) ??
        CupertinoColors.activeBlue.resolveFrom(context);
    final background = control.getColor("bgcolor", context) ??
        CupertinoColors.systemGrey5.resolveFrom(context);

    final indicator = Semantics(
      label: control.getString("semantics_label"),
      value: control.get("semantics_value")?.toString(),
      child: ClipRRect(
        borderRadius: radius,
        child: SizedBox(
          height: height,
          child: value == null
              ? CupertinoActivityIndicator(color: color, radius: height * 2)
              : LayoutBuilder(builder: (context, constraints) {
                  return ColoredBox(
                    color: background,
                    child: Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: SizedBox(
                        width: constraints.maxWidth * value.clamp(0, 1),
                        child: ColoredBox(color: color),
                      ),
                    ),
                  );
                }),
        ),
      ),
    );
    return LayoutControl(control: control, child: indicator);
  }
}

class CupertinoBottomAppBarControl extends StatelessWidget {
  final Control control;

  const CupertinoBottomAppBarControl({super.key, required this.control});

  @override
  Widget build(BuildContext context) {
    final borderRadius = control.getBorderRadius("border_radius");
    Widget bar = DecoratedBox(
      decoration: BoxDecoration(
        color: control.getColor("bgcolor", context) ??
            CupertinoColors.systemBackground.resolveFrom(context),
        borderRadius: borderRadius,
        border: Border(
          top: BorderSide(
            color: CupertinoColors.separator.resolveFrom(context),
            width: 0.5,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: control.getPadding("padding", EdgeInsets.zero)!,
          child: SizedBox(
            height: control.getDouble("height"),
            child: control.buildWidget("content"),
          ),
        ),
      ),
    );
    if (borderRadius != null) {
      bar = ClipRRect(borderRadius: borderRadius, child: bar);
    }
    return LayoutControl(control: control, child: bar);
  }
}

class CupertinoFloatingActionButtonControl extends StatelessWidget {
  final Control control;

  const CupertinoFloatingActionButtonControl(
      {super.key, required this.control});

  @override
  Widget build(BuildContext context) {
    final icon = control.buildIconOrWidget("icon");
    final content = control.buildTextOrWidget("content");
    if (icon == null && content == null) {
      return const ErrorControl(
          "FloatingActionButton has nothing to display. Provide at minimum one of these: icon, content");
    }
    final child = icon ?? content!;
    final mini = control.getBool("mini", false)!;
    final url = control.getUrl("url");
    final button = CupertinoButton(
      minimumSize: Size.square(mini ? 40 : 56),
      padding: icon != null && content != null
          ? const EdgeInsets.symmetric(horizontal: 18)
          : EdgeInsets.zero,
      borderRadius: BorderRadius.circular(mini ? 20 : 28),
      color: control.getColor("bgcolor", context) ??
          CupertinoTheme.of(context).primaryColor,
      foregroundColor: control.getColor("foreground_color", context) ??
          (control.disabled
              ? null
              : CupertinoTheme.of(context).primaryContrastingColor),
      disabledColor: CupertinoColors.tertiarySystemFill.resolveFrom(context),
      onPressed: control.disabled
          ? null
          : () {
              if (url != null) openWebBrowser(url);
              control.triggerEvent("click");
            },
      child: icon != null && content != null
          ? Row(mainAxisSize: MainAxisSize.min, children: [icon, content])
          : child,
    );
    return LayoutControl(control: control, child: button);
  }
}
