import 'package:flutter/material.dart';

import '../models/control.dart';
import '../utils/badge.dart';
import '../utils/tooltip.dart';

class MaterialControlTooltip extends StatelessWidget {
  final Control control;
  final Widget child;

  const MaterialControlTooltip({
    super.key,
    required this.control,
    required this.child,
  });

  @override
  Widget build(BuildContext context) =>
      parseTooltip(control.get("tooltip"), context, child) ?? child;
}

class MaterialControlBadge extends StatelessWidget {
  final Control control;
  final Widget child;

  const MaterialControlBadge({
    super.key,
    required this.control,
    required this.child,
  });

  @override
  Widget build(BuildContext context) =>
      control.wrapWithBadge("badge", child, Theme.of(context));
}
