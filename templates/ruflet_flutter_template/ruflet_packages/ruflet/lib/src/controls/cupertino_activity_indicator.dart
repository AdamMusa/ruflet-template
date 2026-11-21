import 'dart:ui' show SemanticsRole;

import 'package:flutter/cupertino.dart';

import 'progress_ring_core.dart';

/// Cupertino skin of [ProgressRingCore]: a CupertinoActivityIndicator,
/// partially revealed while determinate. It announces the same label and
/// value as the Material ring, which CupertinoActivityIndicator does not do
/// by itself.
class CupertinoProgressRingSkin extends StatelessWidget {
  const CupertinoProgressRingSkin({super.key, required this.core});

  final ProgressRingCore core;

  @override
  Widget build(BuildContext context) {
    final p = core.props;
    final fraction = core.fraction;
    final radius = p.radius ?? 10.0;
    return Semantics(
      label: p.semanticsLabel,
      value: core.accessibilityValue,
      role: fraction == null
          ? SemanticsRole.loadingSpinner
          : SemanticsRole.progressBar,
      minValue: fraction == null ? null : '0',
      maxValue: fraction == null ? null : '100',
      child: fraction != null
          ? CupertinoActivityIndicator.partiallyRevealed(
              radius: radius, color: p.color, progress: fraction)
          : CupertinoActivityIndicator(
              radius: radius, animating: p.animating, color: p.color),
    );
  }
}
