import 'package:flutter/material.dart';

import '../utils/buttons.dart' show parseButtonStyle;
import '../widgets/error.dart';
import 'button_core.dart';

/// Material skin of [ButtonCore]: maps the core's values onto
/// ElevatedButton, FilledButton (+ tonal), OutlinedButton or TextButton.
class MaterialButtonSkin extends StatelessWidget {
  const MaterialButtonSkin({super.key, required this.core});

  final ButtonCore core;

  @override
  Widget build(BuildContext context) {
    final p = core.props;
    final theme = Theme.of(context);
    final style = parseButtonStyle(
      p.style.value,
      theme,
      defaultForegroundColor: p.color ?? theme.colorScheme.primary,
      defaultBackgroundColor: p.bgcolor ?? theme.colorScheme.surface,
      defaultOverlayColor: theme.colorScheme.primary.withValues(alpha: 0.08),
      defaultShadowColor: theme.colorScheme.shadow,
      defaultSurfaceTintColor: theme.colorScheme.surfaceTint,
      defaultElevation: p.elevation ?? 1,
      defaultPadding: const EdgeInsets.symmetric(horizontal: 8),
      defaultBorderSide: BorderSide.none,
      defaultShape: theme.useMaterial3
          ? const StadiumBorder()
          : RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
    );
    var icon = p.icon;
    final iconColor = p.iconColor;
    if (icon != null && iconColor != null) {
      icon =
          IconTheme.merge(data: IconThemeData(color: iconColor), child: icon);
    }
    final content = p.content?.build();
    final onPressed = core.onClick;
    final onLongPress = core.onLongPress;
    final focusNode = core.focusNode;
    final autofocus = p.autofocus;
    final clipBehavior = p.clipBehavior;

    if (icon != null) {
      final label = content ??
          const ErrorControl("Error displaying Button",
              description:
                  "\"icon\" must be specified together with \"content\"");
      return switch (core.variant) {
        ButtonVariant.filled => FilledButton.icon(
            style: style,
            autofocus: autofocus,
            focusNode: focusNode,
            onPressed: onPressed,
            onLongPress: onLongPress,
            clipBehavior: clipBehavior,
            icon: icon,
            label: label),
        ButtonVariant.tonal => FilledButton.tonalIcon(
            style: style,
            autofocus: autofocus,
            focusNode: focusNode,
            onPressed: onPressed,
            onLongPress: onLongPress,
            clipBehavior: clipBehavior,
            icon: icon,
            label: label),
        ButtonVariant.text => TextButton.icon(
            style: style,
            autofocus: autofocus,
            focusNode: focusNode,
            onPressed: onPressed,
            onLongPress: onLongPress,
            clipBehavior: clipBehavior,
            icon: icon,
            label: label),
        ButtonVariant.outlined => OutlinedButton.icon(
            style: style,
            autofocus: autofocus,
            focusNode: focusNode,
            onPressed: onPressed,
            onLongPress: onLongPress,
            clipBehavior: clipBehavior,
            icon: icon,
            label: label),
        ButtonVariant.elevated => ElevatedButton.icon(
            style: style,
            autofocus: autofocus,
            focusNode: focusNode,
            onPressed: onPressed,
            onLongPress: onLongPress,
            clipBehavior: clipBehavior,
            icon: icon,
            label: label),
      };
    }
    return switch (core.variant) {
      ButtonVariant.filled => FilledButton(
          style: style,
          autofocus: autofocus,
          focusNode: focusNode,
          onPressed: onPressed,
          onLongPress: onLongPress,
          clipBehavior: clipBehavior,
          child: content),
      ButtonVariant.tonal => FilledButton.tonal(
          style: style,
          autofocus: autofocus,
          focusNode: focusNode,
          onPressed: onPressed,
          onLongPress: onLongPress,
          clipBehavior: clipBehavior,
          child: content),
      ButtonVariant.text => TextButton(
          style: style,
          autofocus: autofocus,
          focusNode: focusNode,
          onPressed: onPressed,
          onLongPress: onLongPress,
          clipBehavior: clipBehavior,
          child: content ?? const Text("")),
      ButtonVariant.outlined => OutlinedButton(
          style: style,
          autofocus: autofocus,
          focusNode: focusNode,
          onPressed: onPressed,
          onLongPress: onLongPress,
          clipBehavior: clipBehavior,
          child: content),
      ButtonVariant.elevated => ElevatedButton(
          style: style,
          autofocus: autofocus,
          focusNode: focusNode,
          onPressed: onPressed,
          onLongPress: onLongPress,
          clipBehavior: clipBehavior,
          child: content),
    };
  }
}
