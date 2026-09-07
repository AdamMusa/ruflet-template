import 'dart:async';

import 'package:flutter/cupertino.dart';

import '../extensions/control.dart';
import '../models/control.dart';
import '../utils/alignment.dart';
import '../utils/box.dart';
import '../utils/colors.dart';
import '../utils/cupertino_theme.dart';
import '../utils/edge_insets.dart';
import '../utils/numbers.dart';
import '../utils/text.dart';
import '../utils/time.dart';
import '../utils/transforms.dart';

class CupertinoControlBadge extends StatelessWidget {
  final Control control;
  final Widget child;

  const CupertinoControlBadge({
    super.key,
    required this.control,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final value = control.get("badge");
    if (value == null) return child;
    final badge = value is Control ? value : null;
    if (badge != null) badge.notifyParent = true;
    if (badge?.getBool("label_visible", true) == false) return child;

    final label = badge?.buildTextOrWidget("label") ?? Text(value.toString());
    final styleTheme = cupertinoStyleTheme(context);
    final smallSize = badge?.getDouble("small_size", 8) ?? 8;
    final largeSize = badge?.getDouble("large_size", 18) ?? 18;
    final padding = badge?.getPadding(
          "padding",
          const EdgeInsets.symmetric(horizontal: 5),
        ) ??
        const EdgeInsets.symmetric(horizontal: 5);
    final background = badge == null
        ? CupertinoColors.systemRed.resolveFrom(context)
        : parseColor(badge.get("bgcolor"), styleTheme,
            CupertinoColors.systemRed.resolveFrom(context))!;
    final textColor = badge == null
        ? CupertinoColors.white
        : parseColor(
            badge.get("text_color"), styleTheme, CupertinoColors.white)!;
    final textStyle = badge?.getTextStyle("text_style", styleTheme) ??
        CupertinoTheme.of(context)
            .textTheme
            .tabLabelTextStyle
            .copyWith(color: textColor, fontWeight: FontWeight.w600);
    final alignment = badge?.getAlignment("alignment", Alignment.topRight) ??
        Alignment.topRight;
    final offset = badge?.getOffset("offset", Offset.zero) ?? Offset.zero;

    final labelText = label is Text ? label.data ?? "" : "widget";
    final compact = labelText.isEmpty;
    final indicator = Container(
      constraints: BoxConstraints(
        minWidth: compact ? smallSize : largeSize,
        minHeight: compact ? smallSize : largeSize,
      ),
      padding: compact ? EdgeInsets.zero : padding,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(largeSize),
      ),
      child: compact
          ? null
          : DefaultTextStyle(
              style: textStyle.copyWith(color: textColor),
              textAlign: TextAlign.center,
              child: label,
            ),
    );
    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        Positioned.fill(
          child: IgnorePointer(
            child: Align(
              alignment: alignment,
              child: Transform.translate(offset: offset, child: indicator),
            ),
          ),
        ),
      ],
    );
  }
}

class CupertinoControlTooltip extends StatefulWidget {
  final Control control;
  final Widget child;

  const CupertinoControlTooltip({
    super.key,
    required this.control,
    required this.child,
  });

  @override
  State<CupertinoControlTooltip> createState() =>
      _CupertinoControlTooltipState();
}

class _CupertinoControlTooltipState extends State<CupertinoControlTooltip> {
  final _controller = OverlayPortalController();
  final _link = LayerLink();
  Timer? _showTimer;
  Timer? _hideTimer;

  dynamic get _value => widget.control.get("tooltip");

  String get _message => _value is String
      ? _value as String
      : _value?["message"]?.toString() ?? "";

  Duration get _waitDuration => _value is Map
      ? parseDuration(
          _value["wait_duration"], const Duration(milliseconds: 800))!
      : const Duration(milliseconds: 800);

  Duration get _showDuration => _value is Map
      ? parseDuration(_value["show_duration"], const Duration(seconds: 2))!
      : const Duration(seconds: 2);

  void _scheduleShow() {
    _hideTimer?.cancel();
    _showTimer?.cancel();
    _showTimer = Timer(_waitDuration, _show);
  }

  void _show() {
    if (!mounted || _message.isEmpty) return;
    _controller.show();
    _hideTimer?.cancel();
    _hideTimer = Timer(_showDuration, _hide);
  }

  void _hide() {
    _showTimer?.cancel();
    if (_controller.isShowing) _controller.hide();
  }

  @override
  void dispose() {
    _showTimer?.cancel();
    _hideTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_value == null || _message.isEmpty) return widget.child;
    return Semantics(
      tooltip: _message,
      child: OverlayPortal(
        controller: _controller,
        overlayChildBuilder: _buildOverlay,
        child: CompositedTransformTarget(
          link: _link,
          child: MouseRegion(
            onEnter: (_) => _scheduleShow(),
            onExit: (_) => _hide(),
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onLongPress: _show,
              onTap: _value is Map && _value["tap_to_dismiss"] == false
                  ? null
                  : _hide,
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOverlay(BuildContext context) {
    final value = _value;
    final styleTheme = cupertinoStyleTheme(context);
    final padding = value is Map
        ? parseEdgeInsets(value["padding"],
            const EdgeInsets.symmetric(horizontal: 10, vertical: 6))!
        : const EdgeInsets.symmetric(horizontal: 10, vertical: 6);
    final background = value is Map
        ? parseColor(value["bgcolor"], styleTheme,
            CupertinoColors.systemGrey.resolveFrom(context))!
        : CupertinoColors.systemGrey.resolveFrom(context);
    final textStyle = value is Map
        ? parseTextStyle(
            value["text_style"],
            styleTheme,
            CupertinoTheme.of(context)
                .textTheme
                .tabLabelTextStyle
                .copyWith(color: CupertinoColors.white))!
        : CupertinoTheme.of(context)
            .textTheme
            .tabLabelTextStyle
            .copyWith(color: CupertinoColors.white);
    final verticalOffset =
        value is Map ? parseDouble(value["vertical_offset"], 12)! : 12.0;
    return CompositedTransformFollower(
      link: _link,
      targetAnchor: Alignment.bottomCenter,
      followerAnchor: Alignment.topCenter,
      offset: Offset(0, verticalOffset),
      child: Align(
        alignment: Alignment.topCenter,
        child: CupertinoPopupSurface(
          isSurfacePainted: false,
          child: Container(
            constraints: value is Map
                ? parseBoxConstraints(value["size_constraints"])
                : null,
            padding: padding,
            decoration: BoxDecoration(
              color: background.withValues(alpha: 0.94),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(_message, style: textStyle),
          ),
        ),
      ),
    );
  }
}
