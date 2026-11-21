import 'package:flutter/widgets.dart';

import '../core/control_core.dart';
import '../core/control_spec.dart';
import '../core/raw_prop.dart';

const _noTrack = 'CupertinoActivityIndicator draws spokes, not a stroked '
    'track';

/// Everything Ruby can send to ProgressRing (`progress_ring` and
/// `cupertino_activity_indicator`), and which design honors it.
const progressRingSpec = ControlSpec(wireType: 'ProgressRing', props: [
  // The determinate fraction: `progress` (the iOS name) wins over `value`.
  PropSpec('value', PropType.number, 'valueFraction',
      consumer: PropConsumer.core),
  PropSpec('progress', PropType.number, 'progressFraction',
      consumer: PropConsumer.core),
  PropSpec('color', PropType.color, 'color'),
  PropSpec('semantics_label', PropType.string, 'semanticsLabel'),
  PropSpec('semantics_value', PropType.number, 'semanticsValue',
      consumer: PropConsumer.core),
  PropSpec('bgcolor', PropType.color, 'bgcolor',
      skins: {Skin.material}, reason: _noTrack),
  PropSpec('stroke_width', PropType.number, 'strokeWidth',
      skins: {Skin.material}, reason: _noTrack),
  PropSpec('stroke_cap', PropType.raw, 'strokeCap',
      skins: {Skin.material}, reason: _noTrack),
  PropSpec('stroke_align', PropType.number, 'strokeAlign',
      skins: {Skin.material}, reason: _noTrack),
  PropSpec('track_gap', PropType.number, 'trackGap',
      skins: {Skin.material}, reason: _noTrack),
  PropSpec('size_constraints', PropType.raw, 'sizeConstraints',
      skins: {Skin.material},
      reason: 'Material ring constraints; the iOS indicator sizes from '
          '`radius`'),
  PropSpec('padding', PropType.edgeInsets, 'padding',
      skins: {Skin.material},
      reason: 'CircularProgressIndicator padding around its track; '
          'CupertinoActivityIndicator has none'),
  PropSpec('year_2023', PropType.boolean, 'year2023',
      skins: {Skin.material},
      reason: 'Material 3 2023 visuals; iOS has no Material variants'),
  PropSpec('radius', PropType.number, 'radius',
      skins: {Skin.cupertino},
      reason: 'CupertinoActivityIndicator size; the Material ring sizes from '
          '`size_constraints`'),
  PropSpec('animating', PropType.boolean, 'animating',
      skins: {Skin.cupertino},
      reason: 'CupertinoActivityIndicator can pause; an indeterminate '
          'CircularProgressIndicator always spins'),
]);

@immutable
class ProgressRingProps {
  ProgressRingProps.parse(PropReader r)
      : valueFraction = r.number('value'),
        progressFraction = r.number('progress'),
        color = r.color('color'),
        semanticsLabel = r.string('semantics_label'),
        semanticsValue = r.number('semantics_value'),
        bgcolor = r.color('bgcolor'),
        strokeWidth = r.number('stroke_width'),
        strokeCap = r.raw('stroke_cap'),
        strokeAlign = r.number('stroke_align'),
        trackGap = r.number('track_gap'),
        sizeConstraints = r.raw('size_constraints'),
        padding = r.edgeInsets('padding'),
        year2023 = r.optionalBoolean('year_2023'),
        radius = r.number('radius'),
        animating = r.boolean('animating', true);

  /// Ruby `value` and `progress`: see [ProgressRingCore.fraction].
  final double? valueFraction;
  final double? progressFraction;
  final Color? color;
  final String? semanticsLabel;
  final double? semanticsValue;
  final Color? bgcolor;
  final double? strokeWidth;
  final RawProp strokeCap;
  final double? strokeAlign;
  final double? trackGap;
  final RawProp sizeConstraints;
  final EdgeInsets? padding;
  final bool? year2023;
  final double? radius;

  /// Whether an indeterminate iOS indicator spins (Ruby's default: true).
  final bool animating;
}

/// The shared progress ring: which fraction it shows (or none, while
/// indeterminate) and what it announces to accessibility, identical on
/// Material and Cupertino.
class ProgressRingCore extends ControlCore<ProgressRingProps> {
  ProgressRingCore(super.control);

  @override
  ControlSpec get spec => progressRingSpec;

  @override
  ProgressRingProps parse(PropReader r) => ProgressRingProps.parse(r);

  /// The determinate fraction in 0..1, or null while indeterminate.
  /// `progress` wins over `value` (the iOS rule); out-of-range values are
  /// clamped (the Material rule), so both designs show the same fraction.
  double? get fraction {
    final fraction = props.progressFraction ?? props.valueFraction;
    return fraction?.clamp(0.0, 1.0).toDouble();
  }

  /// The accessibility value both designs announce: Ruby's
  /// `semantics_value`, or the determinate percentage.
  String? get accessibilityValue {
    final explicit = props.semanticsValue;
    if (explicit != null) return explicit.toString();
    final fraction = this.fraction;
    return fraction == null ? null : '${(fraction * 100).round()}';
  }
}
