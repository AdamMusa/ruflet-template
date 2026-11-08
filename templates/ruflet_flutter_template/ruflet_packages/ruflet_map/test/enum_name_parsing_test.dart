import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ruflet_map/src/utils/attribution_alignment.dart';
import 'package:ruflet_map/src/utils/map.dart';

void main() {
  test('map enum names accept camelCase and Ruby snake_case', () {
    for (final name in [
      'notVisibleRespectMargin',
      'not_visible_respect_margin',
      'NOT_VISIBLE_RESPECT_MARGIN'
    ]) {
      expect(parseEvictErrorTileStrategy(name),
          EvictErrorTileStrategy.notVisibleRespectMargin,
          reason: name);
    }
    expect(parsePatternFit('append_dot'), PatternFit.appendDot);
    expect(parsePatternFit('extendFinalDash'), PatternFit.extendFinalDash);
    expect(parseCursorRotationBehaviour('set_north'),
        CursorRotationBehaviour.setNorth);
    expect(parseAttributionAlignment('bottom_left'),
        AttributionAlignment.bottomLeft);
  });

  test('unknown map enum names keep the default', () {
    expect(parsePatternFit('scale_sideways', PatternFit.none), PatternFit.none);
    expect(
        parseAttributionAlignment('top_left', AttributionAlignment.bottomRight),
        AttributionAlignment.bottomRight);
    expect(parseEvictErrorTileStrategy(null), isNull);
  });
}
