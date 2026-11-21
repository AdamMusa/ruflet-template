import 'package:flutter/material.dart';

import '../utils/box.dart' show parseBoxConstraints;
import '../utils/misc.dart' show parseStrokeCap;
import 'progress_ring_core.dart';

/// Material skin of [ProgressRingCore]: a CircularProgressIndicator.
class MaterialProgressRingSkin extends StatelessWidget {
  const MaterialProgressRingSkin({super.key, required this.core});

  final ProgressRingCore core;

  @override
  Widget build(BuildContext context) {
    final p = core.props;
    return CircularProgressIndicator(
      value: core.fraction,
      strokeWidth: p.strokeWidth,
      color: p.color,
      backgroundColor: p.bgcolor,
      semanticsLabel: p.semanticsLabel,
      semanticsValue: core.accessibilityValue,
      strokeCap: parseStrokeCap(p.strokeCap.string),
      strokeAlign: p.strokeAlign,
      trackGap: p.trackGap,
      constraints: parseBoxConstraints(p.sizeConstraints.value),
      padding: p.padding,
      // todo: deprecated and to be removed in future versions
      // ignore: deprecated_member_use
      year2023: p.year2023,
    );
  }
}
